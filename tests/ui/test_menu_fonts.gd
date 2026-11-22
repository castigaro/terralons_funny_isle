extends TestCase
## Menu theme: one UI font for headings and body that covers umlauts and sharp s, sizes and button height come from
## Balance flow, and a visible focus outline exists. Full glyph coverage is in test_ui_font_glyphs.gd.


func test_one_font_covers_german() -> void:
	check_eq(MenuTheme.heading_font(), MenuTheme.font(), "headings use the UI font")
	check_eq(MenuTheme.body_font(), MenuTheme.font(), "body uses the UI font")
	var font := MenuTheme.font()
	check_eq(font.resource_path, MenuTheme.FONT, "UI font path")
	for ch in "äöüÄÖÜß":
		check_true(font.has_char(ch.unicode_at(0)), "%s has %s" % [font.resource_path.get_file(), ch])


func test_theme_matches_balance() -> void:
	var cfg := Balance.get_section("flow")
	var theme := MenuTheme.build(cfg)
	check_eq(theme.get_font_size("font_size", "Button"), int(cfg["font_size_button"]), "button size")
	check_eq(theme.get_font_size("font_size", "Label"), int(cfg["font_size_body"]), "body size")
	check_eq(theme.get_font_size("font_size", MenuTheme.VARIATION_HEADING), int(cfg["font_size_heading"]), "heading")
	check_eq(theme.get_font_size("font_size", MenuTheme.VARIATION_TITLE), int(cfg["font_size_title"]), "title")
	for key in ["font_size_button", "font_size_body", "font_size_heading", "font_size_title"]:
		check(int(cfg[key]) >= int(cfg["font_size_min"]), "%s above the minimum" % key)
	var focus := theme.get_stylebox("focus", "Button") as StyleBoxFlat
	check_ne(focus, null, "focus style")
	check_eq(focus.border_width_left, int(cfg["focus_outline_px"]), "outline width")
	check_false(focus.draw_center, "outline only")
	check_eq(theme.get_font("font", "Button").resource_path, MenuTheme.FONT, "button font")
	check_eq(theme.get_font("font", "Label").resource_path, MenuTheme.FONT, "body font")
	check_eq(theme.default_font.resource_path, MenuTheme.FONT, "default font")


func test_buttons_use_min_height() -> void:
	var title := (load("res://scenes/ui/menus/title.tscn") as PackedScene).instantiate()
	add_node(title)
	await frames(1)
	var play: Button = title.get("play_button")
	check_eq(play.custom_minimum_size.y, Balance.get_float("flow", "button_min_height"), "min height")
	check_ne(play.icon, null, "play icon from the UI pack")
	check_true(play.icon.resource_path.begins_with("res://assets/ui/ui-pack/"), "UI pack icon")


func test_slider_focus_cue_in_theme() -> void:
	var cfg := Balance.get_section("flow")
	var theme := MenuTheme.build(cfg)
	var grabber := theme.get_icon("grabber", "HSlider")
	var highlight := theme.get_icon("grabber_highlight", "HSlider")
	check_ne(highlight.resource_path, grabber.resource_path, "hovered or focused grabber has its own texture")
	check_eq(highlight.resource_path, MenuTheme.SLIDER_GRABBER_FOCUS, "yellow grabber")
	check_ne(theme.get_stylebox("grabber_area_highlight", "HSlider"), theme.get_stylebox("grabber_area", "HSlider"),
			"highlighted fill differs")
	var ring := MenuTheme.focus_style(cfg)
	var button_focus := theme.get_stylebox("focus", "Button") as StyleBoxFlat
	check_eq(ring.border_width_left, button_focus.border_width_left, "same width as the button outline")
	check_eq(ring.border_color, button_focus.border_color, "same colour as the button outline")
	check_false(ring.draw_center, "outline only")
