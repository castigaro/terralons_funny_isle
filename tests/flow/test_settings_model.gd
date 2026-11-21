extends TestCase
## SettingsModel: defaults and per-key sanitising.


func test_defaults() -> void:
	var vol := Balance.get_float("audio", "default_volume")
	var d := SettingsModel.defaults(vol)
	check_eq(d, {"schema_version": 1, "locale": "en", "music_volume": vol, "effects_volume": vol,
			"reduce_shake_flashes": false}, "defaults")
	check_eq(SettingsModel.KEY_REDUCE, FxSettings.KEY, "shared key with the feedback director")


func test_sanitize_per_key() -> void:
	var s := SettingsModel.sanitize({"locale": "fr", "music_volume": 3, "effects_volume": "loud",
			"reduce_shake_flashes": "yes", "extra": 1}, 1.0)
	check_eq(s["locale"], "en", "unknown locale")
	check_eq(s["music_volume"], 1.0, "clamped")
	check_eq(s["effects_volume"], 1.0, "non-numeric -> default")
	check_eq(s["reduce_shake_flashes"], false, "non-bool -> off")
	check_false(s.has("extra"), "unknown key dropped")
	var ok := SettingsModel.sanitize({"locale": "de", "music_volume": 0, "effects_volume": 0.35,
			"reduce_shake_flashes": true}, 1.0)
	check_eq(ok["locale"], "de", "de kept")
	check_eq(ok["music_volume"], 0.0, "0 kept")
	check_eq(ok["effects_volume"], 0.35, "fraction kept")
	check_true(ok["reduce_shake_flashes"], "toggle kept")
	check_eq(SettingsModel.sanitize({"music_volume": -2.0}, 1.0)["music_volume"], 0.0, "clamped low")
	check_eq(SettingsModel.sanitize({"music_volume": NAN}, 0.7)["music_volume"], 0.7, "NaN -> default")


func test_garbage_and_future_versions() -> void:
	var d := SettingsModel.defaults(1.0)
	for data in [null, [], "x", 5]:
		check_eq(SettingsModel.sanitize(data, 1.0), d, "defaults for %s" % var_to_str(data))
	check_eq(SettingsModel.sanitize({"schema_version": 2, "locale": "de"}, 1.0), d, "future version")
	check_eq(SettingsModel.sanitize({"reduce_shake_flashes": true}, 1.0)["reduce_shake_flashes"], true,
			"missing version counts as current")
