extends "res://tests/support/flow_case.gd"
## Settings and Progress files: siblings in the redirected data folder, values survive a reload (a "restart"),
## missing and corrupt files fall back to defaults without errors.

const SettingsScript := preload("res://scripts/autoload/settings.gd")
const ProgressScript := preload("res://scripts/autoload/progress.gd")


func test_files_are_siblings_below_the_testdata_root() -> void:
	var dir := use_data_dir("persist_paths")
	check_eq(Settings.file_path(), dir.path_join("settings.json"), "settings path")
	check_eq(Progress.file_path(), dir.path_join("progress.json"), "progress path")
	check_eq(Settings.file_path().get_base_dir(), Progress.file_path().get_base_dir(), "same folder")
	check_false(DataDir.path().begins_with("user://"), "not user://")
	check(DataDir.path().replace("\\", "/").to_lower().contains(".testdata"), "below testdata: %s" % DataDir.path())


func test_values_survive_a_restart() -> void:
	use_data_dir("persist_roundtrip")
	Progress.use_campaign(FIXTURE_CAMPAIGN)
	Settings.reload()
	Settings.set_value(SettingsModel.KEY_LOCALE, "de")
	Settings.set_value(SettingsModel.KEY_MUSIC, 0.25)
	Settings.set_value(SettingsModel.KEY_EFFECTS, 0.0)
	Settings.set_value(SettingsModel.KEY_REDUCE, true)
	Progress.record_win(SAMPLE, 2, 83.4)
	# Fresh autoload instances read the files like a new game start.
	var settings: Node = SettingsScript.new()
	add_node(settings)
	check_eq(settings.call("get_value", SettingsModel.KEY_LOCALE), "de", "locale")
	check_eq(settings.call("get_value", SettingsModel.KEY_MUSIC), 0.25, "music")
	check_eq(settings.call("get_value", SettingsModel.KEY_EFFECTS), 0.0, "effects")
	check_eq(settings.call("get_value", SettingsModel.KEY_REDUCE), true, "reduce")
	check_eq(I18n.get_locale(), "de", "locale applied at start")
	check_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")), "effects muted at start")
	var progress: Node = ProgressScript.new()
	progress.set("_campaign_path", FIXTURE_CAMPAIGN)
	add_node(progress)
	var model: ProgressModel = progress.call("model")
	check_true(model.is_won(SAMPLE), "win kept")
	check_true(model.is_unlocked(SMALL), "unlock kept")
	check_eq(model.best_stars(SAMPLE), 2, "stars kept")
	check_eq(model.best_time(SAMPLE), 83.4, "time kept")
	var raw: Dictionary = read_json(Progress.file_path())
	check_eq(raw["schema_version"], 1.0, "schema version written")
	check_eq(raw["unlocked"], [SAMPLE, SMALL], "unlocked written")


func test_missing_files_give_defaults() -> void:
	use_data_dir("persist_missing")
	Settings.reload()
	Progress.use_campaign(FIXTURE_CAMPAIGN)
	check_eq(Settings.last_status(), "missing", "settings missing")
	check_eq(Progress.last_status(), "missing", "progress missing")
	check_eq(I18n.get_locale(), "en", "English on first start")
	check_eq(Settings.get_value(SettingsModel.KEY_REDUCE), false, "reduce off by default")
	check_eq(Progress.model().unlocked_ids(), [SAMPLE], "only the first level")
	check_false(FileAccess.file_exists(Settings.file_path()), "nothing written by reading")


func test_corrupt_files_give_defaults() -> void:
	var dir := use_data_dir("persist_corrupt")
	write_file(dir.path_join("settings.json"), "{\"locale\": \"de\", ")
	write_file(dir.path_join("progress.json"), "[1, 2")
	Settings.reload()
	Progress.use_campaign(FIXTURE_CAMPAIGN)
	check_eq(Settings.last_status(), "corrupt", "settings corrupt")
	check_eq(Progress.last_status(), "corrupt", "progress corrupt")
	check_eq(I18n.get_locale(), "en", "defaults")
	check_eq(Progress.model().unlocked_ids(), [SAMPLE], "defaults")
	Progress.record_win(SAMPLE, 1, 50.0)
	check_eq(JsonStore.read(Progress.file_path())["status"], "ok", "corrupt file replaced by a valid one")
	write_file(dir.path_join("settings.json"), "{\"locale\": 5, \"music_volume\": \"x\"}")
	Settings.reload()
	check_eq(Settings.get_value(SettingsModel.KEY_LOCALE), "en", "wrong type locale")
	check_eq(Settings.get_value(SettingsModel.KEY_MUSIC), Balance.get_float("audio", "default_volume"), "volume")


func test_slider_save_is_debounced_and_flushed() -> void:
	use_data_dir("persist_debounce")
	Settings.reload()
	Settings.set_value(SettingsModel.KEY_MUSIC, 0.4, false)
	check_true(Settings.has_pending_save(), "pending")
	check_false(FileAccess.file_exists(Settings.file_path()), "not written yet")
	Settings.flush()
	check_false(Settings.has_pending_save(), "flushed")
	check_eq(read_json(Settings.file_path())["music_volume"], 0.4, "written on flush")
	Settings.set_value(SettingsModel.KEY_MUSIC, 0.6, false)
	await frames(int(ceilf(Balance.get_float("flow", "settings_save_debounce_s") * 60.0)) + 5)
	check_eq(read_json(Settings.file_path())["music_volume"], 0.6, "written after the debounce")
