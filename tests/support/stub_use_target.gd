extends Node2D
## Scene stand-in for a use target (for example a goat that accepts a hat): records every use.

const TEXTURE := preload("res://assets/graphics/animals/PNG/Round (outline)/goat.png")

@export var target_kind := "goat"
var accepted_kinds: Array = ["hat"]
var used: Array = []


func _init() -> void:
	add_to_group(UseTarget.GROUP)
	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	sprite.texture = TEXTURE
	sprite.scale = Vector2(0.5, 0.5)
	add_child(sprite)


func accepts(obj: Variant) -> bool:
	return obj != null and accepted_kinds.has(obj.get("kind"))


func use(obj: Variant) -> void:
	used.append(obj)
	if obj is Node2D:
		obj.global_position = global_position
