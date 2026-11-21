extends "res://tests/support/flow_case.gd"
## No clipped, trimmed, off-screen or overlapping menu text in English and German at 1280x720 and 1920x1080:
## title, level select (five tiles with long titles, stars, best time, Locked, Coming soon), settings, pause, intro
## card (most tasks with long texts), result (loss with many missing tasks) and credits.

const ClipCheck := preload("res://tests/support/clip_check.gd")
const SIZES := [Vector2(1280, 720), Vector2(1920, 1080)]
const SCENES := {
	"title": "res://scenes/ui/menus/title.tscn",
	"level_select": "res://scenes/ui/menus/level_select.tscn",
	"settings": "res://scenes/ui/menus/settings_panel.tscn",
	"pause": "res://scenes/ui/menus/pause_menu.tscn",
	"intro": "res://scenes/ui/menus/intro_card.tscn",
	"result": "res://scenes/ui/menus/result_screen.tscn",
	"credits": "res://scenes/ui/menus/credits.tscn",
}


func _fill(screen_name: String, node: MenuScreen) -> void:
	var tasks := int(Balance.get_section("rules").get("tasks_max", 0))
	match screen_name:
		"intro":
			node.call("clear_tasks")
			node.bind_text(node.get("title_label"), "flowfix.long_title")
			for i in tasks:
				node.call("add_task_row", "flowfix.long_task", i < 2)
			node.bind_text(node.get("goal_label"), "menu.intro.three_star", {"time": "10:00"})
		"result":
			var keys: Array = []
			for i in tasks - 1:
				keys.append("flowfix.long_task" if i == 0 else "flowfix.short_task")
			node.call("setup", {"won": false, "stars": 0, "time_left": 600.0, "missing_keys": keys,
					"next_enabled": false})
			(node.get("best_label") as Label).visible = true
			node.advance_time(node.guard_s)
		_:
			node.overflow_sample()


func test_no_clipped_text() -> void:
	use_data_dir("overflow")
	install_fixture_translations()
	Progress.use_campaign("res://tests/fixtures/flow/campaign_five.json")
	Progress.model().record_win(SAMPLE, 3, 599.0)
	Progress.model().record_win(SMALL, 1, 61.0)
	var errors: Array[String] = []
	for locale in ["en", "de"]:
		I18n.set_locale(locale)
		for size in SIZES:
			for screen_name in SCENES:
				var host := Control.new()
				host.size = size
				add_node(host)
				var node := (load(SCENES[screen_name]) as PackedScene).instantiate() as MenuScreen
				host.add_child(node)
				await frames(1)
				_fill(screen_name, node)
				await frames(2)
				errors.append_array(ClipCheck.check_tree(node, "%s@%dx%d" % [screen_name, size.x, size.y], locale,
						Rect2(host.global_position, size)))
				host.queue_free()
				await frames(1)
	check_eq(errors, [] as Array[String], "clip problems")


func test_clip_check_flags_a_small_button() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_node(host)
	var button := Button.new()
	button.text = "Wackeln und Blitze verringern"
	button.clip_text = true
	button.position = Vector2(10, 10)
	button.size = Vector2(60, 20)
	host.add_child(button)
	var off := Label.new()
	off.text = "Off screen"
	off.position = Vector2(1250, 700)
	host.add_child(off)
	await frames(1)
	button.size = Vector2(60, 20)
	var errors := ClipCheck.check_tree(host, "selftest", "de", Rect2(Vector2.ZERO, host.size))
	var joined := "\n".join(errors)
	check_has(joined, "needs width", "too narrow button found")
	check_has(joined, "leaves the viewport", "off-screen label found")


func test_button_columns_share_one_width() -> void:
	use_data_dir("button_columns")
	install_fixture_translations()
	for locale in ["en", "de"]:
		I18n.set_locale(locale)
		for size in SIZES:
			for screen_name in ["title", "pause"]:
				var host := Control.new()
				host.size = size
				add_node(host)
				var node := (load(SCENES[screen_name]) as PackedScene).instantiate() as MenuScreen
				host.add_child(node)
				await frames(2)
				var column := node.find_child("Buttons", true, false) as VBoxContainer
				var where := "%s %s@%dx%d" % [screen_name, locale, size.x, size.y]
				check_ne(column, null, "%s has a button column" % where)
				if column != null:
					var widest := 0.0
					for child in column.get_children():
						widest = maxf(widest, (child as Control).get_combined_minimum_size().x)
					check(column.get_child_count() >= 4, "%s stacks its buttons in the column" % where)
					for child in column.get_children():
						var button := child as Button
						check(absf(button.size.x - column.size.x) < 0.5, "%s: %s fills the column" % [where, button.name])
						check(absf(button.size.x - widest) < 0.5, "%s: %s has the widest width" % [where, button.name])
						check(button.size.x >= Balance.get_float("flow", "button_min_width"), "%s: min width" % where)
				host.queue_free()
				await frames(1)
	I18n.set_locale("en")
