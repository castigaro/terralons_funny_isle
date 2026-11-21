extends "res://tests/support/level_case.gd"
## German overflow check: the HUD filled with its longest German content (task titles, hint, cues, banner, verbs)
## clips no label at 1280x720 and 1920x1080 and keeps its layout rules.

const Layout := preload("res://tests/ui/test_hud_layout.gd")
const FIXTURES := "res://tests/fixtures/levels"
const LEVELS := "res://data/levels"


func _keys(field: String) -> Array:
	var out := {}
	for dir in [LEVELS, FIXTURES]:
		for path in LevelDef.list_level_files(dir):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not data is Dictionary:
				continue
			for task in data.get("tasks", []):
				if task is Dictionary and String(task.get(field, "")) != "":
					out[String(task[field])] = true
	return out.keys()


func _longest_de(keys: Array, count: int) -> Array:
	var known := keys.filter(func(k: String) -> bool: return level.text_in(k, "de") != "")
	known.sort_custom(func(a: String, b: String) -> bool:
		return level.text_in(a, "de").length() > level.text_in(b, "de").length())
	return known.slice(0, count)


func _labels(n: Node, out: Array) -> void:
	if n is Label and (n as Label).is_visible_in_tree() and (n as Label).text != "":
		out.append(n)
	for c in n.get_children():
		_labels(c, out)


func _check_label(label: Label, tag: String) -> void:
	var font := label.get_theme_font("font")
	var fs := label.get_theme_font_size("font_size")
	var path := "%s %s '%s'" % [tag, label.get_path().get_concatenated_names().get_file(), label.text]
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var w := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		check(w <= label.size.x + 1.0, "%s fits: %.1f > %.1f" % [path, w, label.size.x])
	else:
		var limit := label.max_lines_visible if label.max_lines_visible > 0 else 999
		check(label.get_line_count() <= limit, "%s lines %d > %d (w %.1f, text %.1f, fs %d)" % [path, label.get_line_count(), limit, label.size.x, font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, fs])
		for word in label.text.split(" ", false):
			var ww := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			check(ww <= label.size.x + 1.0, "%s word '%s' fits" % [path, word])


func test_german_longest_content_fits() -> void:
	await open_level()
	var hud := level.hud()
	I18n.set_locale("de")
	await frames(1)
	var titles := _longest_de(_keys("title_key") + ["fixture.long_title"], 5)
	check_eq(titles.size(), 5, "five title keys")
	var hint := String(_longest_de(_keys("hint_key"), 1)[0])
	for view in Layout.SIZES:
		hud.set_layout_size(view)
		hud.overflow_sample(titles, hint)
		await frames(2)
		var tag := "DE %dx%d" % [view.x, view.y]
		check_eq(hud.task_rows().size(), int(Balance.get_value("rules", "tasks_max")), "%s rows" % tag)
		check_eq(hud.hint_key(), hint, "%s longest hint" % tag)
		check(hud.banner_visible(), "%s banner" % tag)
		var labels: Array = []
		_labels(hud.root_control(), labels)
		check(labels.size() >= 15, "%s labels found: %d" % [tag, labels.size()])
		for label in labels:
			_check_label(label, tag)
		Layout.check_layout(self, hud, view, tag)


func test_every_cue_and_verb_fits_in_german() -> void:
	await open_level()
	var hud := level.hud()
	I18n.set_locale("de")
	hud.set_layout_size(Vector2(1280, 720))
	for type_name in Hud.config()["failure_types"]:
		var key := String(Hud.config()["failure_types"][type_name]["key"])
		(hud.get("_throttle") as HudModel.CueThrottle).offer(key, float(hud.get("_clock")))
		hud.set("_cue_key", key)
		hud.call("_apply_cue_text")
		hud.panel("CueSlot").visible = true
		hud.force_layout()
		await frames(1)
		_check_label(hud.panel("CueLabel") as Label, "cue %s" % key)
		Layout.check_layout(self, hud, Vector2(1280, 720), "cue %s" % key)
	for verb in ["grab", "throw", "use"]:
		EventBus.interact_verb_changed.emit(verb, "coconut")
		await frames(1)
		_check_label(hud.panel("VerbLabel") as Label, "verb %s" % verb)
