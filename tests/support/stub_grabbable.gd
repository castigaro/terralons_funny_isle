extends Node2D
## Scene stand-in for a grabbable item: records the contract calls and shows an item sprite.

const TEXTURE := preload("res://assets/graphics/items/PNG/Colored/genericItem_color_161.png")

@export var kind := "coconut"
var grabbable := true
var held_by: Node2D = null
var grab_calls := 0
var release_calls := 0
var visual: Sprite2D


func _init() -> void:
	add_to_group(Grabbable.GROUP)
	visual = Sprite2D.new()
	visual.name = "Visual"
	visual.texture = TEXTURE
	visual.scale = Vector2(2.5, 2.5)
	add_child(visual)


func can_grab() -> bool:
	return grabbable and held_by == null


func on_grabbed(carrier: Node2D) -> void:
	held_by = carrier
	grab_calls += 1


func on_released() -> void:
	held_by = null
	release_calls += 1


func get_throw_visual() -> Node2D:
	return visual
