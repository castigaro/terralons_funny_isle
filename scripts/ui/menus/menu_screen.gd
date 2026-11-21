class_name MenuScreen
extends Control
## Base of every menu screen: shared theme, backdrop (dim over a running level), translated texts that follow a
## language switch live, initial focus, a real-time input guard and the overflow_sample() hook of the clip check.
## Screens only emit signals; the GameFlow root (scripts/main.gd) does every transition.
## Subclasses override _build(), and optionally handle_input(), focus_first() and overflow_sample().

const SFX_CLICK := "ui_click"
const SFX_HOVER := "ui_hover"

## Seconds after opening before keys are accepted (0 = at once).
var guard_s := 0.0
var cfg: Dictionary = {}
var _age := 0.0
var _texts: Array = []
var _backdrop: Panel
var _first_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = MenuTheme.get_theme()
	cfg = Balance.get_section("flow")
	_backdrop = Panel.new()
	_backdrop.name = "Backdrop"
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	set_dimmed(false)
	_build()
	I18n.locale_changed.connect(_on_locale_changed)
	refresh_texts()


func _build() -> void:
	pass


func _process(delta: float) -> void:
	# A hit-stop may still scale time when a screen opens; guards count unscaled seconds.
	var real := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	_age += real
	_tick(real)


func _tick(_delta: float) -> void:
	pass


## Seconds since the screen opened (real time of the ALWAYS-processing screen).
func age() -> float:
	return _age


func guard_passed() -> bool:
	return FlowRules.accepts_input(_age, guard_s)


## Lets tests skip the guard or delay without waiting frames.
func advance_time(seconds: float) -> void:
	_age += seconds
	_tick(seconds)


## Dims the level below (overlays) or keeps the clear colour visible (menus without a level).
func set_dimmed(dimmed: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(ArtPalette.color("ui_panel"), float(cfg.get("dim_alpha", 0.0)) if dimmed else 0.0)
	_backdrop.add_theme_stylebox_override("panel", box)


## Keyboard events the GameFlow root forwards; return true when used.
func handle_input(_event: InputEvent) -> bool:
	return false


func focus_first() -> void:
	if _first_focus != null and is_instance_valid(_first_focus) and _first_focus.is_visible_in_tree():
		_first_focus.grab_focus()


## Fills in the longest content for the clip check (optional).
func overflow_sample() -> void:
	pass


# --- Building blocks -------------------------------------------------------------------------------------

## A centred panel with a vertical box inside; returns the box.
func make_panel(parent: Control = self) -> VBoxContainer:
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	return box


func make_label(key: String, args: Dictionary = {}, variation: String = "") -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if variation != "":
		label.theme_type_variation = variation
	bind_text(label, key, args)
	return label


## A label whose text wraps inside the content width.
func make_wrapping_label(key: String, args: Dictionary = {}) -> Label:
	var label := make_label(key, args)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = float(cfg.get("content_width", 0))
	return label


## A menu button with an optional UI-pack icon: hover grabs focus, press plays the click sound.
func make_button(key: String, icon_path: String = "", args: Dictionary = {}) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(float(cfg.get("button_min_width", 0)),
			float(cfg.get("button_min_height", 0)))
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if icon_path != "":
		button.icon = load(icon_path)
		button.expand_icon = false
	bind_text(button, key, args)
	wire_button(button)
	return button


## A centred column for a vertical button stack: buttons added to it fill its width, so all of them take the width
## of the widest button in the current language (button_min_width stays the floor).
func make_button_column(parent: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "Buttons"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(column)
	return column


## Adds the theme's focus outline as a child panel of a control that draws no focus box itself (sliders); the
## ring is shown while the control has focus.
func add_focus_ring(control: Control) -> Panel:
	var ring := Panel.new()
	ring.name = "FocusRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.focus_mode = Control.FOCUS_NONE
	ring.show_behind_parent = false
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grow := float(cfg.get("focus_expand_px", 0))
	ring.offset_left = -grow
	ring.offset_top = -grow
	ring.offset_right = grow
	ring.offset_bottom = grow
	var style := MenuTheme.focus_style(cfg)
	style.set_expand_margin_all(0.0)
	ring.add_theme_stylebox_override("panel", style)
	control.add_child(ring)
	ring.visible = control.has_focus()
	control.focus_entered.connect(func() -> void: ring.visible = true)
	control.focus_exited.connect(func() -> void: ring.visible = false)
	return ring


func wire_button(button: BaseButton) -> void:
	button.mouse_entered.connect(_on_hover.bind(button))
	button.pressed.connect(play_click)


func _on_hover(button: Control) -> void:
	if button.focus_mode != Control.FOCUS_NONE and not button.has_focus():
		button.grab_focus()
		_play(SFX_HOVER)


func play_click() -> void:
	_play(SFX_CLICK)


func _play(sound_id: String) -> void:
	if Audio.audio_map().sfx.has(sound_id):
		Audio.play_sfx(sound_id)


# --- Translated texts ------------------------------------------------------------------------------------

## Shows I18n.t(key, args) on a Label or Button now and after every language switch; an empty key leaves the text.
func bind_text(control: Control, key: String, args: Dictionary = {}) -> void:
	for entry in _texts:
		if entry[0] == control:
			entry[1] = key
			entry[2] = args
			_apply_text(entry)
			return
	var item := [control, key, args]
	_texts.append(item)
	_apply_text(item)


func _apply_text(entry: Array) -> void:
	var control: Object = entry[0]
	if not is_instance_valid(control) or String(entry[1]) == "":
		return
	control.set("text", I18n.t(String(entry[1]), entry[2]))


func refresh_texts() -> void:
	for entry in _texts:
		_apply_text(entry)
	_refresh()


## Rebuilds dynamic texts after a language switch (subclasses).
func _refresh() -> void:
	pass


func _on_locale_changed(_code: String) -> void:
	refresh_texts()


# --- Input helpers ---------------------------------------------------------------------------------------

static func is_key_press(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.is_echo()


static func is_key_release(event: InputEvent) -> bool:
	return event is InputEventKey and not event.pressed and not event.is_echo()


static func is_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed


static func is_back(event: InputEvent) -> bool:
	return is_key_press(event) and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"))
