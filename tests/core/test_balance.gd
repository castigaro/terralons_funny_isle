extends TestCase
## Balance autoload: file loading, overrides, int handling and the pure loader.

const BalanceScript := preload("res://scripts/autoload/balance.gd")
const DataDirScript := preload("res://scripts/autoload/data_dir.gd")


func _balance() -> Node:
	return root().get_node("Balance")


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_core_file_loads() -> void:
	var balance := _balance()
	check_eq(balance.last_errors(), [], "load errors")
	check(balance.has_value("core", "schema_version"), "core namespace present")
	check_eq(balance.get_float("core", "title_hint_pulse_seconds"), 1.2, "pulse seconds")
	check_eq(balance.get_int("core", "schema_version"), 1, "schema version")


func test_override_wins_and_clear_restores() -> void:
	var balance := _balance()
	balance.set_override("core", "title_hint_pulse_seconds", 3.5)
	check_eq(balance.get_float("core", "title_hint_pulse_seconds"), 3.5, "override")
	balance.clear_overrides()
	check_eq(balance.get_float("core", "title_hint_pulse_seconds"), 1.2, "restored")


func test_set_overrides_with_dict() -> void:
	var balance := _balance()
	balance.set_overrides("core", {"a": 1, "b": true})
	check_eq(balance.get_value("core", "a"), 1, "a")
	check_eq(balance.get_bool("core", "b"), true, "b")
	check_eq(balance.get_value("core", "missing", "dflt"), "dflt", "default")


func test_integral_float_reads_as_int() -> void:
	var balance := _balance()
	balance.set_override("core", "count", 3.0)
	check_eq(typeof(balance.get_value("core", "count")), TYPE_INT, "normalized type")
	check_eq(balance.get_int("core", "count"), 3, "get_int")
	var normalized: Dictionary = BalanceScript.normalize_json({"x": [2.0, 2.5]})
	check_eq(typeof(normalized["x"][0]), TYPE_INT, "nested int")
	check_eq(normalized["x"][1], 2.5, "fraction kept")


func test_read_int_missing_and_invalid() -> void:
	var missing: Dictionary = BalanceScript.read_int({}, "nope")
	check_false(missing["ok"], "missing key not ok")
	var bad: Dictionary = BalanceScript.read_int({"k": 1.5}, "k")
	check_false(bad["ok"], "fraction not ok")


func test_parse_dir_reports_bad_files() -> void:
	var rel := "fixtures/balance_bad"
	check_eq(root().get_node("DataDir").ensure_dir(rel), OK, "ensure_dir")
	var dir: String = DataDirScript.globalize(root().get_node("DataDir").file(rel))
	_write(dir.path_join("broken.json"), "{ not json")
	_write(dir.path_join("list.json"), "[1, 2]")
	_write(dir.path_join("good.json"), "{\"speed\": 4.0}")
	var parsed: Dictionary = BalanceScript.parse_dir(dir)
	check_eq(parsed["errors"].size(), 2, "two errors %s" % str(parsed["errors"]))
	check_eq(parsed["data"].keys(), ["good"], "only good namespace")
	check_eq(typeof(parsed["data"]["good"]["speed"]), TYPE_INT, "speed normalized")


func test_parse_dir_missing_folder() -> void:
	var parsed: Dictionary = BalanceScript.parse_dir("res://does/not/exist")
	check_eq(parsed["errors"].size(), 1, "missing folder error")
