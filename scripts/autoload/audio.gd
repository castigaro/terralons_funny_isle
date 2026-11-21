extends Node
## Audio autoload: music with crossfade, throttled sound effects, jingles with music duck and the single-voice
## announcer with captions. Sounds are wired from data/audio.json to EventBus signals; tuning comes from
## data/balance/audio.json. A missing file or mapping only warns once and never stops the game.

const MAP_PATH := "res://data/audio.json"
const LEVELS_DIR := "res://data/levels"
const CAPTION_SCENE := "res://scenes/audio/announcer_caption.tscn"
const BUS_NAMES := {"music": "Music", "effects": "Effects"}
const MUSIC_BUS := "Music"
const EFFECTS_BUS := "Effects"
const JINGLE_TOKEN := "jingle"
const SFX_REQUEST_LOG := 64  # balance-exempt: test log size

## Directory of the level files used to look up the level music and event types.
var levels_dir := LEVELS_DIR
## When true, _process does not advance the audio clock (tests call advance() themselves).
var manual_clock := false

var _map: AudioMap = AudioMap.new()
var _map_path := MAP_PATH
var _tuning: AudioTuning = AudioTuning.new()
var _throttle: SfxThrottle
var _queue: AnnouncerQueue
var _duck: MusicDuck
var _arbiter := JingleArbiter.new()
var _rng: SeededRng
var _now := 0.0
var _errors: Array = []
var _warned := {}
var _warnings: Array = []
var _volumes := {}
var _music_players: Array[AudioStreamPlayer] = []
var _music_current := 0
var _music_id := ""
var _fade_elapsed := 0.0
var _fading := false
var _pools := {}
var _jingle_player: AudioStreamPlayer
var _jingle_id := ""
var _announcer_player: AudioStreamPlayer
var _line_lengths := {}
var _caption: Node = null
var _event_types := {}
var _streams := {}
var _connections: Array = []
var _sfx_requests: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	for bus in [MUSIC_BUS, EFFECTS_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			_errors.append("audio bus %s missing (default_bus_layout.tres)" % bus)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%s" % ["A", "B"][i]
		player.bus = MUSIC_BUS
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_music_players.append(player)
	_jingle_player = _make_player("Jingle", Node.PROCESS_MODE_ALWAYS)
	_announcer_player = _make_player("Announcer", Node.PROCESS_MODE_ALWAYS)
	if ResourceLoader.exists(CAPTION_SCENE):
		_caption = (load(CAPTION_SCENE) as PackedScene).instantiate()
		add_child(_caption)
	reload_tuning()
	_load_map(MAP_PATH)
	for bus in BUS_NAMES:
		set_volume(bus, _tuning.default_volume)
	for err in _errors:
		push_error("Audio: %s" % err)


func _process(delta: float) -> void:
	if not manual_clock:
		advance(delta)


func _make_player(player_name: String, mode: ProcessMode) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = EFFECTS_BUS
	player.process_mode = mode
	add_child(player)
	return player


## Re-reads data/balance/audio.json through Balance and rebuilds throttle, queue, duck and the player pools.
func reload_tuning() -> void:
	var balance := get_node_or_null("/root/Balance")
	var section: Dictionary = balance.call("get_section", AudioTuning.NS) if balance != null else {}
	_tuning = AudioTuning.from_section(section)
	for err in _tuning.errors:
		if not _errors.has(err):
			_errors.append(err)
	_throttle = SfxThrottle.new(_tuning)
	_queue = AnnouncerQueue.new(_tuning.announcer_max_queue, _tuning.announcer_gap)
	_duck = MusicDuck.new(_tuning.duck_db, _tuning.duck_attack, _tuning.duck_release)
	_rng = SeededRng.new(_tuning.sfx_seed)
	for id in _pools:
		for player in _pools[id]["players"]:
			player.queue_free()
	_pools.clear()
	if _caption != null and _caption.has_method("configure"):
		_caption.call("configure", _tuning)


## Uses another audio map file (tests) and rewires the EventBus connections.
func use_map_file(path: String) -> void:
	_load_map(path)


func _load_map(path: String) -> void:
	_map_path = path
	_map = AudioMap.load_file(path)
	for err in _map.errors():
		if not _errors.has(err):
			_errors.append(err)
	_connect_bus()


func _connect_bus() -> void:
	var bus := get_node_or_null("/root/EventBus")
	for c in _connections:
		if bus != null and bus.is_connected(c[0], c[1]):
			bus.disconnect(c[0], c[1])
	_connections.clear()
	if bus == null:
		return
	for s in bus.get_script().get_script_signal_list():
		var sname: String = s["name"]
		if not _map.has_signal_entry(sname) and sname != "level_started":
			continue
		var cb := _make_callback(sname, s["args"].size())
		bus.connect(sname, cb)
		_connections.append([sname, cb])


func _make_callback(sname: String, argc: int) -> Callable:
	match argc:
		0:
			return func() -> void: handle_signal(sname, [])
		1:
			return func(a: Variant) -> void: handle_signal(sname, [a])
		2:
			return func(a: Variant, b: Variant) -> void: handle_signal(sname, [a, b])
		3:  # balance-exempt: signal argument count
			return func(a: Variant, b: Variant, c: Variant) -> void: handle_signal(sname, [a, b, c])
		_:
			return func(a: Variant, b: Variant, c: Variant, d: Variant) -> void: handle_signal(sname, [a, b, c, d])


## The single dispatch of every EventBus connection.
func handle_signal(signal_name: String, args: Array) -> void:
	var resolve_args := args
	if signal_name == "level_started":
		_on_level_started(String(args[0]) if not args.is_empty() else "")
	elif signal_name == "event_triggered" and not args.is_empty():
		var event_id := String(args[0])
		resolve_args = [String(_event_types.get(event_id, event_id)), event_id]
	var res := _map.resolve(signal_name, resolve_args)
	if not res["mapped"]:
		if not _map.ignored.has(signal_name) and signal_name != "level_started":
			_warn_once("signal:" + signal_name, "no sound mapping for signal %s" % signal_name)
		return
	if res["sfx"] != "":
		play_sfx(res["sfx"], res["pitch"])
	if res["jingle"] != "":
		_arbiter.request(res["jingle"])
	if res["announcer"] != "":
		say(res["announcer"])


func _on_level_started(level_id: String) -> void:
	_sfx_requests.clear()
	_queue.clear()
	_announcer_player.stop()
	var info := AudioMap.level_info(level_id, levels_dir)
	if info.is_empty():
		_warn_once("level:" + level_id, "no level file for %s, music unchanged" % level_id)
		_event_types = {}
		return
	_event_types = info["event_types"]
	if String(info["music"]) != "":
		play_music(info["music"])


## Advances the audio clock: plays the jingle of this frame, starts the next announcer line, applies duck and fade.
func advance(delta: float) -> void:
	_now += maxf(delta, 0.0)
	var jingle := _arbiter.flush()
	if jingle != "":
		play_jingle(jingle)
	_tick_announcer()
	if _fading:
		_fade_elapsed += maxf(delta, 0.0)
	_apply_music_volumes()


# --- Volume ----------------------------------------------------------------------------------------

## Sets the bus "music" or "effects" to a linear volume 0..1; 0 mutes the bus.
func set_volume(bus: String, linear: float) -> void:
	var key := bus.to_lower()
	if not BUS_NAMES.has(key):
		_warn_once("bus:" + bus, "unknown audio bus %s" % bus)
		return
	var idx := AudioServer.get_bus_index(BUS_NAMES[key])
	var v := clampf(linear, 0.0, 1.0)
	_volumes[key] = v
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0.0)
	if v > 0.0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(v))


