extends "res://tests/support/entity_scene_case.gd"
## EntityRegistry: snapshot format and uids, held/worn, panic and relocate effects, restart and zone queries.


func test_snapshot_format_and_stable_uids() -> void:
	await build()
	var snap := registry.snapshot_entities()
	check_eq(snap.size(), EntityDefs.animal_kinds().size() + EntityDefs.item_kinds().size(), "one per entity")
	var uids := {}
	for entry: Dictionary in snap:
		check_eq(entry.keys().size(), 5, "keys of %s" % str(entry))
		for key in ["uid", "kind", "zones", "held_by", "worn_by"]:
			check(entry.has(key), "%s in %s" % [key, str(entry)])
		uids[entry["uid"]] = true
		check_eq(entry["uid"], "%s_1" % entry["kind"], "uid")
	check_eq(uids.size(), snap.size(), "unique uids")
	await physics_frames(3)
	check_eq(registry.snapshot_entities()[0]["uid"], snap[0]["uid"], "stable")


func test_held_and_worn() -> void:
	await build(["pig", "goat"], ["hat"])
	animal("pig").on_grabbed(castaway)
	item("hat").wear_on(animal("goat"), "goat")
	await physics_frames(2)
	var by_kind := {}
	for entry: Dictionary in registry.snapshot_entities():
		by_kind[entry["kind"]] = entry
	check_eq(by_kind["pig"]["held_by"], "player", "carried pig")
	check_eq(by_kind["hat"]["worn_by"], "goat", "worn hat")
	check(item("hat").global_position.distance_to(animal("goat").global_position) < 60.0, "hat follows the goat")
	animal("pig").on_released()
	item("hat").take_off()
	await physics_frames(1)
	for entry: Dictionary in registry.snapshot_entities():
		check_eq(entry["held_by"], "", "released")
		check_eq(entry["worn_by"], "", "taken off")


func test_panic_kind_and_panic_all() -> void:
	await build(["chicken", "duck", "goat"], [])
	check_eq(registry.panic_kind("chicken", 1.0), 1, "one chicken")
	await physics_frames(2)
	check_eq(animal("chicken").get_state_name(), "panic", "chicken panics")
	check(animal("duck").get_state_name() != "panic", "duck calm")
	check_eq(registry.panic_all(cfg.reaction_max_seconds + 10.0), 3, "all three")
	await physics_frames(2)
	for kind in ["chicken", "duck", "goat"]:
		check_eq(animal(kind).get_state_name(), "panic", "%s panics" % kind)
	await physics_frames(ticks_for(cfg.reaction_max_seconds) + 2)
	for kind in ["chicken", "duck", "goat"]:
		check(animal(kind).brain.is_normal(), "%s normal again: %s" % [kind, animal(kind).get_state_name()])


func test_relocate_skips_carried_and_protected() -> void:
	await build(["chicken", "pig"], [])
	var target := Vector2(700, 600)
	animal("pig").on_grabbed(castaway)
	check_eq(registry.relocate("pig", target), 0, "carried pig stays")
	registry.set_protection(func(info: Dictionary) -> bool: return info["kind"] == "chicken")
	check_eq(registry.relocate("chicken", target), 0, "protected chicken stays")
	registry.set_protection(Callable())
	check_eq(registry.relocate("chicken_1", target), 1, "by uid")
	check_eq(animal("chicken").global_position, target, "moved")


func test_reset_all_puts_everything_home() -> void:
	await build(["chicken", "monkey"], ["coconut"])
	animal("chicken").relocate_to(Vector2(700, 600))
	animal("monkey").on_grabbed(castaway)
	animal("chicken").bonk(Vector2.RIGHT, "coconut")
	item("coconut").relocate_to(Vector2(800, 100))
	await physics_frames(2)
	registry.reset_all()
	check_eq(animal("chicken").global_position, arena.ANIMAL_HOMES["chicken"], "chicken home")
	check_eq(animal("monkey").global_position, arena.ANIMAL_HOMES["monkey"], "monkey home")
	check_eq(item("coconut").global_position, arena.ITEM_HOMES["coconut"], "coconut home")
	check(animal("chicken").brain.is_normal(), "chicken calm")
	check_eq(animal("monkey").held_by(), "", "monkey free")


func test_zone_containment_without_physics_frame() -> void:
	await build(["chicken"], ["coconut"])
	var circle := Zone.new()
	circle.zone_id = "ring"
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 50.0
	shape.shape = c
	circle.add_child(shape)
	circle.position = Vector2(500, 450)
	arena.add_child(circle)
	item("coconut").relocate_to(Vector2(530, 450))
	check_has(registry.zones_of(item("coconut")), "ring", "inside the circle at once")
	item("coconut").relocate_to(Vector2(560, 450))
	check_false(registry.zones_of(item("coconut")).has("ring"), "outside the circle")
	animal("chicken").relocate_to(arena.CAGE.get_center())
	check_has(registry.zones_of(animal("chicken")), "cage", "inside the rectangle at once")
	check(circle.contains_with_margin(Vector2(510, 450), 20.0), "margin inside")
	check_false(circle.contains_with_margin(Vector2(545, 450), 20.0), "margin outside")
	check(arena.cage.clamp_inside(Vector2(0, 0), 20.0).distance_to(arena.CAGE.position + Vector2(20, 20)) < 0.01,
			"clamp")


func test_unreachable_reasons() -> void:
	await build(["chicken", "duck"], ["coconut"])
	var cases := [[Vector2(500, 820), "water"], [Vector2(-50, 300), "bounds"], [arena.ROCK.get_center(), "stuck"],
			[arena.POCKET.get_center(), "stuck"], [Vector2(500, 450), ""]]
	for c in cases:
		item("coconut").relocate_to(c[0])
		check_eq(registry.unreachable_reason(item("coconut")), c[1], "coconut at %s" % str(c[0]))
	animal("duck").relocate_to(Vector2(500, 820))
	check_eq(registry.unreachable_reason(animal("duck")), "", "ducks swim")
