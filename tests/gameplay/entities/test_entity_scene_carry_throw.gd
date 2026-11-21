extends "res://tests/support/entity_scene_case.gd"
## Carry and throw an animal: caught signal, carry-weight walk speed and throw range, landing, back to wander.


func test_grab_carry_and_throw_a_pig() -> void:
	await build(["pig"], [])
	var pig := animal("pig")
	var ccfg := castaway.cfg
	var weight := clampf(float(pig.def["carry_weight"]), ccfg.carry_weight_min, ccfg.carry_weight_max)
	await place_castaway(Vector2(200, 600), 0.0)
	place(pig, Vector2(250, 600))
	await physics_frames(1)
	press_interact()
	await physics_frames(2)
	check_eq(castaway.get_carried(), pig, "carried")
	check_eq(events("animal_caught"), [["animal_caught", ["pig"]]], "animal_caught")
	check_eq(events("object_grabbed"), [["object_grabbed", ["pig"]]], "object_grabbed")
	check_eq(pig.get_state_name(), "carried", "carried state")
	check_eq(pig.collision_layer, 0, "no collision while carried")
	move = Vector2.RIGHT
	await physics_frames(ticks_for(0.6))
	var speed := castaway.get_logic().velocity.length()
	var expected := ccfg.move_speed * ccfg.carry_speed_factor / weight
	check(absf(speed - expected) < 0.5, "carry speed %.2f expected %.2f" % [speed, expected])
	move = Vector2.ZERO
	await physics_frames(ticks_for(0.3))
	var thrown_from := castaway.global_position
	check_eq(castaway.get_logic().throw_reach(), ccfg.throw_range / weight, "throw reach")
	press_interact()
	await physics_frames(1)
	var waited := await wait_until(func() -> bool: return not events("object_landed").is_empty(),
			ticks_for(ccfg.throw_flight_time) + 5)
	check(waited >= 0, "landed")
	var landed: Array = events("object_landed")[0][1]
	check_eq(landed[0], "pig", "landed kind")
	check_eq(landed[2], "sand", "landed surface")
	var distance := thrown_from.distance_to(landed[1])
	check(absf(distance - ccfg.throw_range / weight) < 2.0, "throw distance %.1f" % distance)
	await physics_frames(1)
	check_eq(pig.get_state_name(), "wander", "wanders after landing")
	check_eq(pig.collision_layer, PhysicsLayers.ANIMALS, "collision restored")
	check(pig.collision_mask & PhysicsLayers.WATER != 0, "pigs do not swim")


func test_light_load_keeps_full_numbers() -> void:
	await build([], ["coconut"])
	await place_castaway(Vector2(200, 600), 0.0)
	place(item("coconut"), Vector2(250, 600))
	await physics_frames(1)
	press_interact()
	await physics_frames(2)
	check_eq(castaway.get_carried(), item("coconut"), "carried")
	check_eq(castaway.get_logic().throw_reach(), castaway.cfg.throw_range, "weight 1.0 keeps the range")