func get_volume(bus: String) -> float:
	return float(_volumes.get(bus.to_lower(), _tuning.default_volume))


# --- Music -----------------------------------------------------------------------------------------

## Crossfades to a music id of data/audio.json; the current id is a no-op, an unknown id keeps the track.
func play_music(id: String) -> void:
	if id == _music_id:
		return
	var path := _map.music_path(id)
	if path == "":
		_warn_once("music:" + id, "unknown music id %s" % id)
		return
	var stream := _stream(path)
	if stream == null:
		return
	var had_music := _music_id != ""
	if had_music:
		_music_current = 1 - _music_current
	var incoming := _music_players[_music_current]
	incoming.stream = stream
	incoming.play()
	_music_id = id
	_fading = had_music and _tuning.crossfade > 0.0
	_fade_elapsed = 0.0
	if not had_music and _tuning.crossfade > 0.0:
		_fading = true
	_apply_music_volumes()


func current_music() -> String:
	return _music_id


## Stops every player (music, jingle, announcer, effects).
func stop_all() -> void:
	stop_music()
	_jingle_player.stop()
	_announcer_player.stop()
	for id in _pools:
		for player in _pools[id]["players"]:
			player.stop()


func _exit_tree() -> void:
	stop_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


## Stops all audio, waits in real time until the mixer released its playbacks and quits; use it instead of
## SceneTree.quit() so no audio resource is still in use at exit.
func quit_game(exit_code: int = 0) -> void:
	stop_all()
	var until := Time.get_ticks_msec() + _tuning.quit_settle_msec
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
	get_tree().quit(exit_code)


