extends RefCounted
## Pure stand-in for a Zone in brain tests: an axis-aligned rectangle with the Zone confinement methods.

var rect := Rect2()


func _init(r: Rect2) -> void:
	rect = r


func contains_point(p: Vector2) -> bool:
	return rect.has_point(p)


func clamp_inside(p: Vector2, margin: float) -> Vector2:
	var inner := rect.grow(-margin)
	return Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))


func random_point(rng: SeededRng, margin: float) -> Vector2:
	var inner := rect.grow(-margin)
	return Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y))
