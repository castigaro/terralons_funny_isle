class_name RespawnGuard
extends RefCounted
## Pure respawn timer (A5): commits once an entity was continuously unreachable for respawn_delay seconds.
## A reachable, carried, flying, worn or task-protected entity resets the timer and is never respawned.

var delay := 0.0
var unreachable_time := 0.0
var reason := ""


func _init(respawn_delay: float) -> void:
	delay = respawn_delay


## Advances by delta; lost_reason is "" while reachable. Returns {commit: bool, reason: String}.
func tick(delta: float, lost_reason: String, free: bool, protected: bool) -> Dictionary:
	if lost_reason == "" or not free or protected:
		reset()
		return {"commit": false, "reason": ""}
	reason = lost_reason
	unreachable_time += maxf(delta, 0.0)
	if unreachable_time >= delay or is_equal_approx(unreachable_time, delay):
		var committed := reason
		reset()
		return {"commit": true, "reason": committed}
	return {"commit": false, "reason": reason}


func reset() -> void:
	unreachable_time = 0.0
	reason = ""


func is_pending() -> bool:
	return unreachable_time > 0.0