func stop_music() -> void:
	for player in _music_players:
		player.stop()
	_music_id = ""
	_fading = false


func _fade_db(frac: float) -> float:
	if frac >= 1.0:
		return _tuning.music_db
	var floor_lin := db_to_linear(_tuning.silent_db)
	var lin := maxf(frac * db_to_linear(_tuning.music_db), floor_lin)
	return maxf(linear_to_db(lin), _tuning.silent_db)


func _apply_music_volumes() -> void:
	var frac := 1.0
	if _fading:
		frac = clampf(_fade_elapsed / _tuning.crossfade, 0.0, 1.0) if _tuning.crossfade > 0.0 else 1.0
	var duck := _duck.offset_db(_now)
	var incoming := _music_players[_music_current]
	var outgoing := _music_players[1 - _music_current]
	incoming.volume_db = _fade_db(frac) + duck
	if outgoing.playing:
		outgoing.volume_db = _fade_db(1.0 - frac) + duck
	if frac >= 1.0:
		_fading = false
		outgoing.stop()


# --- Sound effects ---------------------------------------------------------------------------------

## Plays a sound id of data/audio.json unless cooldown or voice limit drop it; returns false when dropped.
func play_sfx(sound_id: String, pitch_scale: float = 1.0) -> bool:
	_sfx_requests.append(sound_id)
	if _sfx_requests.size() > SFX_REQUEST_LOG:
		_sfx_requests.pop_front()
	if not _map.sfx.has(sound_id):
		_warn_once("sfx:" + sound_id, "unknown sound %s" % sound_id)
		return false
	if not _throttle.can_play(sound_id, _now):
		return false
	var path: Variant = _rng.pick(_map.sfx_paths(sound_id))
	var stream := _stream(String(path))
	if stream == null:
		return false
	var pool := _pool(sound_id)
	var players: Array = pool["players"]
	var player: AudioStreamPlayer = players[pool["next"]]
	pool["next"] = (int(pool["next"]) + 1) % players.size()
	var pitch := pitch_scale * _rng.jitter(1.0, _tuning.pitch_jitter)
	player.stream = stream
	player.volume_db = _map.sfx_volume_db(sound_id)
	player.pitch_scale = pitch
	player.play()
	_throttle.on_play(sound_id, _now, stream.get_length() / pitch)
	return true


func _pool(sound_id: String) -> Dictionary:
	if not _pools.has(sound_id):
		var players: Array = []
		for i in _tuning.voice_limit(sound_id):
			players.append(_make_player("Sfx_%s_%d" % [sound_id, i], Node.PROCESS_MODE_PAUSABLE))
		_pools[sound_id] = {"players": players, "next": 0}
	return _pools[sound_id]


