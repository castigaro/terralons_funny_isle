class_name SwayPhase
extends RefCounted
## GDScript mirror of the phase hash and pivot modes in scenes/levels/art/sway.gdshader.

const HASH_DOT := Vector2(127.1, 311.7)  # balance-exempt: mirrors sway.gdshader
const HASH_SCALE := 43758.5453  # balance-exempt: mirrors sway.gdshader
## Side-view foliage bends from its base.
const PIVOT_BASE := 0
## Top-down crowns (palms) turn around their centre.
const PIVOT_CENTRE := 1


## Returns the sway phase of a sprite whose origin is at the given global position.
static func phase(origin: Vector2) -> float:
	var v := sin(origin.floor().dot(HASH_DOT)) * HASH_SCALE
	return (v - floorf(v)) * TAU
