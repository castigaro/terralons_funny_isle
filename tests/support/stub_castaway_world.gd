extends CastawayWorld
## Pure CastawayWorld for logic tests: lists of stub things plus blocker rectangles with a simple mover.

var items: Array = []
var targets: Array = []
var throw_only: Array = []
var solids: Array = []
var waters: Array = []
## The playable area; leaving it counts as blocked.
var bounds := Rect2(-100000, -100000, 200000, 200000)
var grass: Array = []


func grabbables(pos: Vector2, radius: float) -> Array:
	return _near(items, pos, radius)


func use_targets(pos: Vector2, radius: float) -> Array:
	return _near(targets, pos, radius)


func throw_targets(pos: Vector2, radius: float) -> Array:
	return _near(targets + throw_only, pos, radius)


func surface_at(pos: Vector2) -> String:
	for rect in waters:
		if rect.has_point(pos):
			return Grabbable.SURFACE_WATER
	for rect in grass:
		if rect.has_point(pos):
			return Grabbable.SURFACE_GRASS
	return Grabbable.SURFACE_SAND


## True if a circle at pos overlaps a solid or water rectangle or leaves the bounds.
func is_blocked(pos: Vector2, radius: float) -> bool:
	if not bounds.grow(-radius).has_point(pos):
		return true
	for rect in solids + waters:
		if _circle_hits(rect, pos, radius):
			return true
	return false


## Moves a circle by motion; returns [new_pos, blocked]. Walk slides per axis, burst stops on contact.
func move(pos: Vector2, motion: Vector2, radius: float, slide: bool) -> Array:
	var target := pos + motion
	if not is_blocked(target, radius):
		return [target, false]
	if slide:
		var along_x := pos + Vector2(motion.x, 0)
		if not is_blocked(along_x, radius):
			return [along_x, true]
		var along_y := pos + Vector2(0, motion.y)
		if not is_blocked(along_y, radius):
			return [along_y, true]
	return [pos, true]


func _circle_hits(rect: Rect2, pos: Vector2, radius: float) -> bool:
	var nearest := Vector2(clampf(pos.x, rect.position.x, rect.end.x), clampf(pos.y, rect.position.y, rect.end.y))
	return nearest.distance_to(pos) < radius


func _near(list: Array, pos: Vector2, radius: float) -> Array:
	var found := []
	for thing in list:
		if thing.global_position.distance_to(pos) <= radius:
			found.append(thing)
	return found
