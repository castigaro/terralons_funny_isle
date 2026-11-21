extends CanvasLayer
## Short centred cue on a dark panel (for example "Restarted!"); hides itself after a timeout.

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Label

var _key := ""
var _token := 0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var style := StyleBoxFlat.new()
	style.bg_color = ArtPalette.color("ui_panel")
	style.set_content_margin_all(24.0)
	style.set_corner_radius_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	_label.add_theme_color_override("font_color", ArtPalette.color("ui_text"))
	I18n.locale_changed.connect(_on_locale_changed)
	visible = false


## Shows the translated text of key for the given seconds.
func show_key(key: String, seconds: float) -> void:
	_key = key
	_token += 1
	var token := _token
	_label.text = I18n.t(key)
	visible = true
	get_tree().create_timer(maxf(seconds, 0.0), false).timeout.connect(_on_timeout.bind(token))


func current_key() -> String:
	return _key if visible else ""


func label_text() -> String:
	return _label.text


func _on_timeout(token: int) -> void:
	if token == _token:
		visible = false


func _on_locale_changed(_code: String) -> void:
	if _key != "":
		_label.text = I18n.t(_key)
