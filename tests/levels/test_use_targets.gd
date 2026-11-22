extends "res://tests/support/level_case.gd"
## Generic use targets in the shipped levels: DeliveryTarget, WearTarget, PenTarget and BuildTarget accept only their kinds and
## feed the generic conditions (delivered_to, worn, in_zone) through the world, never through task ids.

const L1 := "res://scenes/levels/l1_beach_camp.tscn"
const L2 := "res://scenes/levels/l2_farm_meadow.tscn"
const L4 := "res://scenes/levels/l4_lagoon.tscn"


func _progress(task_index: int) -> Dictionary:
	await physics_frames(2)
	return level.level_session().task_progress()[task_index]


func test_delivery_target_counts_and_sends_the_item_home() -> void:
	await open_level(L1)
	var target := level.get_node("Actors/Monkey1/DeliveryTarget")
	var coconut := level.entity_registry().find_uid("coconut_1")
	var hat := level.entity_registry().find_uid("hat_1")
	check(UseTarget.is_valid(target), "valid use target")
	check_eq(String(target.get("target_kind")), "monkey", "kind from the parent animal")
	check(target.call("accepts", coconut), "accepts a coconut")
	check_false(target.call("accepts", hat), "rejects a hat")
	coconut.call("relocate_to", target.global_position)
	target.call("use", coconut)
	var entry: Dictionary = await _progress(1)
	check_eq(entry["current"], 1, "one delivery counted")
	check(coconut.global_position.distance_to(level.home_point("coconut_1")) < 1.0, "coconut back home")
	target.call("use", coconut)
	entry = await _progress(1)
	check(entry["done"], "second delivery completes the task")


func test_wear_target_puts_the_hat_on_the_goat() -> void:
	await open_level(L1)
	var target := level.get_node("Actors/Goat1/WearTarget")
	var hat := level.entity_registry().find_uid("hat_1")
	var coconut := level.entity_registry().find_uid("coconut_1")
	check(target.call("accepts", hat), "accepts the hat")
	check_false(target.call("accepts", coconut), "rejects a coconut")
	target.call("use", hat)
	var entry: Dictionary = await _progress(2)
	check_eq(String(hat.get("worn_by")), "goat", "goat wears the hat")
	check(entry["done"], "worn task done")
	check_false(target.call("accepts", hat), "no second hat while one is worn")


func test_pen_target_puts_animals_into_the_pen_and_cycles_slots() -> void:
	await open_level(L1)
	var gate := level.get_node("Actors/CageGate")
	var c1 := level.entity_registry().find_uid("chicken_1")
	var c2 := level.entity_registry().find_uid("chicken_2")
	var monkey := level.entity_registry().find_uid("monkey_1")
	check(gate.call("accepts", c1), "accepts a chicken")
	check_false(gate.call("accepts", monkey), "rejects the monkey")
	gate.call("use", c1)
	gate.call("use", c2)
	check(c1.global_position != c2.global_position, "different slots")
	var entry: Dictionary = await _progress(0)
	check(level.zone("cage").contains_point(c1.global_position), "first chicken in the cage")
	check(level.zone("cage").contains_point(c2.global_position), "second chicken in the cage")
	check(entry["done"], "cage task done")


func test_pond_jetty_and_pig_pen() -> void:
	await open_level(L2)
	var jetty := level.get_node("Actors/PondJetty")
	var pen := level.get_node("Actors/PenGate")
	var pig := level.entity_registry().find_uid("pig_1")
	for i in 3:
		jetty.call("use", level.entity_registry().find_uid("duck_%d" % (i + 1)))
	pen.call("use", pig)
	var ducks: Dictionary = await _progress(0)
	var pig_entry: Dictionary = level.level_session().task_progress()[1]
	check(ducks["done"], "three ducks in the pond")
	check(pig_entry["done"], "pig in the pen")
	check_false(jetty.call("accepts", pig), "the jetty takes no pig")


func _castle_frame(castle: BuildTarget) -> int:
	await physics_frames(2)
	await frames(1)
	return castle.current_frame()


