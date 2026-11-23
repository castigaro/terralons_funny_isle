class_name LandRect
extends RefCounted
## Axis-aligned land area of a decorative menu critter: keeps a point inside the rectangle (no physics).

var rect := Rect2()


func _init(r: Rect2 = Rect2()) -> void:
	rect = r


func has_point(p: Vector2) -> bool:
	return rect.has_point(p)


## Closest point inside the rectangle (edges included).
func clamp_point(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
