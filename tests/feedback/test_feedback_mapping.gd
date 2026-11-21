extends "res://tests/support/feedback_case.gd"
## Signal to effect mapping: effect types and positions per signal, landing variants by surface, anchor
## consumption, screen-anchored signals and emotes that follow a moving animal.


func _material_of_last_splat() -> Color:
	var nodes := director.active_nodes("splat")
	return (nodes[nodes.size() - 1] as Sprite2D).modulate if not nodes.is_empty() else Color.BLACK


func _same_rgb(a: Color, b: Color) -> bool:
	return is_equal_approx(a.r, b.r) and is_equal_approx(a.g, b.g) and is_equal_approx(a.b, b.b)


func test_every_mapped_signal_plays_its_entry_types() -> void:
	make_director()
	var target := make_target(Vector2(200, 200))
	var cases := {
		"castaway_step": [Vector2(10, 20), "grass"],
		"castaway_dashed": [Vector2(10, 20), Vector2.RIGHT],
		"object_grabbed": ["coconut"],
		"object_thrown": ["coconut"],
		"object_used": ["bucket", "sandcastle"],
		"object_landed": ["coconut", Vector2(5, 5), "grass"],
		"object_bonked": ["castaway", "coconut"],
		"task_completed": ["lvl", "t1"],
		"all_required_done": ["lvl"],
		"timer_warning": ["lvl", 10.0],
		"castaway_dizzy_started": ["coconut"],
		"animal_fled": ["chicken"],
		"animal_bonked": ["goat", "coconut"],
		"animal_panicked": ["chicken"],
		"animal_caught": ["pig"],
		"animal_lured": ["monkey"],
		"entity_lost": ["coconut", "water"],
		"entity_respawned": ["coconut", Vector2(50, 50)],
		"level_won": ["lvl", 3],
		"level_lost": ["lvl", []],
		"level_started": ["lvl"],
	}
	for sig_name in cases:
		await frames(30)
		director.clear_last_effects()
		emit("fx_anchor_node", ["chicken", target])
		emit(sig_name, cases[sig_name])
		var expected: Array = []
		for entry in director.map.entries_for(sig_name, cases[sig_name]):
			if not expected.has(entry["effect"]):
				expected.append(entry["effect"])
		var played := types_for(sig_name)
		check(expected.size() > 0, "%s has entries" % sig_name)
		for effect in expected:
			if effect == "hitstop" and director.hitstop_state()["cooldown_until_ms"] > frame_clock():
				continue
			check_has(played, effect, "%s plays %s" % [sig_name, effect])


func test_position_from_signal_argument() -> void:
	make_director()
	director.clear_last_effects()
	emit("castaway_step", [Vector2(123, 456), "grass"])
	var e: Array = effects_for("castaway_step")
	check_eq(e.size(), 1, "one dust burst")
	check_eq(e[0]["position"], Vector2(123, 456), "at the step position")
	check_false(e[0]["screen"], "world space")


func test_landing_variants_by_surface() -> void:
	make_director()
	var mats := director.map.materials
	for surface in ["water", "sand", "mud"]:
		director.clear_last_effects()
		emit("object_landed", ["coconut", Vector2(300, 300), surface])
		var types := types_for("object_landed")
		check_has(types, "splat", "%s splat" % surface)
		check(_same_rgb(_material_of_last_splat(), mats[surface]), "%s splat tint" % surface)
	director.clear_last_effects()
	emit("object_landed", ["coconut", Vector2(300, 300), "water"])
	check_eq(director.last_popup_text(), "SPLASH!", "water popup")
	emit("object_landed", ["coconut", Vector2(300, 300), "mud"])
	check_eq(director.last_popup_text(), "SPLAT!", "mud popup")
	director.clear_last_effects()
	emit("object_landed", ["coconut", Vector2(300, 300), "grass"])
	check_false(types_for("object_landed").has("splat"), "grass lands without a splat")
	check_has(types_for("object_landed"), "puff", "grass puff")


