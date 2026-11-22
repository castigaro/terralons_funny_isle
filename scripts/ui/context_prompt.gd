class_name ContextPrompt
extends Node2D
## World-space key prompt bubble from level data ({id, anchor, action, text_key}): follows its anchor node and
## frees itself for good once the player has used its action (PromptMemory), also after restarts.

const FONT_PATH := MenuTheme.FONT
const KEY_CAP_SCENE := preload("res://scenes/ui/key_cap.tscn")
## Prompt action -> input actions whose first keys the key cap shows.
const ACTION_KEYS := {
	"move": [&"move_up", &"move_left", &"move_down", &"move_right"],
	"dash": [&"dash"],
	"grab": [&"interact"],
	"throw": [&"interact"],
	"use": [&"interact"],
}

var prompt_id := ""
var action := ""
var text_key := ""
var _anchor: Node2D
var _offset := Vector2.ZERO
var _below_offset := Vector2.ZERO
var _hud_gap := 0.0
var _below := false
var _level: Node
var _panel: PanelContainer
var _key_cap: KeyCap
var _label: Label


## prompt is a normalized LevelDef prompt; level translates level text keys (LevelBase.text).
func setup(prompt: Dictionary, anchor: Node2D, level: Node = null) -> void:
	prompt_id = String(prompt.get("id", ""))
	action = String(prompt.get("action", ""))
	text_key = String(prompt.get("text_key", ""))
	_anchor = anchor
	_level = level
	name = "Prompt_%s" % prompt_id


func _ready() -> void:
	if PromptMemory.is_used(action):
		queue_free()
		return
	var cfg := Balance.get_section("hud")
	_offset = Vector2(0.0, -float(cfg.get("prompt_offset_px", 0)))
	_below_offset = Vector2(0.0, float(cfg.get("prompt_below_offset_px", 0)))
	_hud_gap = float(cfg.get("prompt_hud_gap_px", 0))
	_panel = PanelContainer.new()
	_panel.name = "Bubble"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	var bg := ArtPalette.color("ui_panel")
	bg.a = float(cfg.get("panel_alpha", 1.0))
	style.bg_color = bg
	style.set_corner_radius_all(int(cfg.get("panel_corner_px", 0)))
	style.set_content_margin_all(float(cfg.get("panel_padding_px", 0)) / 2.0)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var box := HBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", int(cfg.get("row_separation_px", 0)))
	_panel.add_child(box)
	_key_cap = KEY_CAP_SCENE.instantiate()
	_key_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(_key_cap)
	_key_cap.set_actions(ACTION_KEYS.get(action, []))
	_label = Label.new()
	_label.name = "TextLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", ArtPalette.color("ui_text"))
	_label.add_theme_font_size_override("font_size", int(cfg.get("prompt_font_size", 1)))
	if ResourceLoader.exists(FONT_PATH):
		_label.add_theme_font_override("font", load(FONT_PATH))
	box.add_child(_label)
	_relabel()
	EventBus.castaway_step.connect(_on_dismiss_signal.bind("castaway_step").unbind(2))
	EventBus.castaway_dashed.connect(_on_dismiss_signal.bind("castaway_dashed").unbind(2))
	EventBus.object_grabbed.connect(_on_dismiss_signal.bind("object_grabbed").unbind(1))
	EventBus.object_thrown.connect(_on_dismiss_signal.bind("object_thrown").unbind(1))
	EventBus.object_used.connect(_on_dismiss_signal.bind("object_used").unbind(2))
	I18n.locale_changed.connect(_on_locale_changed)
	_follow()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	if _panel == null:
		return
	if _anchor == null or not is_instance_valid(_anchor) or not _anchor.is_inside_tree():
		visible = false
		return
	visible = true
	_panel.size = _panel.get_combined_minimum_size()
	_place(false)
	_below = false
	var hud := _hud()
	if hud == null or not _blocked(hud):
		return
	_place(true)
	if _blocked(hud):
		_place(false)
	else:
		_below = true


## Puts the bubble above the anchor, or below it when below is true.
func _place(below: bool) -> void:
	if below:
		global_position = _anchor.global_position + _below_offset
		_panel.position = Vector2(-_panel.size.x / 2.0, 0.0)
	else:
		global_position = _anchor.global_position + _offset
		_panel.position = Vector2(-_panel.size.x / 2.0, -_panel.size.y)


func _hud() -> Hud:
	if _level == null or not is_instance_valid(_level) or not _level.has_method("hud"):
		return null
	var hud := _level.call("hud") as Hud
	return hud if hud != null and hud.visible and hud.root_control() != null else null


func _blocked(hud: Hud) -> bool:
	return hud.blocks_rect(hud.screen_rect_of(_panel, Rect2(Vector2.ZERO, _panel.size)), _hud_gap)


## True while the bubble is flipped below its anchor to stay clear of a HUD panel.
func placed_below() -> bool:
	return _below


func _on_dismiss_signal(signal_name: String) -> void:
	var used := HudModel.prompt_dismiss_action(signal_name)
	if used != action:
		return
	PromptMemory.mark(used)
	queue_free()


func _relabel() -> void:
	if _label == null:
		return
	_label.text = String(_level.call("text", text_key)) if _level != null and _level.has_method("text") \
			else I18n.t(text_key)


func _on_locale_changed(_code: String) -> void:
	_relabel()


func anchor() -> Node2D:
	return _anchor


func label() -> Label:
	return _label


func key_cap() -> KeyCap:
	return _key_cap


func bubble() -> PanelContainer:
	return _panel
