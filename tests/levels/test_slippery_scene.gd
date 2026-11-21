extends "res://tests/support/level_case.gd"
## run-fps: 60,144
## The mud event in Farm Meadow makes the castaway slide: releasing the input at full speed inside mud_lane while
## the event is active stops much later than without it, the same at 60 and 144 fps, and traction is normal again
## after the event ended.

const L2 := "res://scenes/levels/l2_farm_meadow.tscn"
const EVENT := "pig_mud"


## Runs right across the lane centre at full speed, releases there and returns the sliding distance.
func _slide() -> float:
	var lane := level.zone("mud_lane")
	var centre: Vector2 = (lane.get_node("CollisionShape2D") as Node2D).global_position
	await place_castaway(centre + Vector2(-240, 0), 0.0)
	move = Vector2.RIGHT
	var limit := 0
	while castaway.global_position.x < centre.x - 60.0 and limit < run_fps() * 3:
		await physics_frames(1)
		limit += 1
	move = Vector2.ZERO
	var start := castaway.global_position
	var still := 0
	limit = 0
	while still < 3 and limit < run_fps() * 5:
		var before := castaway.global_position
		await physics_frames(1)
		still = still + 1 if castaway.global_position.distance_to(before) < 0.01 else 0
		limit += 1
	return castaway.global_position.distance_to(start)


func test_mud_makes_the_castaway_slide() -> void:
	await open_level(L2, {"autostart": false})
	var dry: float = await _slide()
	EventBus.event_triggered.emit(EVENT)
	await physics_frames(int(ceil(Balance.get_float("events", "actor_impact_seconds") * run_fps())) + 2)
	check_eq(level.get_surface_at(castaway.global_position), Grabbable.SURFACE_MUD, "mud under the castaway")
	var wet: float = await _slide()
	check(wet > dry * 3.0, "slide on mud %.1f px vs %.1f px on grass (%d fps)" % [wet, dry, run_fps()])
	var cfg := CastawayConfig.from_balance()
	var expected := cfg.move_speed * cfg.move_speed / (2.0 * cfg.move_decel * cfg.slippery_friction_factor)
	check(absf(wet - expected) < expected * 0.15, "slide %.1f px close to %.1f px (%d fps)" % [wet, expected, run_fps()])
	EventBus.event_ended.emit(EVENT)
	await physics_frames(2)
	var after: float = await _slide()
	check(absf(after - dry) < 8.0, "traction back after the event: %.1f vs %.1f px" % [after, dry])
