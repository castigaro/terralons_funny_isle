extends "res://tests/support/feedback_case.gd"
## Effect scaling (AC2, AC3): fx_scale, the reduce toggle with its factor (at most 25 %), live settings changes,
## fallback for missing or corrupt settings and the separation from gameplay knockback.

const BASE_SHAKE := {"bonk": {"amplitude": 24, "trauma": 0.8}, "small": {"amplitude": 8, "trauma": 0.5},
		"medium": {"amplitude": 14, "trauma": 0.6}}


func after_each() -> void:
	reset_settings()


func _strengths_with(shake: Dictionary) -> Dictionary:
	var s: Dictionary = Balance.get_section("feedback")["strengths"].duplicate(true)
	s["shake"] = shake
	return s


func test_shake_amplitude_and_flash_alpha_scaling() -> void:
	reset_settings()
	make_director(true, {"strengths": _strengths_with(BASE_SHAKE)})
	check_eq(director.effective_shake_amplitude("bonk"), 24.0, "fx_scale 1, reduce off")
	Balance.set_override("feedback", "fx_scale", 0.5)
	director.reload_config()
	check_eq(director.effective_shake_amplitude("bonk"), 12.0, "fx_scale 0.5")
	Balance.set_override("feedback", "fx_scale", 1.0)
	director.reload_config()
	director.strengths.reduce = true
	check_eq(director.effective_shake_amplitude("bonk"), 0.0, "reduce on, factor 0")
	check_eq(director.effective_flash_alpha("task"), 0.0, "flash alpha reduced to 0")
	Balance.set_override("feedback", "reduce_motion_factor", 0.25)
	director.reload_config()
	director.strengths.reduce = true
	check_eq(director.effective_shake_amplitude("bonk"), 6.0, "factor 0.25 gives 6")
	var task_alpha := director.strengths.base("flash", "task", "alpha")
	check(is_equal_approx(director.effective_flash_alpha("task"), task_alpha * 0.25), "flash alpha at 25 %")


func test_reduce_never_above_quarter_in_data() -> void:
	make_director()
	check(director.strengths.reduce_factor() <= 0.25, "reduce_motion_factor <= 0.25")
	director.strengths.reduce = true
	for key in director.strengths.sub("strengths")["shake"]:
		var base := director.strengths.base("shake", key, "amplitude")
		check(director.effective_shake_amplitude(key) <= base * 0.25, "shake %s at most 25 %%" % key)
	for key in director.strengths.sub("strengths")["flash"]:
		var base := director.strengths.base("flash", key, "alpha")
		check(director.effective_flash_alpha(key) <= base * 0.25, "flash %s at most 25 %%" % key)


func test_settings_file_flips_reduce_live() -> void:
	reset_settings()
	make_director()
	check_false(director.reduce_enabled(), "off by default")
	check(director.effective_shake_amplitude("bonk") > 0.0, "full shake")
	write_settings({SETTINGS_KEY: true})
	check_false(director.reduce_enabled(), "not re-read without a settings_changed signal")
	emit("settings_changed", [SETTINGS_KEY])
	check(director.reduce_enabled(), "re-read after settings_changed")
	check_eq(director.effective_shake_amplitude("bonk"), 0.0, "shake off")
	emit("object_bonked", ["castaway", "coconut"])
	check_eq(director.active_count("shake"), 0, "no shake source added while reduced")
	write_settings({SETTINGS_KEY: false})
	emit("settings_changed", [""])
	check_false(director.reduce_enabled(), "empty key re-reads everything")
	emit("settings_changed", ["music_volume"])
	check_false(director.reduce_enabled(), "other keys keep the value")


func test_new_director_reads_reduce_at_start() -> void:
	write_settings({SETTINGS_KEY: true})
	make_director()
	check(director.reduce_enabled(), "read in _ready")


func test_missing_corrupt_and_wrong_type_fall_back_to_off() -> void:
	DataDir.ensure_dir()
	check_false(FxSettings.read_reduce(DataDir.file("fx_missing_settings.json")), "missing file")
	var corrupt := DataDir.file("fx_corrupt_settings.json")
	var f := FileAccess.open(corrupt, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	check_false(FxSettings.read_reduce(corrupt), "corrupt file")
	var wrong := DataDir.file("fx_wrong_settings.json")
	f = FileAccess.open(wrong, FileAccess.WRITE)
	f.store_string(JSON.stringify({SETTINGS_KEY: "yes"}))
	f.close()
	check_false(FxSettings.read_reduce(wrong), "string value")
	check_false(FxSettings.read_reduce(""), "empty path")


func test_fx_scale_zero_disables_motion_juice() -> void:
	make_director(true, {"fx_scale": 0.0})
	check_eq(director.effective_hitstop_ms("bonk"), 0.0, "hit-stop 0 ms")
	check_eq(director.effective_shake_amplitude("bonk"), 0.0, "shake 0")
	check_eq(director.strengths.effective("recoil", "bonk", "px"), 0.0, "recoil 0")
	check_eq(director.strengths.effective("squash", "pop", "x"), 1.0, "no squash deviation")
	emit("object_bonked", ["castaway", "coconut"])
	check_false(director.hitstop_active(), "no hit-stop")
	check_eq(Engine.time_scale, 1.0, "time scale untouched")
	check_eq(director.active_count("shake"), 0, "no shake")
	check_eq(director.active_count("particles"), 0, "no particles")
	check(director.active_count("popup") > 0, "the BONK popup still reads")


func test_hitstop_clamped_by_max_and_scale() -> void:
	var s: Dictionary = Balance.get_section("feedback")["strengths"].duplicate(true)
	s["hitstop"]["bonk"]["ms"] = 500
	make_director(true, {"strengths": s})
	check_eq(director.effective_hitstop_ms("bonk"), 80.0, "clamped to hitstop_max_ms")
	check(director.strengths.num("hitstop_max_ms") <= 80.0, "default at most 80 ms")
	Balance.set_override("feedback", "hitstop_scale", 0.5)
	director.reload_config()
	check_eq(director.effective_hitstop_ms("bonk"), 80.0, "500 * 0.5 still clamped")
	Balance.clear_overrides()
	director.reload_config()
	check(director.effective_hitstop_ms("bonk") > 0.0, "data value active")
	check(director.effective_hitstop_ms("bonk") <= 80.0, "data value within 80 ms")


func test_gameplay_knockback_not_read() -> void:
	var text := ""
	for path in ["feedback_director.gd", "fx_strengths.gd", "feedback_map.gd", "fx_pool.gd", "shake.gd",
			"hit_stop.gd", "fx_settings.gd"]:
		text += FileAccess.get_file_as_string("res://scripts/feedback/" + path)
	for needle in ["knockback_distance", "\"castaway\", \"knockback", "EntityConfig", "CastawayConfig",
			"item_knockback"]:
		check_false(text.contains(needle), "feedback code reads %s" % needle)
	make_director(true, {"fx_scale": 0.0})
	var before := Balance.get_float("castaway", "knockback_distance")
	check(before > 0.0, "gameplay knockback stays configured")
