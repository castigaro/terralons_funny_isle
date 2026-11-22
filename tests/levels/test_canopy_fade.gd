extends "res://tests/support/level_case.gd"
## Canopy fade (BI-21): a decoration prop with occlusion_fade fades its sprite while an actor stands behind its crown
## and fades back in once the actor has left the crown plus margin and hysteresis; props without it stay unchanged.

const SWAY_SCENE := "res://scenes/levels/props/sway_prop.tscn"
const PALM_SCENE := "res://scenes/levels/props/palm.tscn"
const TREE := "res://assets/graphics/foliage/PNG/Retina/foliagePack_011.png"
const TICKS_FADE := 15
const TICKS_BACK := 18
const TICKS_HOLD := 60


func _fade_cfg() -> Dictionary:
	return Balance.get_section("level")


func _new_tree(fade: bool = true) -> SwayProp:
	var prop := (load(SWAY_SCENE) as PackedScene).instantiate() as SwayProp
	prop.texture = load(TREE)
	prop.sprite_scale = 0.7
	prop.occlusion_fade = fade
	return prop


## Adds a tree whose crown covers the castaway: the base sits below the castaway by half the crown height.
func _tree_over_castaway(fade: bool = true) -> SwayProp:
	var prop := _new_tree(fade)
	var height := 422.0 * 0.7
	prop.position = castaway.global_position + Vector2(0.0, height * 0.5)
	level.get_node("Actors").add_child(prop)
	return prop


func test_castaway_behind_canopy_fades_it() -> void:
	await open_level()
	var prop := _tree_over_castaway()
	var shadow_alpha := prop.shadow.modulate.a
	await physics_frames(TICKS_FADE)
	check(prop.is_occluded(), "castaway behind the crown")
	check(prop.sprite.modulate.a <= 0.5, "crown faded (alpha %.2f)" % prop.sprite.modulate.a)
	check(is_equal_approx(prop.sprite.modulate.a, float(_fade_cfg()["canopy_fade_alpha"])), "fade alpha from the balance")
	check(is_equal_approx(prop.shadow.modulate.a, shadow_alpha), "shadow unchanged while faded")
	var cfg := _fade_cfg()
	prop.position.x += prop.crown_rect().size.x + float(cfg["canopy_fade_margin_px"]) + float(cfg["canopy_fade_hysteresis_px"]) + 8.0
	await physics_frames(TICKS_BACK)
	check_false(prop.is_occluded(), "castaway out of the crown")
	check(is_equal_approx(prop.sprite.modulate.a, 1.0), "crown back to full alpha (%.2f)" % prop.sprite.modulate.a)
	check(is_equal_approx(prop.shadow.modulate.a, shadow_alpha), "shadow unchanged after fading back")


func test_actor_at_the_trunk_does_not_fade() -> void:
	await open_level()
	var prop := _new_tree()
	var height := 422.0 * 0.7
	# The castaway stands at the trunk, below the crown share plus margin.
	prop.position = castaway.global_position + Vector2(0.0, height * 0.02)
	level.get_node("Actors").add_child(prop)
	await physics_frames(TICKS_FADE)
	check_false(prop.is_occluded(), "trunk does not count as crown")
	check(is_equal_approx(prop.sprite.modulate.a, 1.0), "no fade at the trunk")


func test_palm_crown_fades_over_any_actor() -> void:
	await open_level()
	var palm := (load(PALM_SCENE) as PackedScene).instantiate() as PalmProp
	palm.occlusion_fade = true
	palm.solid = false
	level.get_node("Actors").add_child(palm)
	palm.global_position = castaway.global_position - palm.sprite.position + Vector2(0.0, -2.0)
	await physics_frames(TICKS_FADE)
	check(palm.is_occluded(), "palm crown over the castaway")
	check(palm.sprite.modulate.a <= 0.5, "palm crown faded")
	check(palm.get_node_or_null("Footprint") == null, "walk-through palm has no footprint")


func test_animal_and_item_fade_the_canopy() -> void:
	await open_level()
	for path in ["Actors/Chicken1", "Actors/Coconut1"]:
		var actor := level.get_node(path) as Node2D
		check(actor != null and actor.is_in_group(SwayProp.ACTOR_GROUP), "%s is an actor" % path)
		var prop := _new_tree()
		prop.position = actor.global_position + Vector2(0.0, 422.0 * 0.7 * 0.5)
		level.get_node("Actors").add_child(prop)
		await physics_frames(TICKS_FADE)
		check(prop.is_occluded(), "%s behind the crown fades it" % path)
		prop.queue_free()
		await physics_frames(1)


func test_no_flicker_at_the_edge() -> void:
	await open_level()
	var prop := _tree_over_castaway()
	await physics_frames(TICKS_FADE)
	var cfg := _fade_cfg()
	var faded := prop.sprite.modulate.a
	var crown := prop.crown_rect()
	# Park the castaway between margin and margin + hysteresis right of the crown.
	var want_x := crown.end.x + float(cfg["canopy_fade_margin_px"]) + float(cfg["canopy_fade_hysteresis_px"]) * 0.5
	prop.position.x -= want_x - castaway.global_position.x
	var lowest := 1.0
	var highest := 0.0
	for i in TICKS_HOLD:
		await physics_frames(1)
		lowest = minf(lowest, prop.sprite.modulate.a)
		highest = maxf(highest, prop.sprite.modulate.a)
	check(is_equal_approx(highest, faded) and is_equal_approx(lowest, faded), "alpha holds inside the hysteresis band")
	var alpha := float(cfg["canopy_fade_alpha"])
	var rate := (1.0 - alpha) / float(cfg["canopy_fade_seconds"])
	prop.position.x -= float(cfg["canopy_fade_hysteresis_px"])
	await physics_frames(1)
	var step_in := prop.sprite.modulate.a - faded
	check(is_equal_approx(step_in, rate / 60.0), "fade-in step %.4f equals rate / fps" % step_in)
	prop.position.x += float(cfg["canopy_fade_hysteresis_px"]) * 4.0 + crown.size.x
	var before := prop.sprite.modulate.a
	await physics_frames(1)
	check(prop.is_occluded(), "inside again")
	check(is_equal_approx(before - prop.sprite.modulate.a, rate / 60.0), "fade-out step equals the fade-in step")


func test_defaults_are_inert() -> void:
	await open_level()
	var prop := _new_tree(false)
	prop.position = castaway.global_position + Vector2(0.0, 422.0 * 0.7 * 0.5)
	level.get_node("Actors").add_child(prop)
	await physics_frames(TICKS_FADE)
	check_false(prop.is_physics_processing(), "no canopy polling by default")
	check(prop.sprite.self_modulate.is_equal_approx(Color.WHITE), "no tint by default")
	check(prop.shadow.visible, "shadow visible by default")
	check_false(prop.sprite.flip_h, "no mirror by default")
	check(is_equal_approx(prop.sprite.modulate.a, 1.0), "no fade by default")
	var palm := (load(PALM_SCENE) as PackedScene).instantiate() as PalmProp
	level.get_node("Actors").add_child(palm)
	check(palm.get_node_or_null("Footprint") is StaticBody2D, "a default palm keeps its solid trunk")
