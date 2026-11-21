extends "res://tests/support/entity_scene_case.gd"
## Animal and item look: pack sprites big enough at 720p, shadows, no placeholder shapes, waddle, hops, speed lines,
## dizzy stars only while bonked and the flip towards the movement.

const MIN_SIDE_720P := 24.0


func test_sprites_shadows_and_no_placeholders() -> void:
	await build()
	for kind in EntityDefs.animal_kinds():
		var a := animal(kind)
		var tex := a.visual.body.texture
		check_eq(tex.resource_path, a.def["sprite"], "%s sprite" % kind)
		check(tex.resource_path.contains("Round (outline)"), "%s round animal sprite" % kind)
		var side := minf(tex.get_width(), tex.get_height()) * a.visual.body.scale.x * 720.0 / 1080.0
		check(side >= MIN_SIDE_720P, "%s on-screen size %.1f" % [kind, side])
		check(a.shadow is Sprite2D and a.shadow.texture != null, "%s shadow" % kind)
	for kind in EntityDefs.item_kinds():
		var it := item(kind)
		check(it.body.texture.resource_path.contains("assets/graphics/items/"), "%s item-pack sprite" % kind)
		check_eq(it.body.texture.resource_path, it.def["sprite"], "%s sprite" % kind)
		check(it.shadow.texture != null, "%s shadow" % kind)
	for path in ["res://scenes/entities/animal.tscn", "res://scenes/entities/item.tscn"]:
		var text := FileAccess.get_file_as_string(path)
		check_false(text.contains("ColorRect") or text.contains("Polygon2D"), "%s has no placeholder shapes" % path)


func test_waddle_hop_flip_and_effects() -> void:
	await build(["chicken"], [])
	var a := animal("chicken")
	var waddled := false
	var hopped_idle := false
	var flips := {}
	for i in ticks_for(cfg.idle_hop_interval * 2.0 + cfg.wander_pause_max + 3.0):
		await physics_frames(1)
		var st := a.get_state_name()
		if st == "wander" and absf(a.visual.waddle) > 0.0:
			waddled = true
		if st == "idle" and a.visual.hop_offset > 0.0:
			hopped_idle = true
		if absf(a.velocity.x) > 1.0:
			flips[a.velocity.x < 0.0] = a.visual.body.flip_h == (a.velocity.x < 0.0)
	check(waddled, "waddles while walking")
	check(hopped_idle, "hops while idle")
	for key in flips:
		check(flips[key], "flip follows the movement (left=%s)" % str(key))
	check_false(a.stars.visible, "no stars while calm")
	a.panic(1.0)
	await physics_frames(3)
	check(a.speed_lines.emitting, "speed lines while panicking")
	check(director.active_count("emote") > 0, "alert emote from the feedback director")
	a.brain.panic_left = 0.0
	a.bonk(Vector2.RIGHT, "coconut")
	await physics_frames(2)
	check(a.stars.visible, "stars while bonked")
	check_false(a.speed_lines.emitting, "no speed lines while dizzy")
	await wait_until(func() -> bool: return a.brain.is_normal(), ticks_for(cfg.reaction_max_seconds) + 2)
	check_false(a.stars.visible, "stars gone")
