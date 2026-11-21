extends TestCase
## Missing files and unmapped signals warn exactly once and never error; a storm of every signal stays in limits.

const FIXTURES := "res://tests/fixtures/audio"
const BURST := 50


func _audio() -> Node:
	return root().get_node("Audio")


func _bus() -> Node:
	return root().get_node("EventBus")


func before_each() -> void:
	_audio().set("manual_clock", true)
	_audio().set("levels_dir", FIXTURES.path_join("levels"))


func test_missing_stream_warns_once() -> void:
	var audio := _audio()
	audio.call("use_map_file", FIXTURES.path_join("missing_file.json"))
	for i in 3:
		check_false(audio.call("play_sfx", "step"), "missing file not played")
		_bus().castaway_step.emit(Vector2.ZERO, "sand")
		audio.call("advance", 1.0)
	check_eq(audio.call("warnings_logged").size(), 1, "one warning: %s" % str(audio.call("warnings_logged")))
	check_eq(audio.call("last_errors"), [], "no errors")


func test_unmapped_signal_warns_once() -> void:
	var audio := _audio()
	audio.call("use_map_file", FIXTURES.path_join("missing_signal.json"))
	for i in 3:
		audio.call("handle_signal", "castaway_step", [Vector2.ZERO, "sand"])
	check_eq(audio.call("warnings_logged").size(), 1, "one warning")
	audio.call("handle_signal", "level_timer_tick", [10.0])
	check_eq(audio.call("warnings_logged").size(), 1, "ignored signal does not warn")
	check_eq(audio.call("last_errors"), [], "no errors")


func test_unknown_ids_warn_once() -> void:
	var audio := _audio()
	for i in 2:
		audio.call("play_sfx", "nope")
		audio.call("play_jingle", "nope")
		audio.call("say", "nope")
	check_eq(audio.call("warnings_logged").size(), 3, "one per kind")
	check_eq(audio.call("last_errors"), [], "no errors")


func _emit_all(bus: Node) -> void:
	bus.level_started.emit("fx_level_1")
	bus.level_timer_tick.emit(100.0)
	bus.task_completed.emit("fx_level_1", "t")
	bus.all_required_done.emit("fx_level_1")
	bus.level_won.emit("fx_level_1", 3)
	bus.level_lost.emit("fx_level_1", ["t"])
	bus.event_triggered.emit("fx_rain")
	bus.event_triggered.emit("fx_wave")
	bus.object_grabbed.emit("chicken")
	bus.object_thrown.emit("coconut")
	bus.object_bonked.emit("coconut", "throw")
	bus.settings_changed.emit("music_volume")
	bus.castaway_dashed.emit(Vector2.ZERO, Vector2.RIGHT)
	bus.castaway_step.emit(Vector2.ZERO, "sand")
	bus.object_used.emit("hat", "goat")
	bus.object_landed.emit("coconut", Vector2.ZERO, "water")
	bus.castaway_dizzy_started.emit("coconut")
	bus.castaway_dizzy_ended.emit()
	bus.interact_verb_changed.emit("grab", "chicken")
	bus.task_progress.emit("fx_level_1", "t", 1, 2)
	bus.timer_warning.emit("fx_level_1", 30.0)
	bus.event_ended.emit("fx_rain")
	for kind in ["chicken", "duck", "goat", "pig", "monkey", "parrot", "penguin"]:
		bus.animal_fled.emit(kind)
		bus.animal_bonked.emit(kind, "throw")
		bus.animal_panicked.emit(kind)
		bus.animal_caught.emit(kind)
		bus.animal_lured.emit(kind)
		bus.entity_lost.emit(kind, "water")
		bus.entity_respawned.emit(kind, Vector2.ZERO)


func test_signal_storm() -> void:
	var audio := _audio()
	var bus := _bus()
	var map: AudioMap = audio.call("audio_map")
	var tuning: AudioTuning = audio.call("tuning")
	_emit_all(bus)
	for i in BURST:
		bus.castaway_step.emit(Vector2.ZERO, "sand")
		bus.object_bonked.emit("pig", "throw")
		bus.animal_panicked.emit("chicken")
		bus.task_completed.emit("fx_level_1", "t%d" % i)
	for id in map.sfx:
		check(audio.call("active_voices", id) <= tuning.voice_limit(id), "%s within limit" % id)
	audio.call("advance", 1.0 / 60.0)
	check_eq(audio.call("current_jingle"), "won", "one jingle for the frame")
	check(audio.call("announcer_queued").size() <= tuning.announcer_max_queue, "queue bounded")
	check_eq(audio.call("last_errors"), [], "no errors")
	check_eq(audio.call("warnings_logged"), [], "no warnings")
