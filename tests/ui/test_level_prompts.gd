extends "res://tests/support/level_case.gd"
## Beach Camp teaches the controls in place: move, grab, throw and use prompts sit at the castaway, the first
## chicken, the first coconut and the cage, each disappears once its action was used (also after a restart), the
## texts follow the locale and the key caps come from the input map. Farm Meadow shows no basic prompts.

const L1 := "res://scenes/levels/l1_beach_camp.tscn"
const L2 := "res://scenes/levels/l2_farm_meadow.tscn"


func _actions() -> Array:
	var out: Array = []
	for p in level.prompts():
		out.append((p as ContextPrompt).action)
	out.sort()
	return out


func _prompt(action: String) -> ContextPrompt:
	for p in level.prompts():
		if (p as ContextPrompt).action == action:
			return p
	return null


func test_four_prompts_at_their_anchors() -> void:
	await open_level(L1)
	await frames(1)
	check_eq(_actions(), ["grab", "move", "throw", "use"], "prompt actions")
	var anchors := {"move": castaway, "grab": level.entity_registry().find_uid("chicken_1"),
			"throw": level.entity_registry().find_uid("coconut_1"), "use": level.zone("cage")}
	for action in anchors:
		var p := _prompt(action)
		check(p != null and p.anchor() == anchors[action], "%s prompt anchored" % action)
		if p != null:
			check(p.visible, "%s prompt visible" % action)
			check(p.global_position.distance_to((anchors[action] as Node2D).global_position) < 200.0, "%s prompt near its anchor" % action)
			check(p.key_cap() != null, "%s key cap" % action)
	check(level.spawn_position().distance_to(level.entity_registry().find_uid("chicken_1").global_position) <= 3.0 * 128.0,
			"first chicken within three tiles of the spawn")


func test_used_actions_remove_their_prompts_for_good() -> void:
	await open_level(L1)
	move = Vector2.RIGHT
	await physics_frames(30)
	move = Vector2.ZERO
	await frames(2)
	check_eq(_actions(), ["grab", "throw", "use"], "move prompt gone after walking")
	var chicken := level.entity_registry().find_uid("chicken_1")
	await place_castaway(chicken.global_position + Vector2(-50, 0), 0.0)
	press_interact()
	await physics_frames(2)
	await frames(2)
	check_eq(_actions(), ["throw", "use"], "grab prompt gone after grabbing")
	castaway.global_position = level.get_node("Actors/CageGate").global_position + Vector2(0, 60)
	castaway.reset_physics_interpolation()
	await physics_frames(2)
	check(castaway.get_carried() != null, "still carrying")
	check_eq(castaway.get_interact_verb(), CastawayLogic.VERB_USE, "the cage gate takes the chicken")
	press_interact()
	await physics_frames(2)
	await frames(2)
	check_eq(_actions(), ["throw"], "use prompt gone after using the cage")
	level.restart_level()
	await frames(2)
	check_eq(_actions(), ["throw"], "used prompts stay gone after a restart")


func test_prompt_texts_follow_the_locale() -> void:
	await open_level(L1)
	await frames(1)
	check_eq(_prompt("grab").label().text, "Grab", "English")
	I18n.set_locale("de")
	await frames(1)
	check_eq(_prompt("grab").label().text, "Greifen", "German")
	check_eq(_prompt("use").label().text, "Benutzen", "German use")


func test_farm_meadow_has_no_basic_prompts() -> void:
	await open_level(L2)
	await frames(1)
	check_eq(level.level_def().prompts.size(), 0, "no prompts in level 2")
	check(level.prompts().is_empty(), "no prompt nodes")
