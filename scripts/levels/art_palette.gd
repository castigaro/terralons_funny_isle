class_name ArtPalette
extends RefCounted
## Art palette from data/art/palette.json: colours, outline and drop shadow rules shared by shaders, scenes and docs.

const PATH := "res://data/art/palette.json"
const REQUIRED_COLORS := ["sand", "grass", "water", "water_deep", "foliage", "outline", "ui_panel", "ui_text",
		"ui_accent"]
const FALLBACK_COLOR := "#ff00ff"

static var _cache: Dictionary = {}


## Reads and checks a palette file: returns {data: Dictionary, errors: Array}.
static func read(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"data": {}, "errors": ["%s: cannot read" % path]}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {"data": {}, "errors": ["%s: invalid JSON" % path]}
	return {"data": json.data, "errors": validate(json.data)}


## Returns the problems of a parsed palette (empty = valid).
static func validate(palette: Dictionary) -> Array:
	var errors: Array = []
	var colors: Variant = palette.get("colors")
	if not colors is Dictionary:
		return ["colors: must be an object"]
	for key in REQUIRED_COLORS:
		if not colors.has(key) or not Color.html_is_valid(str(colors[key])):
			errors.append("colors.%s: missing or not a colour" % key)
	var outline: Variant = palette.get("outline")
	if not outline is Dictionary or not colors.has(outline.get("color_key", "")) \
			or not float(outline.get("thickness_px_1080", 0.0)) > 0.0:
		errors.append("outline: needs color_key and thickness_px_1080 > 0")
	var shadow_block: Variant = palette.get("shadow")
	if not shadow_block is Dictionary or not shadow_block.get("offset") is Array or shadow_block["offset"].size() != 2:
		errors.append("shadow: needs alpha, scale, squash and offset [x, y]")
	else:
		for key in ["alpha", "scale", "squash"]:
			if not float(shadow_block.get(key, 0.0)) > 0.0:
				errors.append("shadow.%s: must be > 0" % key)
	var outlined: Variant = palette.get("outlined")
	var drawn: Variant = palette.get("drawn_outline")
	if not outlined is Array or not drawn is Array:
		errors.append("outlined and drawn_outline: must be lists of asset folder prefixes")
	else:
		for prefix in outlined:
			if drawn.has(prefix):
				errors.append("%s: listed as outlined and as drawn_outline" % prefix)
	return errors


## Returns the cached palette data (loaded on first use).
static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = read()["data"]
	return _cache


static func color(color_name: String) -> Color:
	return Color.html(str(data().get("colors", {}).get(color_name, FALLBACK_COLOR)))


static func outline_color() -> Color:
	return color(str(data().get("outline", {}).get("color_key", "outline")))


## Outline thickness in screen pixels at 1920x1080.
static func outline_px() -> float:
	return float(data().get("outline", {}).get("thickness_px_1080", 1.0))


## Drop shadow block: {alpha, scale, squash, offset: Vector2}.
static func shadow() -> Dictionary:
	var block: Dictionary = data().get("shadow", {})
	var off: Array = block.get("offset", [0, 0])
	return {"alpha": float(block.get("alpha", 1.0)), "scale": float(block.get("scale", 1.0)),
			"squash": float(block.get("squash", 1.0)), "offset": Vector2(float(off[0]), float(off[1]))}


## True when the texture comes from a pack with a drawn outline (never gets the outline shader).
static func is_drawn_outline(texture_path: String) -> bool:
	return _matches(texture_path, data().get("drawn_outline", []))


## True when the texture comes from a pack that needs the outline shader.
static func is_outlined(texture_path: String) -> bool:
	return _matches(texture_path, data().get("outlined", []))


## Sets the palette uniforms that a shader material declares (outline_color, water_tint, highlight).
static func apply_to(material: Material) -> void:
	if not material is ShaderMaterial or material.shader == null:
		return
	var names := []
	for uniform in material.shader.get_shader_uniform_list():
		names.append(uniform["name"])
	if names.has("outline_color"):
		material.set_shader_parameter("outline_color", outline_color())
	if names.has("water_tint"):
		material.set_shader_parameter("water_tint", color(str(data().get("water_tint", "water"))))
	if names.has("highlight"):
		var hl := Color.html(str(data().get("highlight", "#ffffff")))
		hl.a = float(data().get("highlight_alpha", hl.a))
		material.set_shader_parameter("highlight", hl)


static func _matches(texture_path: String, prefixes: Array) -> bool:
	var rel := texture_path.trim_prefix("res://")
	for prefix in prefixes:
		if rel.begins_with(str(prefix).trim_prefix("res://")):
			return true
	return false
