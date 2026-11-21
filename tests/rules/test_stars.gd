extends TestCase
## Stars: pure truth table, 25 % boundary and the per-level share override.

const H := preload("res://tests/support/rules_helpers.gd")


func test_truth_table() -> void:
	for req in [false, true]:
		for all in [false, true]:
			for left in [0.0, 50.0, 75.0, 200.0]:
				var expected := 0
				if req and not all:
					expected = 1
				elif req and all:
					expected = 3 if left >= 75.0 else 2
				check_eq(Stars.compute(req, all, left, 300.0, 0.25), expected, "%s %s %f" % [req, all, left])


func test_boundary() -> void:
	check_eq(Stars.compute(true, true, 75.0, 300.0, 0.25), 3, "exactly 25 %")
	check_eq(Stars.compute(true, true, 74.99, 300.0, 0.25), 2, "just below")
	check_eq(Stars.compute(true, true, 300.0 * 0.25, 300.0, 0.25), 3, "computed 25 %")
	check_eq(Stars.compute(false, true, 300.0, 300.0, 0.25), 0, "required open")
	check_eq(Stars.compute(true, false, 300.0, 300.0, 0.25), 1, "required only")
	check_eq(Stars.three_star_time(300.0, 0.25), 75.0, "threshold")


func test_balance_default_share() -> void:
	check_eq(H.rules()["three_star_time_share"], 0.25, "data/balance/rules.json")
	var s := LevelSession.new(H.make_def(H.level_data()), null, H.rules())
	check_eq(s.three_star_time(), 45.0, "25 % of 180 s")


func test_level_share_override() -> void:
	var data := H.level_data()
	data["three_star_share"] = 0.5
	var s := LevelSession.new(H.make_def(data), null, H.rules())
	check_eq(s.three_star_time(), 90.0, "50 % of 180 s")
	s.start()
	s.tick(95.0, H.snap())
	for i in 3:
		s.report_delivery("coconut", "monkey")
	s.report_count("sand", 2)
	s.tick(1.0, H.snap_required_done())
	check_eq(s.get_state(), LevelSession.State.WON, "won")
	check_eq(s.result()["stars"], 2, "84 s left is below the 90 s override (default 45 s would give 3)")
