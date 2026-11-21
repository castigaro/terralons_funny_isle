class_name CastawayWorld
extends RefCounted
## Query interface the castaway logic uses to find things around it; this base finds nothing.
## Candidates are duck-typed objects with global_position (see Grabbable and UseTarget).


## Grabbable candidates within radius of pos.
func grabbables(_pos: Vector2, _radius: float) -> Array:
	return []


## Use targets within radius of pos.
func use_targets(_pos: Vector2, _radius: float) -> Array:
	return []


## Aim-snap targets for throws (use targets and throw-only targets) within radius of pos.
func throw_targets(_pos: Vector2, _radius: float) -> Array:
	return []


## Ground surface at pos: "sand", "grass" or "water".
func surface_at(_pos: Vector2) -> String:
	return Grabbable.SURFACE_SAND
