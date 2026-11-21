extends TestCase
## ProgressModel: unlock order, replay, independent best stars and best time, record_win results.

const IDS := ["a", "b", "c", "d", "e"]


func test_fresh_model_unlocks_only_the_first_level() -> void:
	var m := ProgressModel.defaults(IDS)
	check_true(m.is_unlocked("a"), "first open")
	for level_id in ["b", "c", "d", "e"]:
		check_false(m.is_unlocked(level_id), "%s locked" % level_id)
	check_false(m.is_unlocked("zzz"), "unknown id locked")
	check_eq(m.first_open_id(), "a", "focus target")
	check_eq(m.best_stars("a"), 0, "no stars")
	check_eq(m.best_time("a"), -1.0, "no time")


func test_win_n_unlocks_n_plus_1_only() -> void:
	var m := ProgressModel.defaults(IDS)
	var res := m.record_win("a", 1, 100.0)
	check_eq(res["unlocked_id"], "b", "b opened")
	check_true(m.is_unlocked("b"), "b open")
	check_false(m.is_unlocked("c"), "c still locked")
	check_eq(m.first_open_id(), "b", "focus moves on")
	var again := m.record_win("a", 1, 120.0)
	check_eq(again["unlocked_id"], "", "nothing new on a replay")


func test_replay_of_won_level_allowed() -> void:
	var m := ProgressModel.defaults(IDS)
	m.record_win("a", 2, 90.0)
	m.record_win("b", 1, 90.0)
	check_true(m.is_unlocked("a"), "a replayable")
	check_true(m.is_unlocked("b"), "b replayable")
	check_true(m.is_unlocked("c"), "c open")


func test_best_values_are_independent() -> void:
	var m := ProgressModel.defaults(IDS)
	var first := m.record_win("a", 1, 80.0)
	check_true(first["new_best_stars"] and first["new_best_time"], "first win is a best")
	var slower_three := m.record_win("a", 3, 150.0)
	check_true(slower_three["new_best_stars"], "more stars")
	check_false(slower_three["new_best_time"], "slower time is no best")
	check_eq(m.best_stars("a"), 3, "3 stars kept")
	check_eq(m.best_time("a"), 80.0, "faster time kept")
	var faster_one := m.record_win("a", 1, 60.0)
	check_false(faster_one["new_best_stars"], "fewer stars")
	check_true(faster_one["new_best_time"], "faster time")
	check_eq(m.best_stars("a"), 3, "stars stay 3")
	check_eq(m.best_time("a"), 60.0, "time 60")


func test_unknown_id_and_clamping() -> void:
	var m := ProgressModel.defaults(IDS)
	var res := m.record_win("nope", 3, 10.0)
	check_eq(res, {"new_best_stars": false, "new_best_time": false, "unlocked_id": ""}, "unknown id")
	check_eq(m.to_dict()["levels"], {}, "nothing stored")
	m.record_win("a", 9, 10.0)
	check_eq(m.best_stars("a"), Stars.MAX_STARS, "clamped high")
	m.record_win("b", -4, 0.0)
	check_eq(m.best_stars("b"), 0, "clamped low")
	check_eq(m.best_time("b"), -1.0, "zero time ignored")
	check_true(m.is_won("b"), "still a win")


func test_first_open_id_when_all_won() -> void:
	var m := ProgressModel.defaults(IDS)
	for level_id in IDS:
		m.record_win(level_id, 2, 30.0)
	check_eq(m.first_open_id(), "a", "falls back to the first")
	check_eq(m.unlocked_ids(), IDS, "all open")
	var last := ProgressModel.defaults(IDS)
	check_eq(last.record_win("e", 1, 5.0)["unlocked_id"], "", "last level unlocks nothing")
