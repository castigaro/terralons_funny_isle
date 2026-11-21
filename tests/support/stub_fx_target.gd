extends Node2D
## Test double for the duck-typed FeedbackDirector contract: records fx_squash and fx_recoil calls.

var kind := "stub"
var facing := 0.0
var squashes: Array = []
var recoils: Array = []


func fx_squash(sx: float, sy: float, seconds: float) -> void:
	squashes.append([sx, sy, seconds])


func fx_recoil(offset: Vector2, seconds: float) -> void:
	recoils.append([offset, seconds])


func get_facing() -> float:
	return facing
