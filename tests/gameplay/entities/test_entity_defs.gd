extends TestCase
## EntityDefs and EntityConfig: real data loads, verdict parity with tools/validate_entities.py, balance keys.

const I18nScript := preload("res://scripts/autoload/i18n.gd")
const FIXTURES := "res://tests/fixtures/entities"
## Fixtures only the Python validator rejects (deny list and on-screen size need the PNG files and the deny list).
const PYTHON_ONLY := ["invalid_denied_sprite.json", "invalid_small_sprite.json"]
const REQUIRED_ANIMALS := ["chicken", "duck", "goat", "pig", "monkey", "parrot", "penguin"]
const REQUIRED_ITEMS := ["coconut", "hat", "bucket", "sand_pail"]


func _balance() -> Node:
	return root().get_node("Balance")


func _ctx() -> Dictionary:
	return EntityDefs.make_context(I18nScript.parse_dir("res://i18n")["messages"],
			_balance().get_section("castaway"), _balance().get_section(EntityConfig.NAMESPACE))


func test_default_data_loads() -> void:
	var res := EntityDefs.load_default()
	check_eq(res["errors"], [], "errors")
	for kind in REQUIRED_ANIMALS:
		check(res["animals"].has(kind), "animal %s" % kind)
	for kind in REQUIRED_ITEMS:
		check(res["items"].has(kind), "item %s" % kind)
	check_eq(EntityDefs.cache_errors(), [], "cache errors")
	check(EntityDefs.kinds().has("chicken") and EntityDefs.kinds().has("coconut"), "kinds")
	check_eq(EntityDefs.get_animal("dragon"), {}, "unknown kind")


func test_fixture_parity_with_python() -> void:
	var files := DirAccess.get_files_at(FIXTURES)
	var count := 0
	for name in files:
		if name.get_extension() != "json" or PYTHON_ONLY.has(name):
			continue
		count += 1
		var data: Variant = EntityDefs.read_json(FIXTURES.path_join(name))["data"]
		var res := EntityDefs.parse(data["animals"], data["items"], _ctx())
		var expect_ok := name.begins_with("valid_")
		check_eq(res["errors"].is_empty(), expect_ok, "%s verdict %s" % [name, str(res["errors"])])
	check(count >= 9, "fixtures checked: %d" % count)


func test_messages_match_python_wording() -> void:
	var data: Variant = EntityDefs.read_json(FIXTURES.path_join("invalid_unknown_lure.json"))["data"]
	var errors: Array = EntityDefs.parse(data["animals"], data["items"], _ctx())["errors"]
	check(str(errors).contains("animals.monkey.lure_item: unknown lure item banana"), str(errors))


func test_config_keys_exist_and_are_positive() -> void:
	var section: Dictionary = _balance().get_section(EntityConfig.NAMESPACE)
	for key in EntityConfig.KEYS:
		check(section.has(key), "missing key %s" % key)
		check(float(section.get(key, 0.0)) > 0.0, "%s must be > 0" % key)
	for key in section:
		check(EntityConfig.KEYS.has(key), "unknown key %s" % key)
	var cfg := EntityConfig.from_balance()
	check_eq(cfg.missing, [], "missing")
	check_eq(cfg.respawn_delay, 2.0, "respawn delay default")
	check_eq(cfg.reaction_max_seconds, 3.0, "reaction max default")
	check(cfg.bonk_seconds < cfg.reaction_max_seconds, "bonk shorter than the reaction limit")
	check(EntityConfig.from_dict({}).missing.has("bonk_radius"), "missing reported")


func test_every_reaction_fits_the_limit() -> void:
	var cfg := EntityConfig.from_balance()
	for kind in EntityDefs.animal_kinds():
		var d := EntityDefs.get_animal(kind)
		check(cfg.bonk_seconds + float(d["panic_duration"]) <= cfg.reaction_max_seconds, kind)


func test_castaway_carry_limits() -> void:
	var cfg := CastawayConfig.from_balance()
	check_eq(cfg.carry_weight_min, 0.5, "min")
	check_eq(cfg.carry_weight_max, 2.0, "max")
