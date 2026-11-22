extends RefCounted
## Pixel statistics for the ground and zone art checks: luma standard deviation, opaque share and the grass filter.

## Minimum luma standard deviation of the green pixels of a grass tile and of an opaque filled sprite.
const GRASS_MIN_SD := 0.02
## Minimum luma standard deviation of every other ground tile (sand, shore, details); the flat pack grass has 0.
const GROUND_FLOOR_SD := 0.005
## Share of opaque pixels above which a sprite counts as a filled square.
const FILLED_SHARE := 0.9


static func luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


static func is_green(c: Color) -> bool:
	return c.a > 0.5 and c.g > c.r + 0.2 and c.g > c.b + 0.2


static func is_opaque(c: Color) -> bool:
	return c.a > 0.5


## Luma standard deviation of the pixels in rect that pass filter (a Callable(Color) -> bool); -1 without pixels.
static func luma_sd(img: Image, rect: Rect2i, filter: Callable = is_opaque) -> float:
	var n := 0
	var s := 0.0
	var s2 := 0.0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := img.get_pixel(x, y)
			if not filter.call(c):
				continue
			var l := luma(c)
			n += 1
			s += l
			s2 += l * l
	if n == 0:
		return -1.0
	var mean := s / float(n)
	return sqrt(maxf(s2 / float(n) - mean * mean, 0.0))


## Mean colour of the opaque pixels in rect.
static func mean_color(img: Image, rect: Rect2i) -> Color:
	var n := 0
	var sum := Vector3.ZERO
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				n += 1
				sum += Vector3(c.r, c.g, c.b)
	sum /= float(maxi(n, 1))
	return Color(sum.x, sum.y, sum.z)


## Share of opaque pixels in rect.
static func opaque_share(img: Image, rect: Rect2i) -> float:
	var n := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if img.get_pixel(x, y).a > 0.5:
				n += 1
	return float(n) / float(maxi(rect.size.x * rect.size.y, 1))


## Loads a PNG below res:// as an RGBA8 image straight from the file (works headless); null when missing.
static func load_png(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
	return img


## WCAG contrast ratio of two colours.
static func contrast(a: Color, b: Color) -> float:
	var la := _relative(a)
	var lb := _relative(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _relative(c: Color) -> float:
	var ch := [c.r, c.g, c.b]
	for i in 3:
		ch[i] = ch[i] / 12.92 if ch[i] <= 0.03928 else pow((ch[i] + 0.055) / 1.055, 2.4)
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]
