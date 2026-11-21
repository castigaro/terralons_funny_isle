extends TestCase
## data/balance/castaway.json: every key present and positive, sane derived speeds, overrides reach the config.


func _balance() -> Node:
	return root().get_node("Balance")


func test_every_key_exists_and_is_positive() -> void:
	var section: Dictionary = _balance().get_section(CastawayConfig.NAMESPACE)
	for key in CastawayConfig.KEYS:
		check(section.has(key), "missing key %s" % key)
		check(float(section.get(key, 0.0)) > 0.0, "%s must be > 0" % key)
	for key in section:
		check(CastawayConfig.KEYS.has(key), "unknown key %s" % key)
	check_eq(CastawayConfig.from_balance().missing, [], "missing keys")


func test_derived_speeds() -> void:
	var cfg := CastawayConfig.from_balance()
	check(cfg.dash_speed() > cfg.move_speed, "dash faster than running")
	check(cfg.dash_speed() >= cfg.knockback_speed(), "dash at least as fast as knockback")
	check(cfg.dash_cooldown >= cfg.dash_duration, "cooldown covers the dash")
	check(cfg.use_radius < cfg.throw_range, "use radius below throw range")
	check(cfg.grab_touch_radius <= cfg.grab_radius, "touch radius inside grab radius")


func test_dizzy_default() -> void:
	check_eq(CastawayConfig.from_balance().dizzy_seconds, 1.2, "dizzy seconds")


func test_from_balance_reads_overrides() -> void:
	_balance().set_override(CastawayConfig.NAMESPACE, "move_speed", 123)
	check_eq(CastawayConfig.from_balance().move_speed, 123.0, "override")
	_balance().clear_overrides()
	check_eq(CastawayConfig.from_balance().move_speed, 460.0, "file value")


func test_from_dict_reports_missing() -> void:
	var cfg := CastawayConfig.from_dict({"move_speed": 10})
	check_eq(cfg.move_speed, 10.0, "value")
	check(cfg.missing.has("dash_distance"), "missing reported")
