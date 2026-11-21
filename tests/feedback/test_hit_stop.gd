extends TestCase
## HitStop state machine with a fake clock: clamping, paused rejection, max-not-sum, generations, cooldown,
## safety restore and a bounded frozen total under a bonk storm.

const MAX_MS := 80.0
const COOLDOWN_MS := 250.0
const GRACE_MS := 34.0


func _hs() -> HitStop:
	return HitStop.new(MAX_MS, COOLDOWN_MS, GRACE_MS)


func test_duration_clamped() -> void:
	var hs := _hs()
	var r := hs.request(1000.0, 500.0, false)
	check(r["accepted"] and r["started"], "accepted")
	check_eq(r["end_ms"], 1080.0, "clamped to 80 ms")


func test_paused_and_zero_rejected() -> void:
	var hs := _hs()
	check_false(hs.request(0.0, 50.0, true)["accepted"], "paused")
	check_false(hs.request(0.0, 0.0, false)["accepted"], "zero ms")
	check_false(hs.active, "inactive")
	check_eq(hs.rejected_count, 2, "counted")


func test_overlap_extends_to_max_not_sum() -> void:
	var hs := _hs()
	hs.request(0.0, 50.0, false)
	var r := hs.request(20.0, 50.0, false)
	check(r["accepted"], "overlap accepted")
	check_eq(hs.end_ms, 70.0, "later end wins (max), not 100 (sum)")
	check(r["rearm"], "end moved: re-arm")
	var r2 := hs.request(30.0, 10.0, false)
	check_false(r2["rearm"], "earlier end does not re-arm")
	check_eq(hs.end_ms, 70.0, "end kept")
	hs.request(60.0, 80.0, false)
	check_eq(hs.end_ms, 80.0, "one freeze never exceeds max_ms from its start")


func test_only_latest_generation_restores() -> void:
	var hs := _hs()
	var first: int = hs.request(0.0, 40.0, false)["generation"]
	var second: int = hs.request(10.0, 60.0, false)["generation"]
	check_ne(first, second, "new generation on extension")
	check_false(hs.timer_fired(first), "stale timer ignored")
	check(hs.timer_fired(second), "current timer restores")
	check(hs.restore(70.0), "restored")
	check_false(hs.timer_fired(second), "no restore after restore")


func test_cooldown_drops_requests() -> void:
	var hs := _hs()
	hs.request(0.0, 50.0, false)
	hs.restore(50.0)
	check_false(hs.request(100.0, 50.0, false)["accepted"], "inside cooldown")
	check_false(hs.request(299.0, 50.0, false)["accepted"], "still inside")
	check(hs.request(300.0, 50.0, false)["accepted"], "after cooldown")


func test_safety_check_after_lost_timer() -> void:
	var hs := _hs()
	hs.request(0.0, 50.0, false)
	check_false(hs.check(60.0), "within grace")
	check(hs.check(50.0 + GRACE_MS), "past end plus grace")
	hs.restore(84.0)
	check_false(hs.active, "restored")
	check_false(hs.check(1000.0), "nothing to restore")


func test_bonk_storm_frozen_total_bounded() -> void:
	var hs := _hs()
	var windows := 0
	for i in 20:
		var now := i * 50.0
		if hs.active and now >= hs.end_ms:
			hs.restore(hs.end_ms)
		var r := hs.request(now, 70.0, false)
		if r["started"]:
			windows += 1
	if hs.active:
		hs.restore(hs.end_ms)
	check(windows >= 1 and windows <= 4, "freeze windows in 1 s: %d" % windows)
	check(hs.frozen_ms_total <= windows * MAX_MS, "frozen %.1f ms over %d windows" % [hs.frozen_ms_total, windows])
	check(hs.frozen_ms_total <= 1000.0 * MAX_MS / (MAX_MS + COOLDOWN_MS) + MAX_MS, "most of the second unfrozen")
