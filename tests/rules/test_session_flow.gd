extends TestCase
## LevelSession win and loss flow (D-3) on the real EventBus.

const H := preload("res://tests/support/rules_helpers.gd")
const SignalRecorder := preload("res://tests/support/signal_recorder.gd")
const FLOW := ["task_progress", "task_completed", "all_required_done", "level_won", "level_lost", "level_started"]
const ONCE := ["task_completed", "all_required_done", "level_won", "level_lost", "level_started", "timer_warning"]

var _rec: SignalRecorder = null


func before_each() -> void:
	_rec = SignalRecorder.new(H.bus())


func after_each() -> void:
	_rec.disconnect_all()


func _session(rules: Dictionary = {}, data: Dictionary = {}) -> LevelSession:
	var section := rules if not rules.is_empty() else H.rules()
	var level := data if not data.is_empty() else H.level_data()
	return LevelSession.new(H.make_def(level, section), H.bus(), section)


func _names(wanted: Array) -> Array:
	var out := []
	for e in _rec.filtered(wanted):
		out.append(e[0])
	return out


func _check_once() -> void:
	var counts := {}
	for e in _rec.filtered(ONCE):
		var key := str(e)
		counts[key] = counts.get(key, 0) + 1
	for key in counts:
		check(counts[key] <= 1, "%s fired %d times per attempt" % [key, counts[key]])


func test_required_done_then_finish() -> void:
	var s := _session()
	s.start()
	s.tick(1.0, H.snap(["yard"], "", "", [H.ent("c1", "chicken", ["coop"]), H.ent("c2", "chicken", ["coop"])]))
	check_eq(s.get_state(), LevelSession.State.RUNNING, "one required task open")
	s.tick(1.0, H.snap_required_done())
	check_eq(s.get_state(), LevelSession.State.REQUIRED_DONE, "required done")
	var flow := _rec.filtered(FLOW)
	check_eq(flow[0], ["level_started", ["lvl_inline"]], "started")
	check_eq(flow[1], ["task_progress", ["lvl_inline", "t_alpha", 2, 2]], "alpha progress")
	check_eq(flow[2], ["task_completed", ["lvl_inline", "t_alpha"]], "alpha done")
	check_eq(flow[3], ["task_progress", ["lvl_inline", "t_bravo", 1, 1]], "bravo progress")
	check_eq(flow[4], ["task_completed", ["lvl_inline", "t_bravo"]], "bravo done")
	check_eq(flow[5], ["all_required_done", ["lvl_inline"]], "all required")
	H.run(s, 120, 1.0 / 60.0, H.snap())
	check_eq(s.get_state(), LevelSession.State.REQUIRED_DONE, "play continues")
	check_eq(_names(["level_won"]), [], "not won yet")
	var left := s.time_left()
	check(s.finish(), "finish accepted")
	check_eq(s.get_state(), LevelSession.State.WON, "won")
	var won := _rec.filtered(["level_won"])
	check_eq(won, [["level_won", ["lvl_inline", Stars.compute(true, false, left, 180.0, 0.25)]]], "won args")
	check_eq(won[0][1][1], 1, "required only gives 1 star")
	check_false(s.finish(), "second finish refused")
	_check_once()


func test_timeout_after_required_wins() -> void:
	var s := _session()
	s.start()
	s.tick(1.0, H.snap_required_done())
	s.report_delivery("coconut", "monkey")
	s.report_delivery("coconut", "monkey")
	s.report_delivery("coconut", "monkey")
	s.report_count("sand", 2)
	s.pause()
	check_false(s.finish(), "finish refused while paused")
	s.resume()
	s.tick(200.0, H.snap())
	check_eq(s.get_state(), LevelSession.State.WON, "won by auto finish")
	_check_once()
	_rec.clear()
	var s2 := _session()
	s2.start()
	s2.tick(1.0, H.snap_required_done())
	s2.report_count("sand", 2)
	s2.tick(200.0, H.snap())
	check_eq(s2.get_state(), LevelSession.State.WON, "timeout in REQUIRED_DONE wins")
	check_eq(s2.time_left(), 0.0, "no time left")
	check(s2.result()["stars"] <= 2, "at most 2 stars")
	check_eq(s2.result()["open_optional_ids"], ["t_charlie"], "open optional")
	_check_once()


func test_timeout_with_required_open_loses() -> void:
	var data := H.level_data()
	data["tasks"][3]["required"] = true
	var s := _session({}, data)
	s.start()
	s.tick(1.0, H.snap(["yard"], "pig"))
	s.tick(180.0, H.snap(["yard"], "pig"))
	check_eq(s.get_state(), LevelSession.State.LOST, "lost")
	check_eq(_rec.filtered(["level_lost"]), [["level_lost", ["lvl_inline", ["t_alpha", "t_delta"]]]], "open required ids in data order")
	check_eq(s.result()["stars"], 0, "no stars")
	check_eq(s.result()["open_required_ids"], ["t_alpha", "t_delta"], "result open")
	_check_once()


