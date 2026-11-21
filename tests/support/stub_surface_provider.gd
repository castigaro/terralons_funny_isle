extends Node
## Scene stand-in for the level surface provider: grass and water rectangles, sand everywhere else.

var grass: Array = []
var waters: Array = []


func _init() -> void:
	add_to_group(Grabbable.SURFACE_PROVIDER_GROUP)


func get_surface_at(global_pos: Vector2) -> String:
	for rect in waters:
		if rect.has_point(global_pos):
			return Grabbable.SURFACE_WATER
	for rect in grass:
		if rect.has_point(global_pos):
			return Grabbable.SURFACE_GRASS
	return Grabbable.SURFACE_SAND
