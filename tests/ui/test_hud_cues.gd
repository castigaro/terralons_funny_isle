extends "res://tests/support/level_case.gd"
## Failure cues: every failure type reacts to its real EventBus signal with its translated cue for cue_seconds;
## "event stole something" is resolved through the level's event schedule; time's up wins over a visible cue; a
## task fail_key replaces the generic text; the HUD spawns no effect nodes of its own.

const STEAL_LEVEL := "res://tests/fixtures/levels/valid_steal_events.json"


func _cue_text(hud: Hud) -> String:
	return (hud.panel("CueLabel") as Label).text


func test_each_failure_type_shows_its_cue() -> void:
	await open_level()
	var hud := level.hud()
	check_eq(hud.current_cue_key(), "", "no cue at start")
	var cases := [
		["entity_lost", ["pig", "fled"], "hud.cue.animal_escaped"],
		["entity_lost", ["bucket", "water"], "hud.cue.item_lost_sea"],
		["castaway_dizzy_started", ["coconut"], "hud.cue.dizzy_hit"],
	]
	for c in cases:
		EventBus.emit_signal.callv([StringName(c[0])] + c[1])
		await frames(1)
		check_eq(hud.current_cue_key(), c[2], "%s %s" % [c[0], str(c[1])])
		check(hud.panel("CueSlot").visible, "cue panel visible for %s" % c[2])
		check_eq(_cue_text(hud), I18n.t(c[2]), "translated text %s" % c[2])
		check((hud.panel("CueIcon") as TextureRect).texture != null, "icon for %s" % c[2])
	var timer: LevelTimer = level.level_session().get("_timer")
	timer.remaining = 0.01
	await physics_frames(2)
	await frames(1)
	check_eq(level.level_session().get_state(), LevelSession.State.LOST, "lost")
	check_eq(hud.current_cue_key(), "hud.cue.time_up", "time's up replaces the visible cue")
	EventBus.castaway_dizzy_started.emit("coconut")
	await frames(1)
	check_eq(hud.current_cue_key(), "hud.cue.time_up", "time's up is not replaced")


func test_cue_hides_after_cue_seconds() -> void:
	await open_level()
	var hud := level.hud()
	EventBus.castaway_dizzy_started.emit("coconut")
	await frames(1)
	check_eq(hud.current_cue_key(), "hud.cue.dizzy_hit", "shown")
	var seconds := float(Balance.get_value("hud", "cue_seconds"))
	await frames(int(seconds * 60.0) - 20)
	check_eq(hud.current_cue_key(), "hud.cue.dizzy_hit", "still visible before cue_seconds")
	await frames(40)
	check_eq(hud.current_cue_key(), "", "hidden after cue_seconds")
	check_false(hud.panel("CueSlot").visible, "panel hidden")


func test_item_lost_only_for_sea_and_bounds() -> void:
	await open_level()
	var hud := level.hud()
	EventBus.entity_lost.emit("bucket", "stuck")
	await frames(1)
	check_eq(hud.current_cue_key(), "", "stuck items give no sea cue")
	EventBus.entity_lost.emit("bucket", "bounds")
	await frames(1)
	check_eq(hud.current_cue_key(), "hud.cue.item_lost_sea", "out of bounds counts as the sea")


func test_task_fail_key_overrides_generic_text() -> void:
	await open_level()
	var hud := level.hud()
	EventBus.entity_lost.emit("chicken", "fled")
	await frames(1)
	check_eq(hud.current_cue_key(), "fixture.chicken_a_fail", "open task about the chicken names it")
	check_eq(_cue_text(hud), level.text("fixture.chicken_a_fail"), "level text")


func test_non_stealing_event_shows_nothing() -> void:
	await open_level()
	var hud := level.hud()
	EventBus.event_triggered.emit("fx_ev_rain")
	await frames(1)
	check_eq(hud.current_cue_key(), "", "rain steals nothing")


func test_stealing_event_needs_something_held() -> void:
	await open_level(SAMPLE_LEVEL, {"level_json_path": STEAL_LEVEL})
	var hud := level.hud()
	check_false(level.is_failed(), "steal fixture loads")
	EventBus.event_triggered.emit("fx_ev_coconuts")
	await frames(1)
	check_eq(hud.current_cue_key(), "", "nothing held, nothing stolen")
	var coconut := level.get_node("Actors/Coconut1") as Node2D
	await place_castaway(coconut.global_position + Vector2(-50, 0), 0.0)
	press_interact()
	await physics_frames(2)
	check(castaway.get_carried() == coconut, "holding the coconut")
	EventBus.event_triggered.emit("fx_ev_parrot")
	await frames(1)
	check_eq(hud.current_cue_key(), "", "the hat thief needs a worn hat")
	EventBus.event_triggered.emit("fx_ev_coconuts")
	await frames(1)
	check_eq(hud.current_cue_key(), "hud.cue.event_stole", "take_held event steals the held coconut")


func test_hud_spawns_no_effect_nodes() -> void:
	await open_level()
	var hud := level.hud()
	var before := hud.get_child_count()
	var count := _count(hud)
	EventBus.castaway_dizzy_started.emit("coconut")
	EventBus.entity_lost.emit("pig", "fled")
	await frames(2)
	check_eq(hud.get_child_count(), before, "no new HUD children")
	check_eq(_count(hud), count, "no nodes created for cues")


func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total