func test_early_finish_has_no_effect() -> void:
	var s := _session()
	check_false(s.finish(), "READY")
	s.start()
	s.tick(1.0, H.snap())
	var before := s.state_dict()
	_rec.clear()
	check_false(s.finish(), "RUNNING with required open")
	check_eq(s.state_dict(), before, "state unchanged")
	check_eq(_rec.events(), [], "no signals")


func test_all_done_auto_finishes() -> void:
	var s := _session()
	s.start()
	s.report_delivery("coconut", "monkey")
	s.report_delivery("coconut", "monkey")
	s.report_delivery("coconut", "monkey")
	s.report_count("sand")
	s.report_count("sand", 0)
	s.report_count("sand", -4)
	s.tick(1.0, H.snap_required_done())
	check_eq(s.get_state(), LevelSession.State.REQUIRED_DONE, "sand 1 of 2, negative ignored")
	s.report_count("sand")
	s.tick(1.0, H.snap_required_done())
	check_eq(s.get_state(), LevelSession.State.WON, "auto finish")
	check_eq(_rec.filtered(["level_won"])[0][1][1], 3, "3 stars with plenty of time")
	_check_once()


func test_auto_finish_can_be_disabled() -> void:
	var rules := H.rules()
	rules["auto_finish_when_all_done"] = false
	var s := _session(rules)
	s.start()
	for i in 3:
		s.report_delivery("coconut", "monkey")
	s.report_count("sand", 2)
	s.tick(1.0, H.snap_required_done())
	check_eq(s.get_state(), LevelSession.State.REQUIRED_DONE, "waits for finish")
	check(s.finish(), "finish")
	check_eq(_rec.filtered(["level_won"])[0][1][1], 3, "3 stars")


func test_same_tick_completion_and_timeout_wins() -> void:
	var rules := H.rules()
	rules["auto_finish_when_all_done"] = false
	var s := _session(rules)
	s.start()
	s.tick(179.0, H.snap())
	s.tick(5.0, H.snap_required_done())
	check_eq(s.get_state(), LevelSession.State.WON, "completion wins the tie")
	check_eq(_names(["level_lost"]), [], "no loss")


func test_progress_live_then_latched() -> void:
	var s := _session()
	s.start()
	var one := H.snap([], "", "", [H.ent("c1", "chicken", ["coop"])])
	s.tick(0.1, one)
	check_eq(s.task_progress()[0]["current"], 1, "1/2")
	s.tick(0.1, H.snap())
	check_eq(s.task_progress()[0]["current"], 0, "progress can go down before completion")
	s.tick(0.1, H.snap([], "", "", [H.ent("c1", "chicken", ["coop"]), H.ent("c2", "chicken", ["coop"])]))
	check(s.task_progress()[0]["done"], "done")
	s.tick(0.1, H.snap())
	check(s.task_progress()[0]["done"], "stays done")
	check_eq(s.task_progress()[0]["current"], 2, "stays 2/2")
	var progress := _rec.filtered(["task_progress"])
	check_eq(progress.size(), 3, "progress only on change: %s" % str(progress))


func test_progress_clamped_until_done() -> void:
	var data := H.level_data()
	data["tasks"][2]["modifiers"] = [{"type": "worn", "item": "hat"}]
	var s := _session({}, data)
	s.start()
	for i in 4:
		s.report_delivery("coconut", "monkey")
	s.tick(0.1, H.snap())
	check_eq(s.task_progress()[2]["current"], 2, "n/n only when done")
	check_false(s.task_progress()[2]["done"], "modifier missing")
	s.tick(0.1, H.snap([], "", "hat"))
	check_eq(s.task_progress()[2]["current"], 3, "done shows 3/3")


func test_missed_before_event_stays_open() -> void:
	var data := H.level_data()
	data["tasks"][2]["modifiers"] = [{"type": "before_event", "event": "e_one"}]
	var s := LevelSession.new(H.make_def(data), H.bus(), H.rules(), {"schedule_mode": EventScheduler.MODE_EARLIEST})
	s.start()
	s.tick(31.0, H.snap())
	for i in 3:
		s.report_delivery("coconut", "monkey")
	s.tick(1.0, H.snap())
	var task: Dictionary = s.task_progress()[2]
	check(task["missed"], "missed")
	check_false(task["done"], "open")
	check(s.result()["open_optional_ids"].has("t_charlie"), "counts as open")
