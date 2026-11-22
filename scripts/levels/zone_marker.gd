class_name ZoneMarker
extends Node2D
## Decoration that outlines a player-action zone (pen, pond, build site) with the derived double-stroke nine-patch.
## It sizes itself from the axis-aligned bounds of the zone's CollisionShape2D (rectangle, or circle as its square)
## when it enters the level; it has no collision, input or per-frame work and never changes the zone itself.

## Scale of the nine-patch texture in world pixels per texture pixel (line width and corner radius).
const LINE_SCALE := 2.0

## zone_id of the Zone (below the level's Zones node) this marker outlines.
@export var zone_id := ""

var _zone: Zone


func _ready() -> void:
	var lvl := _level()
	var found: Zone = lvl.zone(zone_id) if lvl != null else null
	if found == null:
		push_warning("ZoneMarker %s: no zone '%s' in the level" % [name, zone_id])
		hide()
		return
	apply_zone(found)


## Sizes and places the marker on the bounds of the zone.
func apply_zone(zone: Zone) -> void:
	_zone = zone
	var rect := zone_rect(zone)
	global_position = rect.position
	var frame := get_node("Frame") as NinePatchRect
	frame.position = Vector2.ZERO
	frame.scale = Vector2(LINE_SCALE, LINE_SCALE)
	frame.size = rect.size / LINE_SCALE
	show()


## The outlined rectangle in global coordinates.
func marker_rect() -> Rect2:
	var frame := get_node("Frame") as NinePatchRect
	return Rect2(frame.global_position, frame.size * frame.scale * global_scale)


func zone_node() -> Zone:
	return _zone


## Axis-aligned bounds of the first CollisionShape2D of a zone in global coordinates (empty without a shape).
static func zone_rect(zone: Zone) -> Rect2:
	for child in zone.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or shape_node.shape == null:
			continue
		var local := Rect2()
		if shape_node.shape is RectangleShape2D:
			var size: Vector2 = (shape_node.shape as RectangleShape2D).size
			local = Rect2(-size / 2.0, size)
		elif shape_node.shape is CircleShape2D:
			var r: float = (shape_node.shape as CircleShape2D).radius
			local = Rect2(Vector2(-r, -r), Vector2(2.0 * r, 2.0 * r))
		else:
			continue
		return shape_node.global_transform * local
	return Rect2()


func _level() -> LevelBase:
	var node := get_parent()
	while node != null and not node is LevelBase:
		node = node.get_parent()
	return node as LevelBase
