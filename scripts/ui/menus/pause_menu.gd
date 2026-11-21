extends MenuScreen
## Pause menu (Esc): Resume, Restart (R), Settings, Level select and Quit over the frozen level. Esc resumes and
## R restarts from here as well.

signal resume_pressed
signal restart_pressed
signal settings_pressed
signal level_select_pressed
signal quit_pressed

const ICON_RESUME := "res://assets/ui/ui-pack/PNG/Extra/Default/icon_play_light.png"
const ICON_RESTART := "res://assets/ui/ui-pack/PNG/Extra/Default/icon_repeat_light.png"
const ICON_SETTINGS := "res://assets/ui/ui-pack/PNG/Yellow/Default/slide_hangle.png"
const ICON_LEVELS := "res://assets/ui/ui-pack/PNG/Yellow/Default/arrow_basic_w.png"
const ICON_QUIT := "res://assets/ui/ui-pack/PNG/Yellow/Default/icon_cross.png"

var resume_button: Button
var restart_button: Button
var settings_button: Button
var level_select_button: Button
var quit_button: Button


func _build() -> void:
	var box := make_panel()
	box.add_child(make_label("menu.pause.title", {}, MenuTheme.VARIATION_HEADING))
	resume_button = _add(box, make_button("menu.resume", ICON_RESUME), resume_pressed)
	restart_button = _add(box, make_button("menu.restart", ICON_RESTART), restart_pressed)
	settings_button = _add(box, make_button("menu.settings", ICON_SETTINGS), settings_pressed)
	level_select_button = _add(box, make_button("menu.level_select", ICON_LEVELS), level_select_pressed)
	quit_button = _add(box, make_button("menu.quit", ICON_QUIT), quit_pressed)
	_first_focus = resume_button


func _add(box: Control, button: Button, sig: Signal) -> Button:
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(sig.emit)
	box.add_child(button)
	return button


func handle_input(event: InputEvent) -> bool:
	if not is_key_press(event):
		return false
	if event.is_action_pressed("pause"):
		resume_pressed.emit()
		return true
	if event.is_action_pressed("restart"):
		restart_pressed.emit()
		return true
	return false
