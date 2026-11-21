extends TestCase
## data/audio.json covers every EventBus signal, every animal kind and event type, and only points to imported,
## allowed files; negative fixtures produce the expected errors.

const FIXTURES := "res://tests/fixtures/audio"


func _bus_signals() -> Array:
	var names: Array = []
	for s in root().get_node("EventBus").get_script().get_script_signal_list():
		names.append(s["name"])
	return names


func _animal_kinds() -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals.json"))
	return data["animals"].keys()


func _event_types() -> Array:
	return LevelDef.load_event_types()["types"].keys()


func _validate(path: String) -> Array:
	var map := AudioMap.load_file(path)
	return map.validate(_bus_signals(), _animal_kinds(), _event_types(), AudioMap.load_deny_tokens())


func test_real_map_is_valid() -> void:
	check_eq(_validate(AudioMap.DEFAULT_PATH), [], "audio.json errors")


func test_every_signal_mapped_or_ignored_with_reason() -> void:
	var map := AudioMap.load_file()
	for sig in _bus_signals():
		var mapped := map.signals.has(sig)
		var ignored := map.ignored.has(sig) and String(map.ignored[sig]).strip_edges() != ""
		check(mapped or ignored, "signal %s has no entry" % sig)
		check_false(mapped and map.ignored.has(sig), "signal %s is mapped and ignored" % sig)


func test_actions_and_events_have_sounds() -> void:
	var map := AudioMap.load_file()
	var expected := {"castaway_step": "step", "castaway_dashed": "dash", "object_grabbed": "grab",
			"object_thrown": "throw", "object_landed": "land", "object_bonked": "bonk", "task_progress": "task_progress",
			"timer_warning": "timer_warning", "event_triggered": "event_warning"}
	for sig in expected:
		check_eq(map.resolve(sig, [])["sfx"], expected[sig], "%s sound" % sig)
	check_eq(map.resolve("object_landed", ["coconut", Vector2.ZERO, "water"])["sfx"], "splash", "splash on water")
	check_eq(map.resolve("castaway_step", [Vector2.ZERO, "sand"])["sfx"], "step", "step on sand")
	check_eq(map.resolve("task_completed", ["l", "t"])["jingle"], "task_done", "task jingle")
	check_eq(map.resolve("level_won", ["l", 3])["jingle"], "won", "won jingle")
	check_eq(map.resolve("level_lost", ["l", []])["jingle"], "lost", "lost jingle")
	check_eq(map.resolve("level_started", ["l"])["announcer"], "go", "go line")
	check_eq(map.resolve("timer_warning", ["l", 30.0])["announcer"], "hurry_up", "hurry line")
	check_eq(map.resolve("level_won", ["l", 3])["announcer"], "level_complete", "complete line")
	check_eq(map.resolve("level_lost", ["l", []])["announcer"], "times_up", "times up line")


func test_every_animal_and_event_type_resolves() -> void:
	var map := AudioMap.load_file()
	var pitches := {}
	for kind in _animal_kinds():
		for sig in ["animal_fled", "animal_bonked", "animal_panicked", "animal_caught", "animal_lured"]:
			check_ne(map.resolve(sig, [kind])["sfx"], "", "%s %s" % [sig, kind])
		pitches[map.resolve("animal_panicked", [kind])["pitch"]] = true
	check(pitches.size() >= 5, "animals sound distinct: %d pitches" % pitches.size())
	for type in _event_types():
		check_ne(map.resolve("event_triggered", [type])["sfx"], "", "event %s" % type)
	check_eq(map.resolve("event_triggered", ["wave_wash"])["sfx"], "splash", "wave splashes")


func test_every_file_loads_as_audio_stream() -> void:
	var map := AudioMap.load_file()
	var deny := AudioMap.load_deny_tokens()
	check(deny.size() > 10, "deny list loaded")
	for rel in map.all_files():
		check_eq(AudioMap.file_problems(rel, deny), [], rel)
		check(load("res://" + rel) is AudioStream, "%s loads" % rel)


func test_deny_and_word_split() -> void:
	var deny := AudioMap.load_deny_tokens()
	check_eq(AudioMap.deny_hit("drawKnife1.ogg", deny), "knife", "knife")
	check_eq(AudioMap.deny_hit("war_go_go_go.ogg", deny), "war", "war")
	check_eq(AudioMap.deny_hit("footstep01.ogg", deny), "", "footstep")
	check_eq(AudioMap.deny_hit("metalPot1.ogg", deny), "", "pot")
	check_eq(AudioMap.split_words("drawKnife1"), ["draw", "knife", "1"], "split")


func test_missing_signal_fixture() -> void:
	var errs := _validate(FIXTURES.path_join("missing_signal.json"))
	check(str(errs).contains("signal castaway_step is neither mapped nor ignored"), str(errs))


func test_missing_file_fixture() -> void:
	var errs := _validate(FIXTURES.path_join("missing_file.json"))
	check(str(errs).contains("footstep99_missing.ogg: file missing"), str(errs))


func test_denied_file_fixture() -> void:
	var errs := _validate(FIXTURES.path_join("denied_file.json"))
	check(str(errs).contains("drawKnife1.ogg: matches deny-list token knife"), str(errs))


func test_gdignore_file_fixture() -> void:
	var errs := _validate(FIXTURES.path_join("gdignore_file.json"))
	check(str(errs).contains("laser1.mp3: inside a .gdignore folder"), str(errs))


func test_structural_errors() -> void:
	var map := AudioMap.new()
	map.apply({"format_version": 2, "music": {}, "sfx": {"a": {"files": []}}, "pitch": {}, "jingles": {},
			"announcer": {}, "ignored": {}, "signals": {"castaway_step": {"default": "nope", "jingle": "x"}}})
	var errs := str(map.errors())
	check(errs.contains("format_version"), errs)
	check(errs.contains("sfx.a needs a non-empty files list"), errs)
	check(errs.contains("unknown sfx nope"), errs)
	check(errs.contains("unknown jingle x"), errs)
