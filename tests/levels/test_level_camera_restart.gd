## run-fps: 60,144
extends "res://tests/support/level_case.gd"
## Restart snaps camera and castaway back to the spawn in one frame (no camera sweep) and restarts the session.

var _rendered: Array = []


func _on_frame() -> void:
	var vp := level.get_viewport()
	_rendered.append(vp.get_canvas_transform().affine_inverse() * (vp.get_visible_rect().size / 2.0))


func test_restart_snaps_without_sweep() -> void:
	await open_level()
	var cam := level.camera()
	await place_castaway(Vector2(2500, 1300))
	move = Vector2.LEFT
	await physics_frames(30)
	move = Vector2.ZERO
	await frames(2)
	var target := cam.clamp_to_bounds(level.spawn_position())
	var before := cam.global_position
	check(before.distance_to(target) > 300.0, "camera far from the spawn before the restart")
	recorder.clear()
	tree().process_frame.connect(_on_frame)
	level.restart_level()
	check_eq(cam.global_position, target, "camera snapped in the restart call")
	check(castaway.global_position.distance_to(level.spawn_position()) < 0.01, "castaway at the spawn")
	check_eq(castaway.velocity, Vector2.ZERO, "castaway stopped")
	check_eq(level.level_session().elapsed(), 0.0, "timer reset")
	check_eq(level.level_session().get_state(), LevelSession.State.RUNNING, "running")
	await frames(12)
	tree().process_frame.disconnect(_on_frame)
	var arrived := -1
	var between := 0
	for i in _rendered.size():
		var p: Vector2 = _rendered[i]
		if p.distance_to(target) < 0.5:
			if arrived < 0:
				arrived = i
		elif arrived >= 0:
			between += 1
		elif p.distance_to(before) > 60.0:
			between += 1
	check(arrived >= 0 and arrived <= 1, "rendered camera at the spawn within one frame (frame %d)" % arrived)
	check_eq(between, 0, "rendered frames between the old position and the spawn")
	check_eq(events("level_restarted").size(), 1, "EventBus.level_restarted once")
	check_eq(level.level_session().get_state(), LevelSession.State.RUNNING, "still running")
	var cue := level.get_node("Overlay/LevelCue")
	check_eq(cue.call("current_key"), "level.restarted", "restart cue")
	check_eq(cue.call("label_text"), I18n.t("level.restarted"), "cue text")


func test_restarted_signal_and_entity_reset() -> void:
	await open_level()
	var got: Array = []
	level.restarted.connect(func(id: String) -> void: got.append(id))
	var coconut := level.get_node("Actors/Coconut1") as Node2D
	coconut.global_position += Vector2(300, 0)
	level.restart_level()
	check_eq(got, ["valid_sample_level"], "restarted once")
	check_eq(coconut.global_position, level.home_point("coconut_1"), "entity back home")
	check_eq(coconut.get("reset_calls"), 1, "reset_to_home called")


func test_restart_key_restarts() -> void:
	await open_level()
	await physics_frames(30)
	var ev := InputEventAction.new()
	ev.action = "restart"
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(2)
	check(level.level_session().elapsed() < 0.1, "elapsed reset by the restart key")
	check_eq(events("level_restarted").size(), 1, "restarted by key")
