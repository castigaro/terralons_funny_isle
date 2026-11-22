class_name GrassTint
extends RefCounted
## GDScript mirror of scenes/levels/art/grass_tint.gdshader: how strongly a ground pixel counts as grass and the
## colour it gets under a grass tint.

const SHADER_PATH := "res://scenes/levels/art/grass_tint.gdshader"
const GREEN_MIN := 0.04  # balance-exempt: mirrors grass_tint.gdshader
const GREEN_FULL := 0.12  # balance-exempt: mirrors grass_tint.gdshader


## Grass weight of a pixel: 0 for sand and water, 1 for clearly green grass.
static func weight(c: Color) -> float:
	return smoothstep(GREEN_MIN, GREEN_FULL, c.g - maxf(c.r, c.b))


## Colour of a pixel after the shader applied the tint.
static func apply(c: Color, tint: Color) -> Color:
	var w := weight(c) * tint.a
	var tinted := Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)
	return Color(lerpf(c.r, tinted.r, w), lerpf(c.g, tinted.g, w), lerpf(c.b, tinted.b, w), c.a)
