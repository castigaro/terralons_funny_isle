class_name KeyCap
extends PanelContainer
## Keyboard key cap: shows the first key of one or more input actions on a nine-patch key from the UI pack.
## Common key names (Space, Enter, Shift) are translated through hud.key.*; letters stay raw key glyphs.

const KEY_PREFIX := "hud.key."
const TEXTURE_PATH := "res://assets/ui/ui-pack/PNG/Extra/Default/input_square.png"
const FONT_PATH := "res://assets/ui/ui-pack/Font/Kenney Future Narrow.ttf"
const PATCH_MARGIN := 12

var _actions: Array = []
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = get_node_or_null("KeyLabel") as Label
	if _label == null:
		_label = Label.new()
		_label.name = "KeyLabel"
		add_child(_label)
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", ArtPalette.color("ui_panel"))
	if ResourceLoader.exists(FONT_PATH):
		_label.add_theme_font_override("font", load(FONT_PATH))
	var style := StyleBoxTexture.new()
	style.texture = load(TEXTURE_PATH)
	style.set_texture_margin_all(PATCH_MARGIN)
	style.set_content_margin_all(PATCH_MARGIN)
	add_theme_stylebox_override("panel", style)
	var cfg := Balance.get_section("hud")
	_label.add_theme_font_size_override("font_size", int(cfg.get("key_font_size", 1)))
	custom_minimum_size = Vector2(float(cfg.get("key_min_width_px", 1)), 0.0)
	I18n.locale_changed.connect(_on_locale_changed)
	_relabel()


## Shows the first key of each action, joined (["move_up", "move_left", ...] -> "WASD").
func set_actions(actions: Array) -> void:
	_actions = actions.duplicate()
	_relabel()


func set_action(action: StringName) -> void:
	set_actions([action])


func label() -> Label:
	return _label


func label_text() -> String:
	return _label.text if _label != null else ""


## The hud.key.* key behind the text, or "" when the text is a raw key glyph.
func bound_key() -> String:
	if _actions.size() != 1:
		return ""
	var key := KEY_PREFIX + key_name(StringName(_actions[0])).to_lower()
	return key if I18n.has_key(key) else ""


## Raw key name of the first key event of an action ("Space", "E", "Enter"), or "" without a key.
static func key_name(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return OS.get_keycode_string(code).replace(" ", "_")
	return ""


func _relabel() -> void:
	if _label == null:
		return
	var parts := PackedStringArray()
	for action in _actions:
		var raw := key_name(StringName(action))
		var key := KEY_PREFIX + raw.to_lower()
		parts.append(I18n.t(key) if _actions.size() == 1 and I18n.has_key(key) else raw)
	_label.text = "".join(parts)


func _on_locale_changed(_code: String) -> void:
	_relabel()