# --- Jingles and announcer -------------------------------------------------------------------------

## Plays a jingle id and ducks the music for its duration.
func play_jingle(jingle_id: String) -> void:
	var path := _map.jingle_path(jingle_id)
	if path == "":
		_warn_once("jingle:" + jingle_id, "unknown jingle %s" % jingle_id)
		return
	var stream := _stream(path)
	if stream == null:
		return
	_jingle_player.stream = stream
	_jingle_player.play()
	_jingle_id = jingle_id
	_duck.jingle_started(JINGLE_TOKEN, _now, stream.get_length())
	_apply_music_volumes()


## Queues an announcer line; lines never overlap.
func say(line_id: String) -> void:
	var path := _map.announcer_path(line_id)
	if path == "":
		_warn_once("line:" + line_id, "unknown announcer line %s" % line_id)
		return
	var stream := _stream(path)
	if stream == null:
		return
	_line_lengths[line_id] = stream.get_length()
	_queue.enqueue(line_id, stream.get_length())
	_tick_announcer()


func _tick_announcer() -> void:
	var line := _queue.tick(_now)
	if line == "":
		return
	var stream := _stream(_map.announcer_path(line))
	if stream == null:
		return
	_announcer_player.stream = stream
	_announcer_player.play()
	var bus := get_node_or_null("/root/EventBus")
	if bus != null:
		bus.emit_signal("announcer_line", line, _map.announcer_caption(line),
				float(_line_lengths.get(line, stream.get_length())) + _tuning.caption_extra)


# --- Robustness and test helpers -------------------------------------------------------------------

func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	if path == "" or not ResourceLoader.exists(path):
		_warn_once("file:" + path, "missing audio file %s" % path)
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		_warn_once("file:" + path, "not an audio stream: %s" % path)
		return null
	_streams[path] = stream
	return stream


func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	_warnings.append(message)
	push_warning("Audio: %s" % message)


func last_errors() -> Array:
	return _errors.duplicate()


func warnings_logged() -> Array:
	return _warnings.duplicate()


func audio_map() -> AudioMap:
	return _map


func tuning() -> AudioTuning:
	return _tuning


func now() -> float:
	return _now


func active_voices(sound_id: String) -> int:
	return _throttle.active(sound_id, _now)


func announcer_current() -> String:
	return _queue.current(_now)


func announcer_queued() -> Array:
	return _queue.queued()


func current_jingle() -> String:
	return _jingle_id


func music_player() -> AudioStreamPlayer:
	return _music_players[_music_current]


func music_players() -> Array:
	return _music_players.duplicate()


func music_player_db() -> float:
	return _music_players[_music_current].volume_db


func sfx_players(sound_id: String) -> Array:
	return _pool(sound_id)["players"].duplicate() if _map.sfx.has(sound_id) else []


## Sound ids requested via play_sfx since the last level start (also dropped ones), oldest first, capped.
func sfx_requests() -> Array:
	return _sfx_requests.duplicate()


func caption() -> Node:
	return _caption


## Restores the start state between tests: clears queue, throttle, duck and caches, stops every player.
func reset_for_tests() -> void:
	manual_clock = false
	levels_dir = LEVELS_DIR
	stop_all()
	_jingle_id = ""
	_arbiter.clear()
	_warned.clear()
	_warnings.clear()
	_sfx_requests.clear()
	_event_types = {}
	_line_lengths.clear()
	_now = 0.0
	_errors.clear()
	for bus in [MUSIC_BUS, EFFECTS_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			_errors.append("audio bus %s missing (default_bus_layout.tres)" % bus)
	reload_tuning()
	if _map_path != MAP_PATH or not _map.errors().is_empty():
		_load_map(MAP_PATH)
	for bus in BUS_NAMES:
		set_volume(bus, _tuning.default_volume)
	if _caption != null and _caption.has_method("hide_now"):
		_caption.call("hide_now")
