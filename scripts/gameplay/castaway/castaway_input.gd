class_name CastawayInput
extends RefCounted
## One tick of castaway input: move vector plus the dash and interact presses of this physics frame.

var move := Vector2.ZERO
var dash_pressed := false
var interact_pressed := false


## Reads the input map in the current physics frame (no buffering).
static func from_input() -> CastawayInput:
	return make(
		Input.get_vector("move_left", "move_right", "move_up", "move_down"),
		Input.is_action_just_pressed("dash"),
		Input.is_action_just_pressed("interact"))


static func make(move_vector: Vector2 = Vector2.ZERO, dash: bool = false, interact: bool = false) -> CastawayInput:
	var input := CastawayInput.new()
	input.move = move_vector
	input.dash_pressed = dash
	input.interact_pressed = interact
	return input
