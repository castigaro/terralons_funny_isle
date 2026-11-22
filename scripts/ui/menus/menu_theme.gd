class_name MenuTheme
extends RefCounted
## Builds the shared menu theme from data/balance/flow.json and the art palette: one display font for every text
## (headings and body differ only by size and colour), the blue depth buttons, slider and checkbox textures of the UI
## pack and a high-contrast focus outline (shape, not colour only).

## The only UI font: Kenney Future with fixed X, x, %, sharp s and en dash glyphs (tools/derive_font.py).
const FONT := "res://assets/ui/fonts-derived/Kenney Future Fixed.ttf"
const BUTTON_TEX := "res://assets/ui/ui-pack/PNG/Blue/Default/button_rectangle_depth_gradient.png"
const TILE_TEX := "res://assets/ui/ui-pack/PNG/Blue/Default/button_square_depth_gradient.png"
const SLIDER_TRACK := "res://assets/ui/ui-pack/PNG/Blue/Default/slide_horizontal_grey.png"
const SLIDER_FILL := "res://assets/ui/ui-pack/PNG/Blue/Default/slide_horizontal_color.png"
const SLIDER_GRABBER := "res://assets/ui/ui-pack/PNG/Blue/Default/slide_hangle.png"
const SLIDER_GRABBER_FOCUS := "res://assets/ui/ui-pack/PNG/Yellow/Default/slide_hangle.png"
const CHECK_ON := "res://assets/ui/ui-pack/PNG/Blue/Default/check_square_color_checkmark.png"
const CHECK_OFF := "res://assets/ui/ui-pack/PNG/Blue/Default/check_square_grey.png"
const VARIATION_TITLE := "TitleLabel"
const VARIATION_HEADING := "HeadingLabel"
const VARIATION_TILE := "TileButton"
const VARIATION_ACCENT := "AccentLabel"

static var _cached: Theme = null


## The shared theme (built once per process).
static func get_theme() -> Theme:
	if _cached == null:
		_cached = build(Balance.get_section("flow"))
	return _cached


## The shared UI font (MenuTheme.FONT).
static func font() -> FontFile:
	return load(FONT) as FontFile


static func heading_font() -> FontFile:
	return font()


static func body_font() -> FontFile:
	return font()


## The high-contrast focus outline of buttons, checkboxes and the slider focus ring (MenuScreen.add_focus_ring).
static func focus_style(cfg: Dictionary) -> StyleBoxFlat:
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(int(cfg.get("focus_outline_px", 0)))
	focus.border_color = ArtPalette.color("ui_accent")
	focus.set_corner_radius_all(int(cfg.get("button_texture_margin", 0)))
	focus.set_expand_margin_all(float(cfg.get("focus_expand_px", 0)))
	return focus


