extends "res://tests/support/feedback_case.gd"
## Event warnings (AC1): every event type has warning visuals, LevelSession announces event_warning before every
## event_triggered, the director plays the warning at the event_anchor marker (or the castaway) and the start
## visuals of event_triggered use the type remembered from the warning.

const H := preload("res://tests/support/rules_helpers.gd")
const SignalRecorder := preload("res://tests/support/signal_recorder.gd")


class EventMarker extends Node2D:
	var event_id := ""


func test_every_event_type_has_warning_entries() -> void:
	make_director()
	for type in H.event_types():
		check(director.map.event_entries(type, "warning").size() > 0, "%s warning entries" % type)


func test_session_warns_before_trigger() -> void:
	var def := H.make_def(H.level_data())
	var rec := SignalRecorder.new(H.bus())
	var session := LevelSession.new(def, H.bus(), H.rules())
	var lead := float(H.rules()["event_warning_lead_seconds"])
	check(lead > 0.0, "lead from rules.json")
	session.start()
	for i in 180 * 10:
		session.tick(0.1, H.snap())
	var seen := {}
	var warn_time := {}
	for e in rec.filtered(["event_warning", "event_triggered"]):
		var id: String = e[1][0]
		if e[0] == "event_warning":
			check_false(seen.has(id), "%s warned before its trigger" % id)
			warn_time[id] = e[1][2]
			check_eq(e[1][1], _type_of(session, id), "%s type" % id)
		else:
			check(warn_time.has(id), "%s triggered after a warning" % id)
			seen[id] = true
	check_eq(seen.size(), 2, "both events fired")
	for id in warn_time:
		check(warn_time[id] <= lead + 0.11 and warn_time[id] >= 0.0, "%s seconds_until %.2f" % [id, warn_time[id]])
	rec.disconnect_all()


func test_warning_lead_clamped_at_zero() -> void:
	var data := H.level_data()
	data["events"][0]["window"] = [1, 1]
	var def := H.make_def(data)
	var rec := SignalRecorder.new(H.bus())
	var session := LevelSession.new(def, H.bus(), H.rules())
	session.start()
	session.tick(0.05, H.snap())
	var warns := rec.filtered(["event_warning"])
	check_eq(warns.size(), 1, "warning at the very start")
	check(absf(float(warns[0][1][2]) - 0.95) < 0.001, "seconds_until %s" % str(warns[0][1][2]))
	check_eq(rec.filtered(["event_triggered"]).size(), 0, "not triggered yet")
	session.tick(1.0, H.snap())
	check_eq(rec.filtered(["event_triggered"]).size(), 1, "triggered after 1 s")
	rec.disconnect_all()


func test_restart_state_stays_equal_with_warnings() -> void:
	var def := H.make_def(H.level_data())
	var session := LevelSession.new(def, null, H.rules())
	var fresh := session.state_dict()
	session.start()
	for i in 700:
		session.tick(0.1, H.snap())
	session.restart()
	check_eq(session.state_dict(), fresh, "restart restores the initial state")


func _type_of(session: LevelSession, id: String) -> String:
	for entry in session.schedule():
		if entry["id"] == id:
			return entry["type"]
	return ""


func test_director_plays_warning_at_marker_and_start_by_remembered_type() -> void:
	make_director()
	var marker := EventMarker.new()
	marker.event_id = "e_wave"
	marker.position = Vector2(900, 200)
	marker.add_to_group(FeedbackDirector.EVENT_ANCHOR_GROUP)
	add_node(marker)
	director.clear_last_effects()
	emit("event_warning", ["e_wave", "wave_wash", 2.0])
	var warn := effects_for("event_warning")
	check(warn.size() >= director.map.event_entries("wave_wash", "warning").size(), "warning entries played")
	var emote_found := false
	for e in warn:
		if e["type"] == "emote":
			emote_found = true
			check_eq(e["position"], Vector2(900, 200) + Vector2(0, -director.strengths.num("emote_height")),
					"emote over the marker")
	check(emote_found, "warning emote")
	director.clear_last_effects()
	emit("event_triggered", ["e_wave"])
	var types := types_for("event_triggered")
	check_has(types, "shake", "generic start shake")
	check_has(types, "splat", "wave_wash start splat from the remembered type")
	check_has(types, "popup", "wave_wash start popup")


func test_warning_without_marker_falls_back_to_castaway_head() -> void:
	make_director()
	director.clear_last_effects()
	emit("event_warning", ["e_x", "coconut_throw", 2.0])
	var head := castaway_stub.global_position + director.strengths.vec("popup_face_offset")
	var found := false
	for e in effects_for("event_warning"):
		if e["type"] == "emote":
			found = true
			check_eq(e["position"], head + Vector2(0, -director.strengths.num("emote_height")), "emote at head")
	check(found, "emote played")