func test_anchor_consumed_once_then_castaway() -> void:
	make_director()
	var target := make_target(Vector2(700, 100))
	director.clear_last_effects()
	emit("fx_anchor", ["coconut", Vector2(321, 123)])
	emit("entity_lost", ["coconut", "water"])
	var first: Array = effects_for("entity_lost")
	check(first.size() >= 1, "played")
	check_eq(first[0]["position"], Vector2(321, 123), "puff at the anchor")
	director.clear_last_effects()
	emit("entity_lost", ["coconut", "water"])
	check_eq(effects_for("entity_lost")[0]["position"], castaway_stub.global_position, "falls back to castaway")
	director.clear_last_effects()
	emit("fx_anchor_node", ["goat", target])
	emit("animal_bonked", ["goat", "coconut"])
	var bonk: Array = effects_for("animal_bonked")
	var popup_pos := Vector2.ZERO
	for e in bonk:
		if e["type"] == "popup":
			popup_pos = e["position"]
	check_eq(popup_pos, Vector2(700, 100) + director.strengths.vec("popup_face_offset"), "popup over the node")
	check_eq(target.squashes.size(), 1, "squash on the anchor node")
	check_eq(target.recoils.size(), 1, "recoil on the anchor node")
	var dir: Vector2 = (target.recoils[0][0] as Vector2).normalized()
	var away := (target.global_position - castaway_stub.global_position).normalized()
	check(dir.dot(away) > 0.99, "recoil points away from the castaway")


func test_no_visual_signal_keeps_the_anchor() -> void:
	make_director()
	director.clear_last_effects()
	emit("fx_anchor", ["coconut", Vector2(11, 22)])
	emit("interact_verb_changed", ["grab", "coconut"])
	emit("entity_lost", ["coconut", "bounds"])
	check_eq(effects_for("entity_lost")[0]["position"], Vector2(11, 22), "anchor survives a no_visual signal")
	check_eq(effects_for("interact_verb_changed"), [], "no visual for interact_verb_changed")


func test_anchor_expires_at_frame_end() -> void:
	make_director()
	emit("fx_anchor", ["coconut", Vector2(11, 22)])
	await frames(1)
	director.clear_last_effects()
	emit("entity_lost", ["coconut", "bounds"])
	check_eq(effects_for("entity_lost")[0]["position"], castaway_stub.global_position, "stale anchor dropped")


func test_screen_anchored_signals_use_screen_layer() -> void:
	make_director()
	for sig_name in ["task_completed", "timer_warning", "all_required_done", "level_won", "level_lost"]:
		await frames(30)
		director.clear_last_effects()
		var args: Array = ["lvl", "t"] if sig_name == "task_completed" else (["lvl", 5.0] if sig_name ==
				"timer_warning" else (["lvl", 2] if sig_name == "level_won" else (["lvl", []] if sig_name ==
				"level_lost" else ["lvl"])))
		emit(sig_name, args)
		var popups := 0
		for e in effects_for(sig_name):
			if e["type"] == "popup":
				popups += 1
				check(e["screen"], "%s popup on screen" % sig_name)
		check(popups >= 1, "%s popup" % sig_name)
	for node in director.active_nodes("popup"):
		if (node as Node).get_parent() == director.screen_layer:
			return
	fail("no popup is parented to the ScreenLayer")


func test_without_castaway_falls_back_to_screen() -> void:
	make_director(false)
	director.clear_last_effects()
	emit("object_grabbed", ["coconut"])
	var e: Array = effects_for("object_grabbed")
	check(e.size() >= 1 and e[0]["screen"], "no castaway, no anchor: screen centre")


func test_follow_emote_tracks_moving_animal() -> void:
	make_director()
	var animal := make_target(Vector2(100, 100))
	emit("fx_anchor_node", ["chicken", animal])
	emit("animal_fled", ["chicken"])
	var emotes := director.active_nodes("emote")
	check_eq(emotes.size(), 1, "one emote")
	animal.position = Vector2(500, 260)
	await frames(2)
	var height := director.strengths.num("emote_height")
	check_eq((emotes[0] as Sprite2D).position, Vector2(500, 260 - height), "emote follows the animal")
	animal.queue_free()
	await frames(2)
	check_eq((emotes[0] as Sprite2D).position, Vector2(500, 260 - height), "stays at the last position when freed")


func test_squash_skipped_without_contract() -> void:
	make_director()
	var plain := Node2D.new()
	add_node(plain)
	director.clear_last_effects()
	emit("fx_anchor_node", ["rock", plain])
	emit("animal_caught", ["pig"])
	check_false(types_for("animal_caught").has("squash"), "no squash for nodes without fx_squash")
	check_has(types_for("animal_caught"), "popup", "popup still plays")


func test_effects_expire() -> void:
	make_director()
	emit("castaway_dashed", [Vector2(1, 1), Vector2.RIGHT])
	check(director.active_count("puff") > 0, "puff active")
	await frames(int(ceil(director.strengths.num("puff_seconds") * 60.0)) + 3)
	check_eq(director.active_count("puff"), 0, "puff released after puff_seconds")
	var popup_left := director.strengths.num("popup_seconds") - director.strengths.num("puff_seconds")
	await frames(int(ceil(popup_left * 60.0)) + 3)
	check_eq(director.active_count("popup"), 0, "popup released after popup_seconds")
