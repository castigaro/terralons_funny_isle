extends "res://tests/support/flow_case.gd"
## Live settings: language switch updates every screen without reload, sliders drive the buses (0 mutes), the
## reduce toggle is written before settings_changed and reaches the feedback director.

const SignalRecorder := preload("res://tests/support/signal_recorder.gd")
const DIRECTOR := "res://scripts/feedback/feedback_director.gd"


func _texts(node: Node) -> Array:
	var out: Array = []
	if (node is Label or node is Button) and (node as Control).is_visible_in_tree():
		out.append(String(node.get("text")))
	for child in node.get_children():
		out.append_array(_texts(child))
	return out


func test_language_switch_is_live_on_every_screen() -> void:
	await open_flow("live_lang")
	var screens := [FlowRules.Screen.TITLE, FlowRules.Screen.LEVEL_SELECT, FlowRules.Screen.SETTINGS,
			FlowRules.Screen.CREDITS]
	for s in screens:
		var node: MenuScreen = flow.call("show_screen", s)
		await frames(1)
		var before := _texts(node)
		Settings.set_value(SettingsModel.KEY_LOCALE, "de")
		await frames(1)
		var after := _texts(node)
		check_ne(before, after, "texts changed on screen %d" % s)
		check_true(after.has(I18n.text_in("menu.back", "de")) or s == FlowRules.Screen.TITLE
				or s == FlowRules.Screen.CREDITS, "German back on %d" % s)
		Settings.set_value(SettingsModel.KEY_LOCALE, "en")
		await frames(1)
		check_eq(_texts(node), before, "back to English on %d" % s)
	check_true(flow.call("start_level_flow", SAMPLE, true), "level starts")
	var intro := screen_node()
	var intro_before := _texts(intro)
	Settings.set_value(SettingsModel.KEY_LOCALE, "de")
	await frames(1)
	check_ne(_texts(intro), intro_before, "intro card follows")
	check_has(_texts(intro), "Beispielstrand", "level title German")
	check_has(_texts(intro), I18n.text_in("menu.intro.required", "de"), "required marker German")
	await wait_guard()
	await key(KEY_SPACE)
	await key(KEY_ESCAPE)
	check_has(_texts(screen_node()), I18n.text_in("menu.resume", "de"), "pause German")
	await key(KEY_ESCAPE)
	await lose_level()
	var result := screen_node()
	check_has(_texts(result), I18n.text_in("menu.result.lost", "de"), "result German")
	Settings.set_value(SettingsModel.KEY_LOCALE, "en")
	await frames(1)
	check_has(_texts(result), I18n.text_in("menu.result.lost", "en"), "result back to English")
	check_has(_texts(result), I18n.t("menu.result.missing", {"tasks": [{"key": "fixture.reach_a_title"}]}),
			"missing tasks re-rendered")


func test_title_language_toggle() -> void:
	await open_flow("live_toggle")
	var title := screen_node()
	var toggle: Button = title.get("language_button")
	check_eq(toggle.text, "Deutsch", "shows the other language")
	await click(toggle)
	check_eq(I18n.get_locale(), "de", "switched")
	check_eq(toggle.text, "English", "now offers English")
	check_eq(read_json(Settings.file_path())["locale"], "de", "saved")
	check_eq((title.get("play_button") as Button).text, I18n.text_in("menu.play", "de"), "play German")


func test_sliders_drive_the_buses() -> void:
	await open_flow("live_sliders")
	var panel: MenuScreen = flow.call("show_screen", FlowRules.Screen.SETTINGS, FlowRules.Screen.TITLE)
	var music: HSlider = panel.get("music_slider")
	var effects: HSlider = panel.get("effects_slider")
	check_eq(music.value, 100.0, "full volume by default")
	check_eq(music.step, Balance.get_float("flow", "slider_step_percent"), "step")
	music.value = 0.0
	check_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "0 mutes music")
	check_eq(Audio.get_volume("music"), 0.0, "volume 0")
	effects.value = 50.0
	check_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")), "effects audible")
	check_eq(Audio.get_volume("effects"), 0.5, "effects half")
	check_eq((panel.get("effects_value") as Label).text, "50 %", "value label")
	music.value = 35.0
	check_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "unmuted again")
	flow.call("go_back")
	await frames(1)
	var saved: Dictionary = read_json(Settings.file_path())
	check_eq(saved["music_volume"], 0.35, "music saved on close")
	check_eq(saved["effects_volume"], 0.5, "effects saved on close")


func test_reduce_toggle_written_before_signal() -> void:
	await open_flow("live_reduce")
	var panel: MenuScreen = flow.call("show_screen", FlowRules.Screen.SETTINGS, FlowRules.Screen.TITLE)
	var toggle: CheckBox = panel.get("reduce_toggle")
	check_false(toggle.button_pressed, "off by default")
	var director: Node = (load(DIRECTOR) as GDScript).new()
	add_node(director)
	await frames(1)
	check_false(director.get("strengths").reduce, "director starts full")
	var seen := []
	var on_change := func(k: String) -> void: seen.append([k, FxSettings.read_reduce(Settings.file_path())])
	EventBus.settings_changed.connect(on_change)
	await click(toggle)
	EventBus.settings_changed.disconnect(on_change)
	check_eq(seen, [[FxSettings.KEY, true]], "file already true when the signal fires")
	check_true(director.get("strengths").reduce, "feedback director switched")
	await click(toggle)
	check_false(FxSettings.read_reduce(Settings.file_path()), "off again")


func test_reload_reapplies_saved_values() -> void:
	var dir := use_data_dir("live_reload")
	write_file(dir.path_join("settings.json"), JSON.stringify({"schema_version": 1, "locale": "de",
			"music_volume": 0.0, "effects_volume": 0.3, "reduce_shake_flashes": true}))
	Settings.reload()
	check_eq(I18n.get_locale(), "de", "locale")
	check_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "music muted")
	check_eq(Audio.get_volume("effects"), 0.3, "effects")
	TranslationServer.set_locale("de")
	use_data_dir("live_first_start")
	Settings.reload()
	check_eq(I18n.get_locale(), "en", "first start is English even after a German locale")
