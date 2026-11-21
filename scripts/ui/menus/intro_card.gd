extends MenuScreen
## Level intro card (D-9): level title, every task marked required or optional and the 3-star time goal before
## "Go!". It waits as long as the player needs (no auto-close). A key or mouse press after a short guard arms it and
## the release of that same key or button closes it, so the dismiss key is up again when the level starts and never
## moves the castaway. Presses during the guard or from before the card never arm. The timer starts after the card.

signal dismissed

const ICON_REQUIRED := "res://assets/ui/ui-pack/PNG/Yellow/Default/star.png"
const ICON_OPTIONAL := "res://assets/ui/ui-pack/PNG/Yellow/Default/star_outline.png"

var title_label: Label
var goal_label: Label
var hint_label: Label
var task_rows: Array = []
var _tasks_box: VBoxContainer
var _closed := false
## The press that will close the card on its release: {"key": physical or logical keycode} or {"mouse": index}.
var _armed := {}


func _build() -> void:
	guard_s = float(cfg.get("intro_guard_s", 0))
	var box := make_panel()
	title_label = make_label("", {}, MenuTheme.VARIATION_HEADING)
	box.add_child(title_label)
	_tasks_box = VBoxContainer.new()
	_tasks_box.name = "Tasks"
	box.add_child(_tasks_box)
	goal_label = make_wrapping_label("")
	goal_label.theme_type_variation = MenuTheme.VARIATION_ACCENT
	box.add_child(goal_label)
	hint_label = make_wrapping_label("menu.intro.go_hint")
	hint_label.modulate.a = 0.0
	box.add_child(hint_label)


## Fills the card: def is the LevelDef, three_star_s the seconds that must be left for 3 stars.
func setup(def: LevelDef, three_star_s: float) -> void:
	bind_text(title_label, def.title_key)
	clear_tasks()
	for task in def.tasks:
		add_task_row(HudModel.task_title_key(task), bool(task.get("required", false)))
	bind_text(goal_label, "menu.intro.three_star", {"time": FlowRules.format_time(three_star_s, true)})


func clear_tasks() -> void:
	for row in task_rows:
		_tasks_box.remove_child(row)
		row.queue_free()
	task_rows.clear()


func add_task_row(text_key: String, required: bool) -> void:
	var row := HBoxContainer.new()
	row.name = "Task%d" % task_rows.size()
	var icon := TextureRect.new()
	icon.texture = load(ICON_REQUIRED if required else ICON_OPTIONAL)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var px := float(cfg.get("star_px", 0))
	icon.custom_minimum_size = Vector2(px, px)
	row.add_child(icon)
	var marker := make_label("menu.intro.required" if required else "menu.intro.optional")
	marker.theme_type_variation = MenuTheme.VARIATION_ACCENT if required else ""
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	marker.custom_minimum_size.x = float(cfg.get("value_label_width", 0)) * 2.0
	row.add_child(marker)
	var text := make_label(text_key)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = float(cfg.get("content_width", 0)) - marker.custom_minimum_size.x - px
	row.add_child(text)
	_tasks_box.add_child(row)
	task_rows.append(row)


func task_texts() -> Array:
	var out: Array = []
	for row in task_rows:
		out.append([String(row.get_child(1).text), String(row.get_child(2).text)])
	return out


func is_closed() -> bool:
	return _closed


func is_armed() -> bool:
	return not _armed.is_empty()


func _tick(_delta: float) -> void:
	if hint_label != null and guard_passed():
		hint_label.modulate.a = 1.0


func close() -> void:
	if _closed:
		return
	_closed = true
	dismissed.emit()


static func _key_id(event: InputEventKey) -> int:
	return int(event.physical_keycode) if event.physical_keycode != KEY_NONE else int(event.keycode)


## Every key counts as "any key"; all key events are consumed so none reaches the level or the flow keys.
func handle_input(event: InputEvent) -> bool:
	if not event is InputEventKey or event.is_echo():
		return false
	if is_key_press(event):
		if guard_passed() and _armed.is_empty():
			_armed = {"key": _key_id(event)}
	elif is_key_release(event) and int(_armed.get("key", -1)) == _key_id(event):
		close()
	return true


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.pressed:
		if guard_passed() and _armed.is_empty():
			_armed = {"mouse": int(event.button_index)}
	elif int(_armed.get("mouse", -1)) == int(event.button_index):
		close()
	accept_event()
