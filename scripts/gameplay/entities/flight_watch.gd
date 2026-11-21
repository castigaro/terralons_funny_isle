class_name FlightWatch
extends RefCounted
## Notices the ThrowFlight child that the castaway adds to a thrown entity (child_entered_tree) and reports the
## ground point, height and progress of the flight each tick, plus a per-flight set of already hit entities.
## ThrowFlight itself stays unchanged; its landing arrives through the entity's on_released().

const FLIGHT_NAME := "ThrowFlight"

var flight: ThrowFlight = null
## Entities already hit during this flight (instance id -> true), so a skim hits each one once.
var hits: Dictionary = {}
var _on_start: Callable


func _init(owner_node: Node, on_start: Callable) -> void:
	_on_start = on_start
	owner_node.child_entered_tree.connect(_on_child)


func _on_child(child: Node) -> void:
	if child is ThrowFlight:
		flight = child
		hits = {}
		if _on_start.is_valid():
			_on_start.call()


func active() -> bool:
	return flight != null and is_instance_valid(flight) and not flight.is_queued_for_deletion()


## {ground: Vector2, height: float, progress: float} of the running flight.
func sample() -> Dictionary:
	if not active():
		return {"ground": Vector2.ZERO, "height": 0.0, "progress": 1.0}
	return {"ground": flight.from.lerp(flight.landing, flight.t), "height": flight.height_at(flight.t),
			"progress": flight.t}


## True when the flight is low enough at its end to skim into animals on the ground.
func skimming(min_progress: float, max_height: float) -> bool:
	if not active():
		return false
	var s := sample()
	return s["progress"] >= min_progress and s["height"] <= max_height


## Ends the watch after the landing (called from on_released).
func finish() -> void:
	flight = null
