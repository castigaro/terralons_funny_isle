extends TestCase
## ProgressModel.from_dict: broken or hostile progress.json content falls back field by field.

const IDS := ["a", "b", "c"]


func _is_default(m: ProgressModel) -> bool:
	return m.unlocked_ids() == ["a"] and m.to_dict()["levels"].is_empty()


func test_garbage_gives_defaults() -> void:
	for data in [null, [], "{", "", 3, {"levels": {"a": {"won": true}}}, {"schema_version": 99, "levels": {}},
			{"schema_version": "1", "levels": {}}, {"schema_version": 1, "levels": []}]:
		check_true(_is_default(ProgressModel.from_dict(data, IDS)), "defaults for %s" % var_to_str(data))


func test_unknown_ids_and_wrong_types_dropped() -> void:
	var data := {"schema_version": 1, "levels": {
		"zzz": {"won": true, "best_stars": 3, "best_time_s": 10.0},
		"a": {"won": "yes", "best_stars": 3},
		"b": {"won": true, "best_stars": "3", "best_time_s": 0},
		"c": {"won": true, "best_stars": 7.0, "best_time_s": -5.0},
	}}
	var m := ProgressModel.from_dict(data, IDS)
	check_false(m.is_won("a"), "won as string dropped")
	check_true(m.is_won("b"), "b won")
	check_eq(m.best_stars("b"), 0, "stars as string dropped")
	check_eq(m.best_time("b"), -1.0, "zero time dropped")
	check_eq(m.best_stars("c"), Stars.MAX_STARS, "stars clamped")
	check_eq(m.best_time("c"), -1.0, "negative time dropped")
	check_false(m.to_dict()["levels"].has("zzz"), "unknown id dropped")


func test_nan_time_dropped() -> void:
	var m := ProgressModel.from_dict({"schema_version": 1, "levels": {"a": {"won": true, "best_stars": 2,
			"best_time_s": NAN}}}, IDS)
	check_eq(m.best_time("a"), -1.0, "NaN dropped")
	check_eq(m.best_stars("a"), 2, "stars kept")


func test_unlocks_are_derived_not_trusted() -> void:
	var data := {"schema_version": 1, "unlocked": ["a", "b", "c"], "levels": {}}
	var m := ProgressModel.from_dict(data, IDS)
	check_eq(m.unlocked_ids(), ["a"], "stored unlock without a win is ignored")
	var won := ProgressModel.from_dict({"schema_version": 1, "unlocked": ["a"], "levels": {"a": {"won": true}}}, IDS)
	check_eq(won.unlocked_ids(), ["a", "b"], "missing unlock after a win is added")


func test_round_trip() -> void:
	var m := ProgressModel.defaults(IDS)
	m.record_win("a", 2, 83.5)
	m.record_win("b", 3, 120.25)
	var dict := m.to_dict()
	check_eq(dict["schema_version"], ProgressModel.SCHEMA_VERSION, "version")
	var parsed: Variant = JSON.parse_string(JSON.stringify(dict))
	var again := ProgressModel.from_dict(parsed, IDS)
	check_eq(again.to_dict(), dict, "round trip equal")
