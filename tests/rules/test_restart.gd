extends TestCase
## Restart restores the initial state; restart and a full simulated level stay fast.

const H := preload("res://tests/support/rules_helpers.gd")
const STEP := 1.0 / 60.0


func test_restart_equals_fresh_session() -> void:
	var def := H.make_def(H.level_data())
	var options := {"seed_override": 55, "schedule_mode": EventScheduler.MODE_SEEDED}
	var s := LevelSession.new(def, H.bus(), H.rules(), options)
	var fresh := LevelSession.new(def, null, H.rules(), options)
	var schedule := s.schedule()
	s.start()
	s.tick(1.0, H.snap_required_done())
	s.report_delivery("coconut", "monkey")
	s.report_count("sand")
	s.tick(172.0, H.snap())
	s.pause()
	check(s.state_dict()["fired"].size() == 2, "events fired")
	check(s.state_dict()["flags"]["warned"], "warning fired")
	check_ne(s.state_dict(), fresh.state_dict(), "played state differs")
	var t0 := Time.get_ticks_usec()
	s.restart()
	var took := Time.get_ticks_usec() - t0
	check(took < 5000, "restart took %d us" % took)
	check_eq(s.get_state(), LevelSession.State.READY, "READY")
	check_eq(s.state_dict(), fresh.state_dict(), "same as fresh")
	check_eq(s.schedule(), schedule, "same schedule")


func test_full_level_is_fast() -> void:
	var entities := []
	for i in 30:
		entities.append(H.ent("e%d" % i, ["chicken", "duck", "goat", "coconut"][i % 4], ["zone_%d" % (i % 6)]))
	var world := H.snap(["yard"], "", "", entities)
	var data := H.level_data()
	data["timer_seconds"] = 300
	var s := LevelSession.new(H.make_def(data), H.bus(), H.rules())
	s.start()
	var t0 := Time.get_ticks_usec()
	var guard := 0
	while s.get_state() == LevelSession.State.RUNNING and guard < 20000:
		s.tick(STEP, world)
		guard += 1
	var took := (Time.get_ticks_usec() - t0) / 1000000.0
	check_eq(s.get_state(), LevelSession.State.LOST, "ran to the end")
	check(took < 2.0, "300 s level took %f s" % took)
