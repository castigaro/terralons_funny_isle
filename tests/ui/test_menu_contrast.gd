extends TestCase
## BI-18 readability: menu text (ui_text) and headings (ui_accent) on the menu panel (ui_panel at flow.panel_alpha)
## keep a WCAG contrast of at least 4.5:1 even over the brightest backdrop pixel (white).

const MIN_CONTRAST := 4.5
const WEAK_ALPHA := 0.3


func _channel(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)


func _luminance(c: Color) -> float:
	return 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b)


func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _panel_over(under: Color, alpha: float) -> Color:
	return under.lerp(ArtPalette.color("ui_panel"), alpha)


func test_text_on_panel_over_white_backdrop() -> void:
	var alpha := Balance.get_float("flow", "panel_alpha")
	for under in [Color.WHITE, ArtPalette.color("water"), Color.BLACK]:
		var bg := _panel_over(under, alpha)
		for color_name in ["ui_text", "ui_accent"]:
			var ratio := _contrast(ArtPalette.color(color_name), bg)
			check(ratio >= MIN_CONTRAST, "%s on the panel over %s: %.2f" % [color_name, under.to_html(false), ratio])


func test_check_can_fail_with_a_weak_panel() -> void:
	var ratio := _contrast(ArtPalette.color("ui_text"), _panel_over(Color.WHITE, WEAK_ALPHA))
	check(ratio < MIN_CONTRAST, "a 0.3 panel over white is too weak (%.2f)" % ratio)
