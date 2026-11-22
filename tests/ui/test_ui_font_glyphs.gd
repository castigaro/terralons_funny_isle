extends TestCase
## The UI font (MenuTheme.FONT, derived by tools/derive_font.py) has every glyph the game shows: the required set,
## every codepoint of the EN and DE i18n texts, diagonal X, x and %, sharp s as SS and the en dash as hyphen. The
## source Kenney Future fails the shape checks, so they detect the original look-alike glyphs.

const SOURCE_FONT := "res://assets/ui/ui-pack/Font/Kenney Future.ttf"
const REQUIRED := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789%Xxäöüß-ÄÖÜ"
const EN_DASH := 0x2013
const PROBE_SIZE := 64
## Minimal |dx| and |dy| of a diagonal edge, as a share of the font size.
const DIAGONAL_EM := 0.1
const PLACEHOLDER_RE := r"\{[A-Za-z0-9_]+\}"


static func _ts() -> TextServer:
	return TextServerManager.get_primary_interface()


static func glyph_index(font: Font, codepoint: int) -> int:
	return _ts().font_get_glyph_index(font.get_rids()[0], PROBE_SIZE, codepoint, 0)


static func contours(font: Font, ch: String) -> Dictionary:
	return _ts().font_get_glyph_contours(font.get_rids()[0], PROBE_SIZE, glyph_index(font, ch.unicode_at(0)))


static func advance(font: Font, ch: String) -> float:
	return _ts().font_get_glyph_advance(font.get_rids()[0], PROBE_SIZE, glyph_index(font, ch.unicode_at(0))).x


## True when one outline edge of the glyph runs diagonally by more than DIAGONAL_EM in both directions.
static func has_diagonal(font: Font, ch: String) -> bool:
	var data := contours(font, ch)
	var points: PackedVector3Array = data.get("points", PackedVector3Array())
	var ends: PackedInt32Array = data.get("contours", PackedInt32Array())
	var limit := DIAGONAL_EM * PROBE_SIZE
	var start := 0
	for end in ends:
		for i in range(start, end + 1):
			var next := start if i == end else i + 1
			var d := points[next] - points[i]
			if absf(d.x) > limit and absf(d.y) > limit:
				return true
		start = end + 1
	return false


## True when sharp s is as wide as two S (one pixel of tolerance for the rounded advances).
static func sharp_s_is_double_s(font: Font) -> bool:
	return absf(advance(font, "ß") - 2.0 * advance(font, "S")) <= 1.0


func test_required_glyphs() -> void:
	var font := MenuTheme.font()
	for ch in REQUIRED:
		check_true(font.has_char(ch.unicode_at(0)), "UI font has %s" % ch)
	check_true(font.has_char(EN_DASH), "UI font has the en dash")


func test_every_i18n_codepoint_is_covered() -> void:
	var font := MenuTheme.font()
	var placeholder := RegEx.create_from_string(PLACEHOLDER_RE)
	var missing := {}
	for key in I18n.keys():
		for loc in I18n.LOCALES:
			var text := placeholder.sub(I18n.text_in(key, loc), "", true)
			for i in text.length():
				var c := text.unicode_at(i)
				if c >= 32 and not font.has_char(c):
					missing[String.chr(c)] = "%s (%s)" % [key, loc]
	check(missing.is_empty(), "codepoints without glyph: %s" % str(missing))


func test_no_i18n_text_uses_star_or_check_signs() -> void:
	for key in I18n.keys():
		for loc in I18n.LOCALES:
			var text := I18n.text_in(key, loc)
			check_false(text.contains("★") or text.contains("✓"), "%s (%s) uses a sign the HUD draws as icon" % [key, loc])


func test_glyph_shapes() -> void:
	var font := MenuTheme.font()
	for ch in ["X", "x", "%"]:
		check_true(has_diagonal(font, ch), "%s has a diagonal edge" % ch)
	check(contours(font, "%").get("contours", PackedInt32Array()).size() >= 3, "% has two dots and a band")
	check_true(sharp_s_is_double_s(font), "sharp s is as wide as SS")
	check_eq(glyph_index(font, EN_DASH), glyph_index(font, "-".unicode_at(0)), "en dash uses the hyphen glyph")


func test_no_system_fallback() -> void:
	check_false(MenuTheme.font().allow_system_fallback, "derived font has no system fallback")


func test_source_font_fails_the_shape_checks() -> void:
	var source := load(SOURCE_FONT) as FontFile
	check_false(has_diagonal(source, "X"), "source X has no diagonal")
	check_false(sharp_s_is_double_s(source), "source sharp s is not SS")
