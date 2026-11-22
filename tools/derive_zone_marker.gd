extends SceneTree
## One-off art tool: derives the zone marker nine-patch from the CC0 Kenney UI pack round line button and writes it
## as a 64 px PNG with a transparent centre (deterministic, the committed PNG is the result).
## Usage: godot --headless --path . --script res://tools/derive_zone_marker.gd
## The button's outer line (its stroke radius and width) is redrawn on a rounded square as a double stroke: a dark
## outer line in palette 'outline' and a light inner line in palette 'zone_marker', so it reads on grass and sand.

const SOURCE := "res://assets/ui/ui-pack/PNG/Extra/Default/button_round_line.png"
const OUT := "res://assets/graphics/pirate-pack-derived/zone_marker@2.png"
const PALETTE := "res://data/art/palette.json"
const SIZE := 64
## Corner radius of the rounded square; the nine-patch margins must be at least this large.
const CORNER := 24.0
## Width of the light inner line in texture pixels; the dark line gets the measured button stroke plus one pixel.
const LIGHT_PX := 2.5
const DARK_ALPHA := 0.85
const LIGHT_ALPHA := 0.9


func _initialize() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	var palette: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALETTE))
	if src == null or not palette is Dictionary:
		printerr("cannot read %s or %s" % [SOURCE, PALETTE])
		quit(1)
		return
	var colors: Dictionary = palette["colors"]
	var img := derive(src, Color.html(colors["outline"]), Color.html(colors["zone_marker"]))
	var err := img.save_png(ProjectSettings.globalize_path(OUT))
	if err != OK:
		printerr("cannot write %s (%d)" % [OUT, err])
		quit(1)
		return
	print("DERIVED %s" % OUT)
	quit(0)


## Builds the marker texture: the stroke width is measured on the source button's outer line.
static func derive(src: Image, dark: Color, light: Color) -> Image:
	var dark_px := stroke_width(src) + 1.0
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var half := SIZE / 2.0
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(absf(x + 0.5 - half), absf(y + 0.5 - half))
			var q := p - Vector2(half - CORNER, half - CORNER)
			var outside := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - CORNER
			var depth := -outside
			var c := Color(0, 0, 0, 0)
			var dark_cover := clampf(depth + 0.5, 0.0, 1.0) * clampf(dark_px - depth + 0.5, 0.0, 1.0)
			var light_cover := clampf(depth - dark_px + 0.5, 0.0, 1.0) * clampf(dark_px + LIGHT_PX - depth + 0.5, 0.0, 1.0)
			if dark_cover > 0.0:
				c = Color(dark, DARK_ALPHA * dark_cover)
			elif light_cover > 0.0:
				c = Color(light, LIGHT_ALPHA * light_cover)
			img.set_pixel(x, y, c)
	return img


## Width in pixels of the darker outer line of the button, measured from the left edge on the middle row.
static func stroke_width(src: Image) -> float:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var row := img.get_height() / 2
	var width := 0
	for x in img.get_width() / 2:
		var c := img.get_pixel(x, row)
		if c.a > 0.5 and 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b < 0.75:
			width += 1
		elif width > 0:
			break
	return float(maxi(width, 1))