func test_sandcastle_stages_follow_deliveries() -> void:
	await open_level(L4)
	var castle := level.get_node("Actors/Sandcastle") as BuildTarget
	var pail := level.entity_registry().find_uid("sand_pail_1")
	var hat := level.entity_registry().find_uid("hat_1")
	check_eq(castle.target_kind, "sandcastle", "target kind")
	check_eq(castle.stage_frames.size(), 4, "four stage frames")
	check_eq(await _castle_frame(castle), 0, "empty at the start")
	var art := castle.get_node("Art") as Sprite2D
	check(art.texture == castle.stage_frames[0], "first frame shown")
	check_false(castle.accepts(hat), "rejects a hat")
	for i in 3:
		check(castle.accepts(pail), "accepts pail %d" % (i + 1))
		castle.use(pail)
		check_eq(await _castle_frame(castle), i + 1, "stage %d after %d pails" % [i + 1, i + 1])
	check(art.texture == castle.stage_frames[3], "finished frame shown")
	check(castle.is_finished(), "castle finished")
	check_false(castle.accepts(pail), "no pail wasted on a finished castle")
	level.restart_level()
	check_eq(await _castle_frame(castle), 0, "restart resets the castle")
	check(art.texture == castle.stage_frames[0], "first frame after the restart")


func test_sandcastle_frames_are_derived_sand_art() -> void:
	var share := func(tex: Texture2D) -> float:
		var img := Image.load_from_file(ProjectSettings.globalize_path(tex.resource_path))
		img.convert(Image.FORMAT_RGBA8)
		var n := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					n += 1
		return float(n) / float(img.get_width() * img.get_height())
	await open_level(L4)
	var castle := level.get_node("Actors/Sandcastle") as BuildTarget
	var art := castle.get_node("Art") as Sprite2D
	check(art.modulate.is_equal_approx(Color.WHITE), "no tint on the castle art: %s" % art.modulate)
	var frames: Array = castle.stage_frames.duplicate()
	frames.append(castle.flattened_frame)
	var shares := []
	for tex: Texture2D in frames:
		check(tex.resource_path.begins_with("res://assets/graphics/pirate-pack-derived/sandcastle_"),
				"derived frame %s" % tex.resource_path)
		var s: float = share.call(tex)
		check(s < 0.9, "%s is not a filled square (%.2f)" % [tex.resource_path, s])
		shares.append(s)
	check(shares[0] < 0.35, "build site is a low outline (%.2f)" % shares[0])
	check(absf(shares[4] - shares[0]) >= 0.15, "flattened differs from the site (%.2f vs %.2f)" % [shares[4], shares[0]])
	check(absf(shares[4] - shares[3]) >= 0.15, "flattened differs from the keep (%.2f vs %.2f)" % [shares[4], shares[3]])


func test_wave_flattens_only_an_unfinished_castle() -> void:
	for pails in [1, 3]:
		await open_level(L4, {"session_options": {"schedule_mode": "earliest"}})
		var castle := level.get_node("Actors/Sandcastle") as BuildTarget
		var pail := level.entity_registry().find_uid("sand_pail_1")
		for i in pails:
			castle.use(pail)
		await _castle_frame(castle)
		var session := level.level_session()
		var wave_start := 0.0
		for e in session.schedule():
			if e["type"] == "wave_wash":
				wave_start = float(e["start"])
		session.tick(wave_start + 0.5 - session.elapsed(), level.build_snapshot())
		var frame: int = await _castle_frame(castle)
		var entry: Dictionary = castle.matching_progress()[0]
		if pails < 3:
			check(entry["missed"], "castle task missed after the wave")
			check(castle.is_flattened(), "unfinished castle flattened")
			check((castle.get_node("Art") as Sprite2D).texture == castle.flattened_frame, "flattened frame shown")
			check_eq(entry["current"], 1, "delivery count unchanged")
		else:
			check(entry["done"], "castle task done before the wave")
			check_false(castle.is_flattened(), "finished castle stays")
			check_eq(frame, 3, "finished frame kept")
		level.queue_free()
		await frames(1)
