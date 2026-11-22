class_name VolcanicGround
extends RefCounted
## GDScript mirror of scenes/levels/art/volcanic_ground.gdshader: the sand, grass and stone weights of a ground
## pixel and the colour it gets on Volcano Cliffs, so headless tests can check contrast and texture.

const SHADER_PATH := "res://scenes/levels/art/volcanic_ground.gdshader"
const GREEN_MIN := 0.04  # balance-exempt: mirrors volcanic_ground.gdshader
const GREEN_FULL := 0.12  # balance-exempt: mirrors volcanic_ground.gdshader
const WARM_MIN := 0.06  # balance-exempt: mirrors volcanic_ground.gdshader
const WARM_FULL := 0.12  # balance-exempt: mirrors volcanic_ground.gdshader
const LUMA_MIN := 0.45  # balance-exempt: mirrors volcanic_ground.gdshader
const LUMA_FULL := 0.6  # balance-exempt: mirrors volcanic_ground.gdshader
const ASH_BASE := 0.7  # balance-exempt: mirrors volcanic_ground.gdshader
const ASH_SPREAD := 0.7  # balance-exempt: mirrors volcanic_ground.gdshader
const GRASS_LUMA := 0.64  # balance-exempt: mirrors volcanic_ground.gdshader
const PARAMS := ["rock_low", "rock_high", "ash_tint", "stone_tint", "detail_strength", "luma_gain", "sand_luma_mean"]


static func luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b  # balance-exempt: Rec. 709 luma weights


## Grass weight of a pixel: 1 for clearly green grass.
static func weight_grass(c: Color) -> float:
	return smoothstep(GREEN_MIN, GREEN_FULL, c.g - maxf(c.r, c.b))


## Sand weight of a pixel: 1 for warm, bright sand and its shore rim.
static func weight_sand(c: Color) -> float:
	return smoothstep(WARM_MIN, WARM_FULL, c.r - c.b) * smoothstep(LUMA_MIN, LUMA_FULL, luma(c)) * (1.0 - weight_grass(c))


## Colour of a pixel after the shader; detail is the red channel of the detail texture at that world point.
static func apply(c: Color, detail: float, params: Dictionary) -> Color:
	var wg := weight_grass(c)
	var ws := weight_sand(c)
	var wst := (1.0 - ws) * (1.0 - wg)
	var l := luma(c)
	var t := clampf(0.5 + (l - float(params["sand_luma_mean"])) * float(params["luma_gain"])
			+ (detail - 0.5) * float(params["detail_strength"]), 0.0, 1.0)
	var rock: Color = (params["rock_low"] as Color).lerp(params["rock_high"], t)
	var tg := clampf(0.5 + (l - GRASS_LUMA) * float(params["luma_gain"])
			+ (detail - 0.5) * float(params["detail_strength"]), 0.0, 1.0)
	var ash: Color = (params["ash_tint"] as Color) * (ASH_BASE + ASH_SPREAD * tg)
	var stone: Color = (params["stone_tint"] as Color) * l
	var rgb := Color(c.r, c.g, c.b).lerp(rock, ws)
	rgb = rgb.lerp(ash, wg)
	rgb = rgb.lerp(stone, wst)
	return Color(rgb.r, rgb.g, rgb.b, c.a)


## The mirror parameters read from a ShaderMaterial that uses the volcanic ground shader.
static func params_from_material(mat: ShaderMaterial) -> Dictionary:
	var out := {}
	for key in PARAMS:
		out[key] = mat.get_shader_parameter(key)
	return out
