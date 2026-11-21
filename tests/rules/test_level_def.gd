extends TestCase
## LevelDef: parity with tools/validate_levels.py on every fixture, derived targets and the folder helpers.

const I18nScript := preload("res://scripts/autoload/i18n.gd")
const H := preload("res://tests/support/rules_helpers.gd")
const FIXTURES := "res://tests/fixtures/levels"


func _ctx() -> Dictionary:
	var messages: Dictionary = I18nScript.parse_dir("res://i18n")["messages"]
	messages.merge(I18nScript.parse_dir(FIXTURES.path_join("i18n"))["messages"])
	return LevelDef.make_context(H.rules(), H.event_types(), messages)


func test_event_catalogue_loads() -> void:
	var res := LevelDef.load_event_types()
	check_eq(res["errors"], [], "events.json errors")
	for name in ["parrot_steal_hat", "goat_stampede", "coconut_throw", "rain_panic", "wave_wash", "mud_trail"]:
		check(res["types"].has(name), "type %s" % name)


func test_fixture_parity() -> void:
	var files := LevelDef.list_level_files(FIXTURES)
	check(files.size() >= 20, "fixtures found: %d" % files.size())
	var ctx := _ctx()
	for path in files:
		var res := LevelDef.load_file(path, ctx)
		var expect_ok: bool = path.get_file().begins_with("valid_")
		check_eq(res["ok"], expect_ok, "%s verdict %s" % [path.get_file(), str(res["errors"])])
		if expect_ok:
			check(res["def"] is LevelDef, "def for %s" % path)
		else:
			check(not res["errors"].is_empty(), "errors for %s" % path)


func test_derived_targets() -> void:
	var res := LevelDef.load_file(FIXTURES.path_join("valid_basic.json"), _ctx())
	var def: LevelDef = res["def"]
	var targets := []
	for task in def.tasks:
		targets.append(task["target"])
	check_eq(targets, [2, 1, 3, 1], "targets")
	check_eq(def.id, "valid_basic", "id")
	check_eq(def.timer_seconds, 240.0, "timer")
	check_eq(def.level_seed, 4242, "seed")
	check_eq(def.three_star_share, -1.0, "no share override")
	check_eq(def.events.size(), 3, "events")
	var counts: LevelDef = LevelDef.load_file(FIXTURES.path_join("valid_counts.json"), _ctx())["def"]
	check_eq(counts.tasks[0]["target"], 4, "count_reached target")
	check_eq(counts.three_star_share, 0.5, "share override")


func test_missing_folder_lists_nothing() -> void:
	check_eq(LevelDef.list_level_files("res://does_not_exist_dir"), [], "missing folder")


func test_real_levels_parse() -> void:
	var ctx := LevelDef.make_context(H.rules(), H.event_types(), I18nScript.parse_dir("res://i18n")["messages"])
	for path in LevelDef.list_level_files():
		var res := LevelDef.load_file(path, ctx)
		check(res["ok"], "%s: %s" % [path, str(res["errors"])])
	check(true)


func test_reserved_and_type_errors() -> void:
	var data := H.level_data()
	data["tasks"][1]["id"] = "player"
	check(H.make_def(data) == null, "reserved id rejected")
	data = H.level_data()
	data["timer_seconds"] = 200.5
	check(H.make_def(data) == null, "float timer rejected")
	data = H.level_data()
	data["tasks"][0]["required"] = 1
	check(H.make_def(data) == null, "int required flag rejected")
	check(H.make_def(H.level_data()) != null, "inline level valid")
