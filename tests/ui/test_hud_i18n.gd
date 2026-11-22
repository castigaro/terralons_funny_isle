extends "res://tests/support/level_case.gd"
## Live language switch: every HUD and prompt text follows I18n.set_locale without re-instancing the level.


func before_each() -> void:
	PromptMemory.reset()


func _snapshot(hud: Hud) -> Array:
	var out: Array = []
	for b in hud.text_bindings():
		out.append({"node": b[0], "id": (b[0] as Object).get_instance_id(), "key": String(b[1]),
				"text": (b[0] as Label).text})
	for p in level.prompts():
		var prompt := p as ContextPrompt
		out.append({"node": prompt.label(), "id": prompt.label().get_instance_id(), "key": prompt.text_key,
				"text": prompt.label().text})
	return out


func test_texts_switch_live_between_en_and_de() -> void:
	await open_level()
	var hud := level.hud()
	hud.show_hint()
	hud.on_failure_signal("castaway_dizzy_started", ["coconut"])
	EventBus.interact_verb_changed.emit("grab", "coconut")
	await frames(1)
	var en := _snapshot(hud)
	var star: Array = hud.star_goal_binding()
	var star_label := star[0] as Label
	var star_en := star_label.text
	var tip_en := hud.panel("TimerPanel").tooltip_text
	check_eq(star_en, I18n.t(String(star[1]), star[2]), "EN star goal line")
	check_eq(tip_en, I18n.t(Hud.STAR_GOAL_TIP_KEY, star[2]), "EN star goal tooltip")
	var keys := en.map(func(e: Dictionary) -> String: return e["key"])
	for want in ["hud.required", "hud.optional", "hud.cue.dizzy_hit", "hud.verb.grab", "fixture.reach_a_hint",
			"fixture.reach_a_title", "fixture.prompt_move"]:
		check_has(keys, want, "binding for %s" % want)
	for e in en:
		check_eq(e["text"], level.text_in(e["key"], "en"), "EN %s" % e["key"])
	var level_id := level.get_instance_id()
	I18n.set_locale("de")
	await frames(1)
	check_eq(level.get_instance_id(), level_id, "same level instance")
	var changed := 0
	for e in en:
		var label := e["node"] as Label
		check(is_instance_valid(label) and label.get_instance_id() == e["id"], "same node for %s" % e["key"])
		var de := level.text_in(e["key"], "de")
		check_eq(label.text, de, "DE %s" % e["key"])
		if de != e["text"]:
			changed += 1
	check(changed * 2 >= en.size(), "most texts changed (%d of %d)" % [changed, en.size()])
	star = hud.star_goal_binding()
	check(star[0] == star_label, "same star goal label")
	check_eq(star_label.text, I18n.t(String(star[1]), star[2]), "DE star goal line")
	check(star_label.text != star_en, "star goal line changed")
	check_eq(hud.panel("TimerPanel").tooltip_text, I18n.t(Hud.STAR_GOAL_TIP_KEY, star[2]), "DE star goal tooltip")
	check(hud.panel("TimerPanel").tooltip_text != tip_en, "tooltip changed")
	I18n.set_locale("en")
	await frames(1)
	for e in en:
		check_eq((e["node"] as Label).text, e["text"], "back to EN %s" % e["key"])
	check_eq(star_label.text, star_en, "back to EN star goal line")
	check_eq(hud.panel("TimerPanel").tooltip_text, tip_en, "back to EN star goal tooltip")
