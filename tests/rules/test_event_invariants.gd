extends TestCase
## Events never end a level, change the timer or undo a task (A6, R-20), for every event type.

const H := preload("res://tests/support/rules_helpers.gd")
const SignalRecorder := preload("res://tests/support/signal_recorder.gd")
const STEP := 1.0 / 30.0


func _level(event_type: String) -> Dictionary:
	var data := H.level_data()
	var ev := {"id": "e_probe", "type": event_type, "window": [20, 40], "duration_s": 6}
	if event_type == "goat_stampede":
		ev["params"] = {"lane": "north_path"}
	data["events"] = [ev, {"id": "e_other", "type": "mud_trail", "window": [60, 90], "duration_s": 4}]
	return data


func _control() -> Dictionary:
	var data := H.level_data()
	data["events"] = [
		{"id": "e_late_a", "type": "mud_trail", "window": [170, 170], "duration_s": 1},
		{"id": "e_late_b", "type": "mud_trail", "window": [175, 175], "duration_s": 1},
	]
	return data


func test_every_event_type_keeps_the_invariants() -> void:
	var types := H.event_types()
	check(types.size() >= 6, "event types")
	for type_name in types:
		var rec := SignalRecorder.new(H.bus())
		var s := LevelSession.new(H.make_def(_level(type_name)), H.bus(), H.rules(),
				{"schedule_mode": EventScheduler.MODE_EARLIEST})
		var control := LevelSession.new(H.make_def(_control()), null, H.rules())
		s.start()
		control.start()
		var world := H.snap(["yard"], "pig", "hat", [H.ent("c1", "chicken", ["coop"]), H.ent("c2", "chicken", ["coop"]),
				H.ent("p1", "pig", [], "player")])
		s.tick(1.0, world)
		control.tick(1.0, world)
		s.report_delivery("coconut", "monkey")
		s.report_count("sand")
		var done_before: Array = s.result()["done_ids"]
		check_eq(done_before, ["t_alpha", "t_bravo"], "%s: tasks done before" % type_name)
		var effects: Array = types[type_name]["effects"]
		var applied := false
		while s.elapsed() < 179.0:
			if not applied and rec.filtered(["event_triggered"]).size() > 0:
				world = H.apply_effects(world, effects)
				applied = true
			s.tick(STEP, world)
			control.tick(STEP, world)
			check(absf(s.time_left() - control.time_left()) < 0.000001, "%s: timer untouched" % type_name)
			if s.get_state() != LevelSession.State.REQUIRED_DONE:
				fail("%s: state changed to %d" % [type_name, s.get_state()])
				break
		check(applied, "%s: event triggered" % type_name)
		check_eq(s.result()["done_ids"], done_before, "%s: done set unchanged" % type_name)
		var counters: Dictionary = s.state_dict()["counters"]
		check_eq(counters.get(Conditions.counter_key_delivery("coconut", "monkey"), 0), 1, "%s: deliveries kept" % type_name)
		check_eq(counters.get(Conditions.counter_key("sand"), 0), 1, "%s: counter kept" % type_name)
		check_eq(rec.filtered(["level_won", "level_lost"]), [], "%s: no end before the timer" % type_name)
		rec.disconnect_all()


func test_no_mutator_api() -> void:
	var s := LevelSession.new(H.make_def(H.level_data()), null, H.rules())
	var re := RegEx.create_from_string("^(set_|complete_|undo_|add_time)")
	for method in s.get_script().get_script_method_list():
		var name: String = method["name"]
		check(re.search(name) == null, "unexpected mutator %s" % name)
