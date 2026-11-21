extends TestCase
## Menu theme: fonts cover umlauts and sharp s, sizes and button height come from Balance flow, a visible focus
## outline exists, and no menu text uses the en dash the fonts lack.


func test_fonts_cover_german() -> void:
	for font in [MenuTheme.heading_font(), MenuTheme.body_font()]:
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
	check_eq(theme.get_font("font", "Button").resource_path, MenuTheme.FONT_HEADING, "button font")
	check_eq(theme.get_font("font", "Label").resource_path, MenuTheme.FONT_BODY, "body font")


func test_buttons_use_min_height() -> void:
	var title := (load("res://scenes/ui/menus/title.tscn") as PackedScene).instantiate()
	add_node(title)
	await frames(1)
	var play: Button = title.get("play_button")
	check_eq(play.custom_minimum_size.y, Balance.get_float("flow", "button_min_height"), "min height")
	check_ne(play.icon, null, "play icon from the UI pack")
	check_true(play.icon.resource_path.begins_with("res://assets/ui/ui-pack/"), "UI pack icon")


func test_menu_texts_have_no_en_dash() -> void:
	for key in I18n.keys():
		if String(key).begins_with("menu."):
			for loc in I18n.LOCALES:
				check_false(I18n.text_in(key, loc).contains("–"), "%s (%s) has an en dash" % [key, loc])
