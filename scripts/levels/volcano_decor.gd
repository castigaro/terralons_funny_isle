class_name VolcanoDecor
extends Node2D
## Root of the Volcano Cliffs set dressing (scenes/levels/decor/l5_volcano_decor.tscn, written offline by
## tools/place_volcano_decor.py): ground patches for the outer shore corners, cliff face pieces, lava glow cracks and
## vents; decor only, nothing placed at runtime.

const GROUP := "volcano_decor"


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(DecorProp.GROUP)


## Ground patch sprites with the volcanic ground material, one per outer-corner coast cell whose shore art has a pocket.
func corner_grounds() -> Array:
	return get_node("CornerGround").get_children()


## Cliff face sprites, one per (cell, piece kind).
func pieces() -> Array:
	return get_node("CliffFace").get_children()


## Lava glow cracks on rock cells.
func cracks() -> Array:
	return get_node("LavaCracks").get_children()


func vents() -> Array:
	return get_node("Vents").get_children()
