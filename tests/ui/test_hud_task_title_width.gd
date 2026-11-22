extends TestCase
## Every HUD task title fits on one line: the EN and DE text of HudModel.task_title_key for each task in
## data/levels/*.json is measured with the UI font at task_font_size against task_name_width_px.

const LEVEL_DIR := "res://data/levels"


func _tasks() -> Array:
	var out: Array = []
	for file in DirAccess.get_files_at(LEVEL_DIR):
		if not file.ends_with(".json"):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_DIR.path_join(file)))
		if data is Dictionary:
			for task in data.get("tasks", []):
				out.append({"level": file.get_basename(), "task": task})
	return out


func test_task_name_is_one_line() -> void:
	check_eq(int(Balance.get_value("hud", "task_name_max_lines")), 1, "task_name_max_lines")


func test_every_task_title_fits_one_line() -> void:
	var font := MenuTheme.font()
	var size := int(Balance.get_value("hud", "task_font_size"))
	var limit := float(Balance.get_value("hud", "task_name_width_px"))
	var tasks := _tasks()
	check(tasks.size() >= 15, "tasks found: %d" % tasks.size())
	for entry in tasks:
		var key := HudModel.task_title_key(entry["task"])
		check(key != "", "%s task %s has a title key" % [entry["level"], str(entry["task"].get("id"))])
		for loc in I18n.LOCALES:
			var text := I18n.text_in(key, loc)
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			check(width <= limit, "%s (%s) '%s' is %.0f px > %.0f px" % [key, loc, text, width, limit])
