extends "res://tests/support/level_case.gd"
## Shipped levels (data/levels + scenes/levels): load cleanly, carry their own theme and music, have the event
## anchors, the feedback director and the event effects, and every use target is reachable on foot.

const LEVELS := ["l1_beach_camp", "l2_farm_meadow"]
const CAMPAIGN := "res://data/campaign.json"


func _campaign() -> Campaign:
	return Campaign.load_file(CAMPAIGN)["campaign"]


func _scene(id: String) -> String:
	return String(_campaign().entry(id)["scene"])


func test_campaign_lists_the_shipped_levels() -> void:
	var c := _campaign()
	check_eq(c.ids().slice(0, LEVELS.size()), LEVELS, "level ids")
	check_eq(c.first_id(), "l1_beach_camp", "first level")
	for id in LEVELS:
		var e := c.entry(id)
		check_true(e["available"], "%s available" % id)
		check(ResourceLoader.exists(String(e["scene"])), "%s scene exists" % id)
		check(FileAccess.file_exists(String(e["json"])), "%s json exists" % id)


func test_every_shipped_level_is_complete_and_reachable() -> void:
	var themes := {}
	var music := {}
	for id in LEVELS:
		await open_level(_scene(id))
		check_false(level.is_failed(), "%s loads: %s" % [id, str(level.load_errors())])
		if level.is_failed():
			continue
		check_eq(level.prompt_problems(), [], "%s prompts placed" % id)
		check_eq(level.level_json_path, String(_campaign().entry(id)["json"]), "%s json path" % id)
		var def := level.level_def()
		themes[def.theme] = true
		music[def.music] = true
		check(level.feedback_director() != null, "%s has a FeedbackDirector" % id)
		check(level.event_effects() != null, "%s has EventEffects" % id)
		for ev in def.events:
			var anchor := level.get_node_or_null("EventAnchors/%s" % ev["id"]) as EventAnchor
			check(anchor != null and anchor.event_id == ev["id"], "%s: anchor for event %s" % [id, ev["id"]])
			for key in ["zone", "flee_zone", "thrower_zone", "lane"]:
				if ev["params"].has(key):
					check(level.zone(String(ev["params"][key])) != null, "%s: zone %s of %s" % [id, ev["params"][key], ev["id"]])
		var reach := level.reachable_from(level.cell_of(level.spawn_position()))
		var targets := tree().get_nodes_in_group(UseTarget.GROUP).filter(func(n: Node) -> bool: return level.is_ancestor_of(n))
		check(targets.size() >= 2, "%s has use targets" % id)
		for target in targets:
			check(reach.has(level.cell_of(target.global_position)), "%s: use target %s reachable" % [id, target.name])
			if target is PenTarget:
				check_false((target as PenTarget).slots().is_empty(), "%s: %s has slots" % [id, target.name])
		for task in def.tasks:
			for cond in task["conditions"]:
				if cond["type"] == "delivered_to":
					var kind := String(cond["target"])
					var found := targets.any(func(t: Node) -> bool: return String(t.get("target_kind")) == kind)
					check(found, "%s: a use target of kind %s exists" % [id, kind])
		level.queue_free()
		await frames(1)
	check_eq(themes.size(), LEVELS.size(), "every level has its own theme")
	check_eq(music.size(), LEVELS.size(), "every level has its own music")


func test_pen_slots_lie_inside_their_zone() -> void:
	var pens := {"l1_beach_camp": {"CageGate": "cage"}, "l2_farm_meadow": {"PondJetty": "pond", "PenGate": "pig_pen"}}
	for id in pens:
		await open_level(_scene(id))
		for gate_name in pens[id]:
			var gate := level.get_node("Actors/%s" % gate_name) as PenTarget
			var area := level.zone(String(pens[id][gate_name]))
			check(area.contains, "%s: %s is a pen" % [id, area.zone_id])
			for slot in gate.slots():
				check(area.contains_point((slot as Node2D).global_position), "%s: %s in %s" % [id, slot.name, area.zone_id])
		level.queue_free()
		await frames(1)
