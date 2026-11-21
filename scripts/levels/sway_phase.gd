class_name SwayPhase
extends RefCounted
## GDScript mirror of the phase hash in scenes/levels/art/sway.gdshader (instance origin to phase in radians).

const HASH_DOT := Vector2(127.1, 311.7)  # balance-exempt: mirrors sway.gdshader
const HASH_SCALE := 43758.5453  # balance-exempt: mirrors sway.gdshader


## Returns the sway phase of a prop whose origin is at the given global position.
static func phase(origin: Vector2) -> float:
	var v := sin(origin.floor().dot(HASH_DOT)) * HASH_SCALE
	return (v - floorf(v)) * TAU
