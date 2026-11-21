extends "res://tests/support/level_case.gd"
## Interact prompt: interact_verb_changed shows the interact key cap with the verb text; "none" hides it.


func test_verbs_show_and_none_hides() -> void:
	await open_level()
	var hud := level.hud()
	var cap := hud.panel("InteractKey") as KeyCap
	var verb_label := hud.panel("VerbLabel") as Label
	for verb in ["grab", "throw", "use"]:
		EventBus.interact_verb_changed.emit(verb, "chicken")
		check_eq(hud.prompt_verb(), verb, "verb %s" % verb)
		check(hud.panel("InteractPrompt").visible, "prompt visible for %s" % verb)
		check_eq(verb_label.text, I18n.t("hud.verb." + verb), "verb text %s" % verb)
	check_eq(cap.label_text(), I18n.t("hud.key.space"), "interact key cap shows Space")
	check_eq(KeyCap.key_name(&"interact"), "Space", "first interact key")
	EventBus.interact_verb_changed.emit("none", "")
	check_eq(hud.prompt_verb(), "none", "none")
	check_false(hud.panel("InteractPrompt").visible, "hidden for none")


func test_castaway_near_coconut_shows_grab() -> void:
	await open_level()
	var hud := level.hud()
	var coconut := level.get_node("Actors/Coconut1") as Node2D
	await place_castaway(coconut.global_position + Vector2(-40, 0))
	await physics_frames(3)
	await frames(1)
	check_eq(hud.prompt_verb(), String(castaway.get_interact_verb()), "prompt follows the castaway verb")
