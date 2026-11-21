class_name PenTarget
extends UseTargetBase
## Use target at a pen, cage or pond: puts a carried animal of an accepted kind on the next drop slot (Marker2D
## children, inside the pen zone) so it counts for in_zone conditions; the pen keeps it inside. Throwing an animal
## into the zone works as well.

var _next := 0


func slots() -> Array:
	return get_children().filter(func(n: Node) -> bool: return n is Marker2D)


func use(obj: Object) -> void:
	var points := slots()
	if points.is_empty() or not obj.has_method("relocate_to"):
		return
	var slot := points[_next % points.size()] as Marker2D
	_next += 1
	obj.call("relocate_to", slot.global_position)
	EventBus.fx_anchor.emit(String(obj.get("kind")), slot.global_position)
