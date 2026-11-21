extends TestCase
## Music per D-2: title stub, levels 1-3 own tracks, level 4 reuses level 2, level 5 reuses level 3; idempotent
## play_music, unknown ids keep the track, music keeps playing in pause while effects pause.

const FIXTURE_LEVELS := "res://tests/fixtures/audio/levels"
const MAIN_SCENE := "res://scenes/main.tscn"


func _audio() -> Node:
	return root().get_node("Audio")


func _bus() -> Node:
	return root().get_node("EventBus")


func before_each() -> void:
	_audio().set("manual_clock", true)
	_audio().set("levels_dir", FIXTURE_LEVELS)


func test_title_stub_requests_title() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_node(main)
	check_eq(_audio().call("current_music"), "title", "title music")
	check_true(_audio().call("music_player").playing, "title playing")


func test_levels_select_their_tracks() -> void:
	var map: AudioMap = _audio().call("audio_map")
	var expected := {"fx_level_1": "level_1", "fx_level_2": "level_2", "fx_level_3": "level_3",
			"fx_level_4": "level_2", "fx_level_5": "level_3"}
	for level_id in expected:
		check_eq(AudioMap.music_for_level(level_id, FIXTURE_LEVELS), expected[level_id], "%s music id" % level_id)
		_bus().level_started.emit(level_id)
		check_eq(_audio().call("current_music"), expected[level_id], "%s current" % level_id)
		var player: AudioStreamPlayer = _audio().call("music_player")
		check_eq(player.stream.resource_path, map.music_path(expected[level_id]), "%s stream" % level_id)


func test_level_four_and_five_reuse_tracks() -> void:
	var map: AudioMap = _audio().call("audio_map")
	check_eq(map.music_path(AudioMap.music_for_level("fx_level_4", FIXTURE_LEVELS)), map.music_path("level_2"), "L4")
	check_eq(map.music_path(AudioMap.music_for_level("fx_level_5", FIXTURE_LEVELS)), map.music_path("level_3"), "L5")


func test_same_id_does_not_restart() -> void:
	var audio := _audio()
	audio.call("play_music", "level_1")
	audio.call("advance", 1.0)
	var player: AudioStreamPlayer = audio.call("music_player")
	var stream := player.stream
	var db := player.volume_db
	audio.call("play_music", "level_1")
	check(audio.call("music_player") == player, "same player")
	check(player.stream == stream, "same stream")
	check_eq(player.volume_db, db, "no new fade")
	check_true(player.playing, "still playing")
	_bus().level_started.emit("fx_level_1")
	check(audio.call("music_player") == player, "restart keeps the player")


func test_crossfade_switches_players() -> void:
	var audio := _audio()
	var tuning: AudioTuning = audio.call("tuning")
	audio.call("play_music", "level_1")
	audio.call("advance", tuning.crossfade + 0.5)
	var first: AudioStreamPlayer = audio.call("music_player")
	check(absf(first.volume_db - tuning.music_db) < 0.01, "first at full volume")
	audio.call("play_music", "level_2")
	var second: AudioStreamPlayer = audio.call("music_player")
	check(second != first, "other player")
	check(absf(second.volume_db - tuning.silent_db) < 0.01, "incoming starts silent")
	audio.call("advance", tuning.crossfade / 2.0)
	check(second.volume_db > tuning.silent_db and first.volume_db > tuning.silent_db, "both audible mid fade")
	audio.call("advance", tuning.crossfade)
	check(absf(second.volume_db - tuning.music_db) < 0.01, "incoming at full volume")
	check_false(first.playing, "outgoing stopped")


func test_unknown_id_keeps_track_and_warns_once() -> void:
	var audio := _audio()
	audio.call("play_music", "level_3")
	audio.call("play_music", "disco_tune")
	audio.call("play_music", "disco_tune")
	check_eq(audio.call("current_music"), "level_3", "kept")
	check_eq(audio.call("warnings_logged").size(), 1, "one warning")
	_bus().level_started.emit("fx_unknown_music")
	check_eq(audio.call("current_music"), "level_3", "kept for level with unknown music")
	_bus().level_started.emit("fx_missing_level")
	check_eq(audio.call("current_music"), "level_3", "kept for a missing level file")
	check_eq(audio.call("last_errors"), [], "no errors")


func test_music_plays_in_pause_effects_pause() -> void:
	var audio := _audio()
	audio.call("play_music", "title")
	for player in audio.call("music_players"):
		check_eq(player.process_mode, Node.PROCESS_MODE_ALWAYS, "music process mode")
	check_eq(audio.process_mode, Node.PROCESS_MODE_ALWAYS, "audio process mode")
	for player in audio.call("sfx_players", "step"):
		check_eq(player.process_mode, Node.PROCESS_MODE_PAUSABLE, "sfx process mode")
	tree().paused = true
	await frames(2)
	check_true(audio.call("music_player").playing, "music keeps playing in pause")
	check_false(audio.call("music_player").stream_paused, "music not paused")
	check(audio.call("music_player").can_process(), "music processes in pause")
	var sfx: AudioStreamPlayer = audio.call("sfx_players", "step")[0]
	check_false(sfx.can_process(), "effects pause with the tree")
	tree().paused = false
