extends TestCase
## Per-sound cooldown and voice limit from data/balance/audio.json: storms of steps and bonks never exceed the limit.

const STORM := 30
const FRAME := 1.0 / 60.0


func _audio() -> Node:
	return root().get_node("Audio")


func _balance() -> Node:
	return root().get_node("Balance")


func before_each() -> void:
	_audio().set("manual_clock", true)


func _tuning() -> AudioTuning:
	return AudioTuning.from_section(_balance().call("get_section", "audio"))


func test_tuning_reads_balance() -> void:
	var t := _tuning()
	check_eq(t.errors, [], "tuning errors")
	check_eq(t.voice_limit("step"), 2, "step limit")
	check_eq(t.voice_limit("bonk"), 3, "bonk limit")
	check(absf(t.cooldown("step") - 0.12) < 0.0001, "step cooldown")
	check_eq(t.voice_limit("grab"), t.default_voice_limit, "default limit")
	check(absf(t.cooldown("grab") - t.default_cooldown) < 0.0001, "default cooldown")


func test_tuning_reports_bad_values() -> void:
	var t := AudioTuning.from_section({"default_voice_limit": 0, "per_sound": {"x": {"voice_limit": 0,
			"cooldown_seconds": -1}}})
	var errs := str(t.errors)
	check(errs.contains("default_voice_limit must be >= 1"), errs)
	check(errs.contains("per_sound.x.voice_limit"), errs)
	check(errs.contains("per_sound.x.cooldown_seconds"), errs)
	check(errs.contains("silent_db missing"), errs)
	check_eq(t.voice_limit("x"), 1, "limit clamped")


func test_pure_throttle_storm() -> void:
	var t := _tuning()
	for sound in ["step", "bonk"]:
		var th := SfxThrottle.new(t)
		var max_active := 0
		var played := 0
		for i in STORM:
			var now := float(i) / float(STORM)
			if th.can_play(sound, now):
				th.on_play(sound, now, 2.0)
				played += 1
			max_active = maxi(max_active, th.active(sound, now))
		check(max_active <= t.voice_limit(sound), "%s max %d" % [sound, max_active])
		check_eq(played, t.voice_limit(sound), "%s plays up to the limit" % sound)


func test_cooldown_drops_without_queueing() -> void:
	var t := _tuning()
	var th := SfxThrottle.new(t)
	check_true(th.can_play("step", 0.0), "first")
	th.on_play("step", 0.0, 0.01)
	check_false(th.can_play("step", t.cooldown("step") / 2.0), "inside cooldown")
	check_eq(th.active("step", 1.0), 0, "dropped request never plays later")
	check_true(th.can_play("step", t.cooldown("step")), "after cooldown")


func test_audio_storm_via_signals() -> void:
	var audio := _audio()
	var bus := root().get_node("EventBus")
	var t := _tuning()
	var max_step := 0
	var max_bonk := 0
	for i in STORM:
		bus.castaway_step.emit(Vector2.ZERO, "sand")
		bus.object_bonked.emit("coconut", "throw")
		audio.call("handle_signal", "castaway_step", [Vector2.ZERO, "grass"])
		max_step = maxi(max_step, audio.call("active_voices", "step"))
		max_bonk = maxi(max_bonk, audio.call("active_voices", "bonk"))
		audio.call("advance", 1.0 / float(STORM))
	check(max_step <= t.voice_limit("step"), "steps %d" % max_step)
	check(max_bonk <= t.voice_limit("bonk"), "bonks %d" % max_bonk)
	check(max_step >= 1 and max_bonk >= 1, "sounds played")
	var playing := 0
	for player in audio.call("sfx_players", "step"):
		playing += 1
	check_eq(playing, t.voice_limit("step"), "pool size equals the limit")
	check_eq(audio.call("last_errors"), [], "no errors")


func test_balance_override_is_observed() -> void:
	var audio := _audio()
	var per: Dictionary = _balance().call("get_value", "audio", "per_sound", {}).duplicate(true)
	per["step"] = {"cooldown_seconds": 0.0, "voice_limit": 1}
	_balance().call("set_override", "audio", "per_sound", per)
	audio.call("reload_tuning")
	var played := 0
	for i in STORM:
		if audio.call("play_sfx", "step"):
			played += 1
		check(audio.call("active_voices", "step") <= 1, "limit 1")
	check_eq(played, 1, "only one voice")
	check_eq(audio.call("sfx_players", "step").size(), 1, "pool of one")


func test_sfx_request_log_counts_dropped_requests_is_capped_and_cleared() -> void:
	var audio := _audio()
	var bus := root().get_node("EventBus")
	bus.level_started.emit("l1_beach_camp")
	check_eq(audio.call("sfx_requests"), [], "cleared on level_started")
	var played := 0
	for i in 5:
		if audio.call("play_sfx", "step"):
			played += 1
	check(played < 5, "the throttle drops some of the burst (%d played)" % played)
	check_eq(audio.call("sfx_requests"), ["step", "step", "step", "step", "step"], "every request logged")
	var cap: int = audio.get_script().get_script_constant_map()["SFX_REQUEST_LOG"]
	for i in cap + 10:
		audio.call("play_sfx", "bonk")
	var entries: Array = audio.call("sfx_requests")
	check_eq(entries.size(), cap, "log capped at %d" % cap)
	check_false(entries.has("step"), "oldest requests dropped first")
	entries.clear()
	check_eq(audio.call("sfx_requests").size(), cap, "getter returns a copy")
	bus.level_started.emit("l1_beach_camp")
	check_eq(audio.call("sfx_requests"), [], "cleared again on the next level_started")
	audio.call("reset_for_tests")
