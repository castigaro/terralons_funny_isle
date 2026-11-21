extends TestCase
## Timer rules: counts only while running, pause keeps the time, one warning, ticks on whole seconds.

const H := preload("res://tests/support/rules_helpers.gd")
const SignalRecorder := preload("res://tests/support/signal_recorder.gd")
const STEP := 1.0 / 60.0

var _rec: SignalRecorder = null


func before_each() -> void:
	_rec = SignalRecorder.new(H.bus())


func after_each() -> void:
	_rec.disconnect_all()


func _session() -> LevelSession:
	return LevelSession.new(H.make_def(H.level_data()), H.bus(), H.rules())


func _count(name: String) -> int:
	return _rec.filtered([name]).size()


func test_ready_ignores_ticks() -> void:
	var s := _session()
	H.run(s, 120, STEP, H.snap())
	check_eq(s.time_left(), 180.0, "time unchanged in READY")
	check_eq(s.elapsed(), 0.0, "elapsed unchanged")
	check_eq(_rec.events(), [], "no signals")


func test_pause_keeps_remaining_time() -> void:
	var s := _session()
	s.start()
	H.run(s, 60, STEP, H.snap())
	var before := s.time_left()
	s.pause()
	check_eq(s.get_state(), LevelSession.State.PAUSED, "paused")
	H.run(s, 600, STEP, H.snap())
	check_eq(s.time_left(), before, "10 s of paused ticks change nothing")
	s.resume()
	check_eq(s.get_state(), LevelSession.State.RUNNING, "running again")
	H.run(s, 60, STEP, H.snap())
	check(absf(s.time_left() - (before - 1.0)) < 0.001, "counts down after resume: %f" % s.time_left())


func test_warning_fires_once() -> void:
	var s := _session()
	s.start()
	s.tick(169.5, H.snap())
	check_eq(_count("timer_warning"), 0, "no warning above 10 s")
	s.tick(0.5, H.snap())
	check_eq(_count("timer_warning"), 1, "warning at 10 s")
	check_eq(_rec.filtered(["timer_warning"])[0][1], ["lvl_inline", 10.0], "warning args")
	H.run(s, 120, STEP, H.snap())
	check_eq(_count("timer_warning"), 1, "still once")


func test_warning_once_around_pause() -> void:
	var s := _session()
	s.start()
	s.tick(169.9, H.snap())
	s.pause()
	H.run(s, 30, STEP, H.snap())
	s.resume()
	check_eq(_count("timer_warning"), 0, "not yet")
	s.tick(0.2, H.snap())
	s.pause()
	s.resume()
	H.run(s, 60, STEP, H.snap())
	check_eq(_count("timer_warning"), 1, "once across pause and resume")


func test_timer_tick_on_whole_seconds() -> void:
	var s := _session()
	s.start()
	H.run(s, 600, STEP, H.snap())
	var ticks := _rec.filtered(["level_timer_tick"])
	check(ticks.size() >= 9 and ticks.size() <= 11, "about one tick per second: %d" % ticks.size())
	var last := -1.0
	for t in ticks:
		var whole := ceili(t[1][0])
		check(whole != last, "one tick per whole second")
		last = whole


func test_ticks_after_end_change_nothing() -> void:
	var lost := _session()
	lost.start()
	lost.tick(200.0, H.snap())
	check_eq(lost.get_state(), LevelSession.State.LOST, "lost")
	var snap_lost := lost.state_dict()
	H.run(lost, 60, STEP, H.snap_required_done())
	check_eq(lost.state_dict(), snap_lost, "LOST is final")
	var won := _session()
	won.start()
	won.tick(1.0, H.snap_required_done())
	check(won.finish(), "finish")
	var snap_won := won.state_dict()
	_rec.clear()
	H.run(won, 60, STEP, H.snap())
	won.report_count("sand", 3)
	check_eq(won.state_dict(), snap_won, "WON is final")
	check_eq(_rec.events(), [], "no signals after WON")
