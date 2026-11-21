extends "res://tests/support/feedback_case.gd"
## Hit-stop in the scene tree (--fixed-fps 60, frame clock): Engine.time_scale drops on a bonk and is always
## restored – after the timer, after bonk storms, on pause, on reset_all (level_started), on free and by the
## safety check when the timer is lost.


func _bonk() -> void:
	emit("object_bonked", ["castaway", "coconut"])


func _frames_until_restored(limit: int) -> int:
	var n := 0
	while Engine.time_scale < 1.0 and n < limit:
		await frames(1)
		n += 1
	return n


func _max_frames(ms: float) -> int:
	return int(ceil(ms / FRAME_MS)) + 1


func test_bonk_freezes_and_restores() -> void:
	make_director()
	var ms := director.effective_hitstop_ms("bonk")
	check(ms > 0.0 and ms <= 80.0, "bonk hit-stop %.0f ms" % ms)
	_bonk()
	check(director.hitstop_active(), "active")
	check_eq(Engine.time_scale, director.strengths.num("hitstop_time_scale"), "time scale lowered")
	await frames(1)
	check(Engine.time_scale < 1.0, "not ended in the first frame")
	var n: int = await _frames_until_restored(60)
	check(n + 1 <= _max_frames(ms), "restored after %d frames (max %d)" % [n + 1, _max_frames(ms)])
	check_eq(Engine.time_scale, 1.0, "restored")
	check_false(director.hitstop_active(), "inactive")


func test_twenty_bonks_in_one_frame() -> void:
	make_director()
	for i in 20:
		_bonk()
	check_eq(director.hitstop_state()["accepted_count"], 20, "all accepted inside one freeze")
	var n: int = await _frames_until_restored(60)
	check(n <= _max_frames(director.strengths.num("hitstop_max_ms")), "restored after %d frames" % n)
	check_eq(Engine.time_scale, 1.0, "restored")


func test_twenty_bonks_spread_over_a_second() -> void:
	make_director()
	var last_accepted_frame := -1
	var limit := _max_frames(director.strengths.num("hitstop_max_ms"))
	for f in 90:
		if f < 60 and f % 3 == 0:
			var before: int = director.hitstop_state()["accepted_count"]
			_bonk()
			if director.hitstop_state()["accepted_count"] > before:
				last_accepted_frame = f
		if Engine.time_scale < 1.0:
			check(f - last_accepted_frame <= limit, "frame %d still frozen, last request at %d" % [f,
					last_accepted_frame])
		await frames(1)
	check_eq(Engine.time_scale, 1.0, "restored")
	var state := director.hitstop_state()
	check(state["accepted_count"] < 20, "the cooldown dropped some of the 20 bonks")
	check(state["frozen_ms_total"] <= 1000.0 * 0.5, "frozen %.0f ms of 1 s" % state["frozen_ms_total"])


func test_pause_restores_and_blocks() -> void:
	make_director()
	_bonk()
	check(Engine.time_scale < 1.0, "frozen")
	tree().paused = true
	await frames(1)
	check_eq(Engine.time_scale, 1.0, "pause restores")
	await frames(30)
	_bonk()
	check_eq(Engine.time_scale, 1.0, "no hit-stop while paused")
	check_false(director.hitstop_active(), "inactive while paused")
	tree().paused = false


func test_level_started_restores() -> void:
	make_director()
	_bonk()
	check(Engine.time_scale < 1.0, "frozen")
	emit("level_started", ["lvl"])
	check_eq(Engine.time_scale, 1.0, "reset_all restores")
	check_eq(director.active_count("popup"), 1, "only the GO popup after the reset")


func test_free_restores() -> void:
	make_director()
	_bonk()
	check(Engine.time_scale < 1.0, "frozen")
	director.queue_free()
	await frames(1)
	check_eq(Engine.time_scale, 1.0, "freeing the director restores")


func test_lost_timer_recovered_by_safety_check() -> void:
	make_director()
	_bonk()
	director.hit_stop.generation += 1
	var n: int = await _frames_until_restored(60)
	var limit := _max_frames(director.effective_hitstop_ms("bonk") + director.strengths.num("hitstop_safety_grace_ms"))
	check(n <= limit + 1, "safety restored after %d frames (limit %d)" % [n, limit])
	check_eq(Engine.time_scale, 1.0, "restored")


func test_cooldown_blocks_immediate_repeat() -> void:
	make_director()
	_bonk()
	await _frames_until_restored(60)
	_bonk()
	check_eq(Engine.time_scale, 1.0, "inside the cooldown: no new freeze")
	await frames(int(ceil(director.strengths.num("hitstop_cooldown_ms") / FRAME_MS)) + 1)
	_bonk()
	check(Engine.time_scale < 1.0, "after the cooldown a new freeze starts")
	await _frames_until_restored(60)
