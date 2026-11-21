extends "res://tests/support/level_case.gd"
## watchdog: 200
## Every event of the shipped levels is presented: a warning (EventBus event_warning, HUD warning cue for at least
## 2 s, feedback at the event anchor), then at the trigger an actor or overlay of EventEffects, its event sound
## request and a funny reaction from the feedback director. Runs with the earliest schedule so the events come quickly.

const LEVELS := ["l1_beach_camp", "l2_farm_meadow"]
const WARN_PREFIX := "hud.cue.warn."
## Popups and emotes rise above their anchor point.
const RISE_PX := 160.0


func _near_anchor(pos: Vector2, anchor: Vector2) -> bool:
	return absf(pos.x - anchor.x) < 1.0 and pos.y <= anchor.y + 1.0 and pos.y >= anchor.y - RISE_PX


func test_events_warn_animate_and_react() -> void:
	for id in LEVELS:
		await open_level(LevelCatalogue.scene_path(id), {"session_options": {"schedule_mode": "earliest"}})
		var session := level.level_session()
		var schedule := session.schedule()
		var hud := level.hud()
		for entry in schedule:
			var event_id := String(entry["id"])
			var warned := false
			var cue_seconds := 0.0
			var presented := false
			while session.elapsed() < float(entry["start"]) + 1.0:
				await physics_frames(1)
				if hud.current_cue_key() == WARN_PREFIX + String(entry["type"]):
					cue_seconds += 1.0 / 60.0
				if level.event_effects().active_event_ids().has(event_id):
					presented = presented or not level.event_effects().actor_nodes().is_empty() \
							or not level.event_effects().overlay_nodes().is_empty()
			for e in events("event_warning"):
				if e[1][0] == event_id:
					warned = true
			check(warned, "%s: %s warned" % [id, event_id])
			check(cue_seconds >= 1.9, "%s: warning cue for %s visible %.2f s" % [id, event_id, cue_seconds])
			check(presented, "%s: %s has an actor or overlay" % [id, event_id])
			var sfx := String(Audio.audio_map().resolve("event_triggered", [String(entry["type"]), event_id]).get("sfx", ""))
			check(sfx != "", "%s: %s maps to a sound" % [id, event_id])
			check_has(Audio.sfx_requests(), sfx, "%s: %s requested its sound" % [id, event_id])
			var anchor := (level.get_node("EventAnchors/%s" % event_id) as Node2D).global_position
			var at_anchor := level.feedback_director().last_effects().filter(
					func(fx: Dictionary) -> bool: return fx["position"] is Vector2 and _near_anchor(fx["position"], anchor))
			check(at_anchor.size() >= 2, "%s: warning and reaction at the %s anchor (%d effects)" % [id, event_id, at_anchor.size()])
			var popups := at_anchor.filter(func(fx: Dictionary) -> bool: return fx["type"] == "popup" or fx["type"] == "emote")
			check_false(popups.is_empty(), "%s: a funny popup or emote for %s" % [id, event_id])
		level.queue_free()
		await frames(1)
