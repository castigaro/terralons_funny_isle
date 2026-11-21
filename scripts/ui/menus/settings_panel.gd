extends MenuScreen
## Settings (from the title and from the pause menu): language buttons named in their own language, music and
## effects sliders (0-100 %, 0 mutes the bus), the "reduce screen shake and flashes" toggle and Back. Every change
## goes through the Settings autoload; slider saves are debounced and flushed on drag end and when closing.

signal back_pressed

const ICON_BACK := "res://assets/ui/ui-pack/PNG/Yellow/Default/arrow_basic_w.png"

var english_button: Button
var german_button: Button
var music_slider: HSlider
var effects_slider: HSlider
var music_value: Label
var effects_value: Label
var reduce_toggle: CheckBox
var back_button: Button


func _build() -> void:
	var box := make_panel()
	box.add_child(make_label("menu.settings.title", {}, MenuTheme.VARIATION_HEADING))
	box.add_child(make_label("menu.settings.language"))
	var langs := HBoxContainer.new()
	langs.alignment = BoxContainer.ALIGNMENT_CENTER
	var group := ButtonGroup.new()
	english_button = make_button("menu.lang.en")
	german_button = make_button("menu.lang.de")
	for pair in [[english_button, "en"], [german_button, "de"]]:
		var button: Button = pair[0]
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_on_language.bind(String(pair[1])))
		langs.add_child(button)
	box.add_child(langs)
	var music := _slider_row(box, "menu.settings.music", SettingsModel.KEY_MUSIC)
	music_slider = music[0]
	music_value = music[1]
	var effects := _slider_row(box, "menu.settings.effects", SettingsModel.KEY_EFFECTS)
	effects_slider = effects[0]
	effects_value = effects[1]
	reduce_toggle = CheckBox.new()
	reduce_toggle.focus_mode = Control.FOCUS_ALL
	reduce_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reduce_toggle.custom_minimum_size.y = float(cfg.get("button_min_height", 0))
	reduce_toggle.button_pressed = bool(Settings.get_value(SettingsModel.KEY_REDUCE))
	bind_text(reduce_toggle, "menu.settings.reduce_shake")
	wire_button(reduce_toggle)
	reduce_toggle.toggled.connect(_on_reduce)
	box.add_child(reduce_toggle)
	back_button = make_button("menu.back", ICON_BACK)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(_on_back)
	box.add_child(back_button)
	_sync_language()
	_first_focus = english_button if I18n.get_locale() == "en" else german_button


func _slider_row(box: Control, key: String, setting: String) -> Array:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var label := make_label(key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.custom_minimum_size.x = float(cfg.get("value_label_width", 0)) * 2.0
	row.add_child(label)
	var slider := HSlider.new()
	slider.focus_mode = Control.FOCUS_ALL
	slider.min_value = 0.0
	slider.max_value = float(cfg.get("percent_scale", 0))
	slider.step = float(cfg.get("slider_step_percent", 0))
	slider.custom_minimum_size = Vector2(float(cfg.get("slider_width", 0)), float(cfg.get("slider_height", 0)))
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value = _percent(float(Settings.get_value(setting)))
	slider.mouse_entered.connect(_on_hover.bind(slider))
	add_focus_ring(slider)
	row.add_child(slider)
	var value := make_label("menu.percent", {"value": int(slider.value)})
	value.custom_minimum_size.x = float(cfg.get("value_label_width", 0))
	row.add_child(value)
	slider.value_changed.connect(_on_slider.bind(setting, value))
	slider.drag_ended.connect(func(_changed: bool) -> void: Settings.flush())
	box.add_child(row)
	return [slider, value]


func _percent(linear: float) -> float:
	return roundf(linear * float(cfg.get("percent_scale", 0)))


func _on_slider(value: float, setting: String, label: Label) -> void:
	bind_text(label, "menu.percent", {"value": int(value)})
	var scale := float(cfg.get("percent_scale", 0))
	Settings.set_value(setting, value / scale if scale > 0.0 else 0.0, false)


func _on_reduce(on: bool) -> void:
	Settings.set_value(SettingsModel.KEY_REDUCE, on)


func _on_language(code: String) -> void:
	Settings.set_value(SettingsModel.KEY_LOCALE, code)
	_sync_language()


func _sync_language() -> void:
	english_button.set_pressed_no_signal(I18n.get_locale() == "en")
	german_button.set_pressed_no_signal(I18n.get_locale() == "de")


func _on_back() -> void:
	Settings.flush()
	back_pressed.emit()


func _refresh() -> void:
	if english_button != null:
		_sync_language()


func handle_input(event: InputEvent) -> bool:
	if is_back(event):
		_on_back()
		return true
	return false


func _exit_tree() -> void:
	Settings.flush()
