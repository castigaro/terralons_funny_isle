extends TestCase
## Jingles duck the music player (not the bus) for their duration; a win or loss replaces the task jingle of the
## same frame.

const STEP := 0.05


func _audio() -> Node:
	return root().get_node("Audio")


func _bus() -> Node:
	return root().get_node("EventBus")


func before_each() -> void:
	_audio().set("manual_clock", true)


func _len(jingle: String) -> float:
	var map: AudioMap = _audio().call("audio_map")
	return (load(map.jingle_path(jingle)) as AudioStream).get_length()


func test_pure_duck_envelope() -> void:
	var d := MusicDuck.new(-12.0, 0.0, 0.4)
	check_eq(d.offset_db(0.0), 0.0, "no jingle")
	d.jingle_started("a", 1.0, 2.0)
	check_eq(d.offset_db(1.5), -12.0, "ducked")
	d.jingle_started("b", 2.0, 3.0)
	check_eq(d.offset_db(3.5), -12.0, "overlap keeps the duck until the last end")
	check(absf(d.offset_db(5.2) + 6.0) < 0.001, "half released")
	check_eq(d.offset_db(5.5), 0.0, "released")


func test_pure_attack() -> void:
	var d := MusicDuck.new(-10.0, 1.0, 0.0)
	d.jingle_started("a", 0.0, 5.0)
	check(absf(d.offset_db(0.5) + 5.0) < 0.001, "attack ramp")
	check_eq(d.offset_db(2.0), -10.0, "full depth")
	check_eq(d.offset_db(5.0), 0.0, "no release")


func test_task_jingle_ducks_music_player() -> void:
	var audio := _audio()
	var tuning: AudioTuning = audio.call("tuning")
	var music_idx := AudioServer.get_bus_index("Music")
	var bus_db := AudioServer.get_bus_volume_db(music_idx)
	audio.call("play_music", "level_1")
	audio.call("advance", tuning.crossfade + 0.5)
	check(absf(audio.call("music_player_db") - tuning.music_db) < 0.01, "full before")
	_bus().task_completed.emit("lvl", "task_a")
	audio.call("advance", STEP)
	check_eq(audio.call("current_jingle"), "task_done", "task jingle")
	audio.call("advance", tuning.duck_attack + STEP)
	check(absf(audio.call("music_player_db") - (tuning.music_db + tuning.duck_db)) < 0.01, "ducked by balance amount")
	check_eq(AudioServer.get_bus_volume_db(music_idx), bus_db, "bus volume untouched")
	var length := _len("task_done")
	var t := STEP + tuning.duck_attack + STEP
	while t < length - STEP:
		audio.call("advance", STEP)
		t += STEP
		check(audio.call("music_player_db") < tuning.music_db + tuning.duck_db / 2.0, "ducked during jingle at %s" % t)
	audio.call("advance", STEP + tuning.duck_release / 2.0)
	var mid: float = audio.call("music_player_db")
	check(mid > tuning.music_db + tuning.duck_db and mid < tuning.music_db, "releasing (%s)" % mid)
	audio.call("advance", tuning.duck_release)
	check(absf(audio.call("music_player_db") - tuning.music_db) < 0.01, "released")
	check_eq(AudioServer.get_bus_volume_db(music_idx), bus_db, "bus volume still untouched")


func test_win_replaces_task_jingle_in_same_frame() -> void:
	var audio := _audio()
	_bus().task_completed.emit("lvl", "task_a")
	_bus().level_won.emit("lvl", 2)
	audio.call("advance", STEP)
	check_eq(audio.call("current_jingle"), "won", "won wins")
	audio.call("reset_for_tests")
	audio.set("manual_clock", true)
	_bus().task_completed.emit("lvl", "task_a")
	_bus().level_lost.emit("lvl", ["task_b"])
	audio.call("advance", STEP)
	check_eq(audio.call("current_jingle"), "lost", "lost wins")


func test_arbiter() -> void:
	var a := JingleArbiter.new()
	check_eq(a.flush(), "", "empty")
	a.request("task_done")
	check_eq(a.flush(), "task_done", "task alone")
	a.request("task_done")
	a.request("won")
	check_eq(a.flush(), "won", "won over task")
	check_eq(a.flush(), "", "requests forgotten")
