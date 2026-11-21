extends CanvasLayer
## Opaque error panel shown when a level cannot be loaded: a translated message, the level path and a Back button.

signal back_pressed

@onready var _panel: PanelContainer = $Panel
@onready var _message: Label = $Panel/Center/Box/Message
@onready var _path: Label = $Panel/Center/Box/Path
@onready var _back: Button = $Panel/Center/Box/Back


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var style := StyleBoxFlat.new()
	style.bg_color = ArtPalette.color("ui_panel")
	_panel.add_theme_stylebox_override("panel", style)
	_message.add_theme_color_override("font_color", ArtPalette.color("ui_text"))
	_path.add_theme_color_override("font_color", ArtPalette.color("ui_text"))
	_back.pressed.connect(_on_back)
	I18n.locale_changed.connect(_on_locale_changed)
	_refresh()
	visible = false


## Shows the panel for the level file that failed to load.
func show_error(path: String) -> void:
	_path.text = path
	_refresh()
	visible = true
	_back.grab_focus()


func message_text() -> String:
	return _message.text


func path_text() -> String:
	return _path.text


func press_back() -> void:
	_on_back()


func _on_back() -> void:
	back_pressed.emit()


func _on_locale_changed(_code: String) -> void:
	_refresh()


func _refresh() -> void:
	_message.text = I18n.t("level.error.load_failed")
	_back.text = I18n.t("level.error.back")
