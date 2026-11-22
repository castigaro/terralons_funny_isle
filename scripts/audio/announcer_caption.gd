extends CanvasLayer
## On-screen caption of the announcer line: centred panel near the top, at most two lines, translated live.

const FONT_PATH := MenuTheme.FONT

var _tuning: AudioTuning = AudioTuning.new()
var _root: Control
var _panel: Panel
var _label: Label
var _style := StyleBoxFlat.new()
var _key := ""
var _remaining := 0.0
var _fade_left := 0.0
var _layout_size := Vector2.ZERO
var _suppressed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.focus_mode = Control.FOCUS_NONE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.focus_mode = Control.FOCUS_NONE
	_panel.add_theme_stylebox_override("panel", _style)
	_root.add_child(_panel)
	_label = Label.new()
	_label.name = "Label"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.focus_mode = Control.FOCUS_NONE
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.max_lines_visible = 2
	_label.add_theme_color_override("font_color", Color.WHITE)
	if ResourceLoader.exists(FONT_PATH):
		_label.add_theme_font_override("font", load(FONT_PATH))
	_panel.add_child(_label)
	_root.visible = false
	configure(_tuning)
	var bus := get_node_or_null("/root/EventBus")
	if bus != null and bus.has_signal("announcer_line"):
		bus.connect("announcer_line", _on_announcer_line)
	var i18n := get_node_or_null("/root/I18n")
	if i18n != null and i18n.has_signal("locale_changed"):
		i18n.connect("locale_changed", _on_locale_changed)
	get_viewport().size_changed.connect(_relayout)


## Applies sizes, layer and colours from the audio tuning.
func configure(tuning: AudioTuning) -> void:
	_tuning = tuning
	layer = tuning.caption_layer
	if _label == null:
		return
	_style.bg_color = Color(0.0, 0.0, 0.0, tuning.caption_panel_alpha)
	_style.set_corner_radius_all(tuning.caption_padding)
	_label.add_theme_font_size_override("font_size", tuning.caption_font_size)
	_relayout()


func _process(delta: float) -> void:
	if _root == null or not _root.visible:
		return
	if _remaining > 0.0:
		_remaining -= delta
		return
	if _fade_left > 0.0 and _tuning.caption_fade > 0.0:
		_fade_left -= delta
		_root.modulate.a = clampf(_fade_left / _tuning.caption_fade, 0.0, 1.0)
		return
	hide_now()


## Shows the translated caption key for seconds, replacing any caption on screen.
func show_line(caption_key: String, seconds: float) -> void:
	if _suppressed:
		return
	_key = caption_key
	_remaining = maxf(seconds, 0.0)
	_fade_left = _tuning.caption_fade
	_root.modulate.a = 1.0
	_root.visible = true
	_label.text = tr(_key)
	_relayout()


func hide_now() -> void:
	_key = ""
	_remaining = 0.0
	_fade_left = 0.0
	if _root != null:
		_root.visible = false
		_label.text = ""


## Suppressed captions are not shown (the result screen is open); the voice line itself still plays.
func set_suppressed(on: bool) -> void:
	_suppressed = on
	if on:
		hide_now()


func is_suppressed() -> bool:
	return _suppressed


func _on_announcer_line(_line_id: String, caption_key: String, seconds: float) -> void:
	show_line(caption_key, seconds)


func _on_locale_changed(_code: String) -> void:
	if _key != "":
		_label.text = tr(_key)
		_relayout()


func _relayout() -> void:
	layout_for(_layout_size if _layout_size != Vector2.ZERO else get_viewport().get_visible_rect().size)


## Lays the panel out for a visible area of the given size (also used by tests for 1280x720 and 1920x1080).
func layout_for(view: Vector2) -> void:
	if _label == null:
		return
	var font := _label.get_theme_font("font")
	var font_size := _label.get_theme_font_size("font_size")
	var pad := float(_tuning.caption_padding)
	var max_w := view.x * _tuning.caption_max_width_share - pad * 2.0
	var natural := font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width := minf(ceilf(natural) + 2.0, max_w)
	_label.size = Vector2(width, font.get_height(font_size))
	var lines := clampi(_label.get_line_count(), 1, 2)
	var height := font.get_height(font_size) * lines
	_label.size = Vector2(width, height)
	_label.position = Vector2(pad, pad)
	_panel.size = Vector2(width + pad * 2.0, height + pad * 2.0)
	_panel.position = Vector2((view.x - _panel.size.x) / 2.0, view.y * _tuning.caption_top_share)


## Uses a fixed visible area for the layout (tests); Vector2.ZERO follows the viewport again.
func set_layout_size(view: Vector2) -> void:
	_layout_size = view
	_relayout()


func label() -> Label:
	return _label


func panel() -> Panel:
	return _panel


func root_control() -> Control:
	return _root


func caption_key() -> String:
	return _key


func is_showing() -> bool:
	return _root != null and _root.visible
