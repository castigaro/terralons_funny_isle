extends TestCase
## Announcer captions: translated (German in German mode), replaced instead of stacked, at most two lines inside
## 60 % of the width at 1280x720 and 1920x1080, never catching the mouse or focus.

const SIZES := [Vector2(1280, 720), Vector2(1920, 1080)]


func _audio() -> Node:
	return root().get_node("Audio")


func _bus() -> Node:
	return root().get_node("EventBus")


func _i18n() -> Node:
	return root().get_node("I18n")


func _caption() -> Node:
	return _audio().call("caption")


func before_each() -> void:
	_audio().set("manual_clock", true)
	_audio().set("levels_dir", "res://tests/fixtures/audio/levels")


func after_each() -> void:
	_caption().call("set_layout_size", Vector2.ZERO)


func _label() -> Label:
	return _caption().call("label")


func test_german_and_english_captions() -> void:
	_i18n().call("set_locale", "de")
	_bus().level_started.emit("fx_level_1")
	check_true(_caption().call("is_showing"), "caption shown")
	check_eq(_label().text, "Los!", "German go")
	_i18n().call("set_locale", "en")
	check_eq(_label().text, "Go!", "live switch to English")
	_audio().call("reset_for_tests")
	_audio().set("manual_clock", true)
	_bus().level_started.emit("fx_level_1")
	check_eq(_label().text, "Go!", "English go")


func test_new_line_replaces_caption() -> void:
	_bus().announcer_line.emit("go", "audio.announcer_go", 2.0)
	_bus().announcer_line.emit("hurry_up", "audio.announcer_hurry_up", 2.0)
	check_eq(_label().text, "Hurry up!", "replaced")
	var labels := 0
	for child in _caption().call("panel").get_children():
		if child is Label:
			labels += 1
	check_eq(labels, 1, "one label")


func test_caption_hides_after_its_time() -> void:
	_bus().announcer_line.emit("go", "audio.announcer_go", 0.1)
	await frames(30)
	check_false(_caption().call("is_showing"), "hidden after seconds and fade")


func test_layout_fits_at_both_sizes_in_both_languages() -> void:
	var tuning: AudioTuning = _audio().call("tuning")
	for locale in ["en", "de"]:
		_i18n().call("set_locale", locale)
		for key in ["audio.announcer_go", "audio.announcer_hurry_up", "audio.announcer_times_up",
				"audio.announcer_level_complete"]:
			for size in SIZES:
				_bus().announcer_line.emit("x", key, 2.0)
				_caption().call("set_layout_size", size)
				var label := _label()
				var panel: Panel = _caption().call("panel")
				check(label.get_line_count() <= 2, "%s %s %s lines %d" % [locale, key, size, label.get_line_count()])
				check(panel.size.x <= size.x * tuning.caption_max_width_share + 0.5, "%s %s width" % [key, size])
				var inner := Rect2(Vector2.ZERO, panel.size)
				check(inner.encloses(Rect2(label.position, label.size)), "%s %s label inside panel" % [key, size])
				check(Rect2(Vector2.ZERO, size).encloses(Rect2(panel.position, panel.size)), "%s panel on screen" % key)
				var font := label.get_theme_font("font")
				var text_w := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
						label.get_theme_font_size("font_size")).x
				check(label.get_line_count() > 1 or text_w <= label.size.x + 0.5, "%s %s not clipped" % [key, size])


func test_caption_never_takes_input() -> void:
	var nodes: Array = [_caption().call("root_control"), _caption().call("panel"), _label()]
	for node in nodes:
		check_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s mouse filter" % node.name)
		check_eq(node.focus_mode, Control.FOCUS_NONE, "%s focus" % node.name)
	check_eq(_caption().layer, (_audio().call("tuning") as AudioTuning).caption_layer, "layer from balance")
	check_eq(_label().get_theme_font_size("font_size"), (_audio().call("tuning") as AudioTuning).caption_font_size,
			"font size from balance")


func test_suppressed_caption_stays_hidden() -> void:
	_i18n().call("set_locale", "en")
	_bus().announcer_line.emit("go", "audio.announcer_go", 2.0)
	check_true(_caption().call("is_showing"), "caption shown before")
	_caption().call("set_suppressed", true)
	check_true(_caption().call("is_suppressed"), "suppressed")
	check_false(_caption().call("is_showing"), "suppressing hides the caption")
	_bus().announcer_line.emit("level_complete", "audio.announcer_level_complete", 3.0)
	check_false(_caption().call("is_showing"), "line ignored while suppressed")
	_i18n().call("set_locale", "de")
	check_false(_caption().call("is_showing"), "locale change shows nothing")
	check_eq(_label().text, "", "no text kept")
	_caption().call("set_suppressed", false)
	_bus().announcer_line.emit("go", "audio.announcer_go", 2.0)
	check_true(_caption().call("is_showing"), "next line shows again")
	_caption().call("hide_now")
	_i18n().call("set_locale", "en")