static func build(cfg: Dictionary) -> Theme:
	var theme := Theme.new()
	var heading := heading_font()
	var body := body_font()
	var text_color := ArtPalette.color("ui_text")
	var accent := ArtPalette.color("ui_accent")
	var disabled := Color(text_color, float(cfg.get("disabled_alpha", 1.0)))
	theme.default_font = body
	theme.default_font_size = int(cfg.get("font_size_body", 0))

	theme.set_color("font_color", "Label", text_color)
	theme.set_font("font", "Label", body)
	theme.set_font_size("font_size", "Label", int(cfg.get("font_size_body", 0)))
	for variation in [VARIATION_TITLE, VARIATION_HEADING, VARIATION_ACCENT]:
		theme.set_type_variation(variation, "Label")
		theme.set_font("font", variation, heading)
	theme.set_font_size("font_size", VARIATION_TITLE, int(cfg.get("font_size_title", 0)))
	theme.set_color("font_color", VARIATION_TITLE, accent)
	theme.set_color("font_outline_color", VARIATION_TITLE, ArtPalette.outline_color())
	theme.set_constant("outline_size", VARIATION_TITLE, int(cfg.get("focus_outline_px", 0)))
	theme.set_font_size("font_size", VARIATION_HEADING, int(cfg.get("font_size_heading", 0)))
	theme.set_color("font_color", VARIATION_HEADING, accent)
	theme.set_font_size("font_size", VARIATION_ACCENT, int(cfg.get("font_size_button", 0)))
	theme.set_color("font_color", VARIATION_ACCENT, accent)

	var focus := focus_style(cfg)

	for type_name in ["Button", "CheckBox"]:
		theme.set_font("font", type_name, heading)
		theme.set_font_size("font_size", type_name, int(cfg.get("font_size_button", 0)))
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
				"font_hover_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color",
				"icon_focus_color"]:
			theme.set_color(color_name, type_name, text_color)
		theme.set_color("font_disabled_color", type_name, disabled)
		theme.set_color("icon_disabled_color", type_name, disabled)
		theme.set_constant("h_separation", type_name, int(cfg.get("separation", 0)))
		theme.set_constant("icon_max_width", type_name, int(cfg.get("button_icon_px", 0)))
		theme.set_stylebox("focus", type_name, focus)
	_set_button_styles(theme, "Button", BUTTON_TEX, cfg)
	_set_button_styles(theme, "CheckBox", BUTTON_TEX, cfg)
	theme.set_type_variation(VARIATION_TILE, "Button")
	_set_button_styles(theme, VARIATION_TILE, TILE_TEX, cfg)
	theme.set_icon("checked", "CheckBox", load(CHECK_ON))
	theme.set_icon("unchecked", "CheckBox", load(CHECK_OFF))
	theme.set_icon("checked_disabled", "CheckBox", load(CHECK_ON))
	theme.set_icon("unchecked_disabled", "CheckBox", load(CHECK_OFF))

	var track := _texture_box(SLIDER_TRACK, cfg, Vector2.ZERO)
	var fill := _texture_box(SLIDER_FILL, cfg, Vector2.ZERO)
	for box in [track, fill]:
		box.texture_margin_top = 0.0
		box.texture_margin_bottom = 0.0
		box.content_margin_top = float(cfg.get("slider_height", 0)) / 2.0
		box.content_margin_bottom = float(cfg.get("slider_height", 0)) / 2.0
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	var fill_light := fill.duplicate() as StyleBoxTexture
	fill_light.modulate_color = Color.html(String(cfg.get("slider_highlight_tint", "#ffffff")))
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill_light)
	# Sliders draw no focus box; MenuScreen.add_focus_ring adds the outline, the yellow grabber is a second cue.
	theme.set_icon("grabber", "HSlider", load(SLIDER_GRABBER))
	theme.set_icon("grabber_highlight", "HSlider", load(SLIDER_GRABBER_FOCUS))
	theme.set_icon("grabber_disabled", "HSlider", load(SLIDER_GRABBER))

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(ArtPalette.color("ui_panel"), float(cfg.get("panel_alpha", 1.0)))
	panel.set_corner_radius_all(int(cfg.get("panel_corner_px", 0)))
	panel.set_content_margin_all(float(cfg.get("panel_padding", 0)))
	panel.set_border_width_all(int(cfg.get("focus_outline_px", 0)))
	panel.border_color = ArtPalette.outline_color()
	theme.set_stylebox("panel", "PanelContainer", panel)
	for type_name in ["VBoxContainer", "HBoxContainer"]:
		theme.set_constant("separation", type_name, int(cfg.get("separation", 0)))
	return theme


static func _texture_box(path: String, cfg: Dictionary, padding: Vector2) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(path)
	box.set_texture_margin_all(float(cfg.get("button_texture_margin", 0)))
	box.content_margin_left = padding.x
	box.content_margin_right = padding.x
	box.content_margin_top = padding.y
	box.content_margin_bottom = padding.y
	return box


static func _set_button_styles(theme: Theme, type_name: String, path: String, cfg: Dictionary) -> void:
	var padding := Vector2(float(cfg.get("button_padding_x", 0)), float(cfg.get("button_padding_y", 0)))
	var normal := _texture_box(path, cfg, padding)
	var hover := _texture_box(path, cfg, padding)
	hover.modulate_color = ArtPalette.color("ui_text")
	var pressed := _texture_box(path, cfg, padding)
	pressed.modulate_color = Color.html(String(cfg.get("pressed_tint", "#ffffff")))
	var off := _texture_box(path, cfg, padding)
	off.modulate_color = Color(1.0, 1.0, 1.0, float(cfg.get("disabled_alpha", 1.0)))
	theme.set_stylebox("normal", type_name, normal)
	theme.set_stylebox("hover", type_name, hover)
	theme.set_stylebox("pressed", type_name, pressed)
	theme.set_stylebox("hover_pressed", type_name, pressed)
	theme.set_stylebox("disabled", type_name, off)
