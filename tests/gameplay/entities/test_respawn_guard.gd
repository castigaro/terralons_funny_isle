extends TestCase
## RespawnGuard (pure): commits after respawn_delay of continuous unreachability, resets otherwise.

const DT := 1.0 / 60.0


func _ticks(g: RespawnGuard, n: int, reason: String, free: bool = true, protected: bool = false) -> int:
	for i in n:
		if g.tick(DT, reason, free, protected)["commit"]:
			return i + 1
	return -1


func test_commits_after_delay() -> void:
	var delay := EntityConfig.from_balance().respawn_delay
	check_eq(delay, 2.0, "default respawn delay")
	var g := RespawnGuard.new(delay)
	var at := _ticks(g, 200, "water")
	check(absi(at - int(round(delay / DT))) <= 1, "commit at %d ticks" % at)


func test_reason_is_passed_through() -> void:
	var g := RespawnGuard.new(0.1)
	var out := {}
	for i in 10:
		out = g.tick(DT, "bounds", true, false)
		if out["commit"]:
			break
	check(out["commit"], "committed")
	check_eq(out["reason"], "bounds", "reason")


func test_reachable_resets() -> void:
	var g := RespawnGuard.new(1.0)
	_ticks(g, 50, "stuck")
	g.tick(DT, "", true, false)
	check_false(g.is_pending(), "reset")
	check_eq(_ticks(g, 50, "stuck"), -1, "timer restarted")


func test_not_free_or_protected_never_commits() -> void:
	var g := RespawnGuard.new(0.5)
	check_eq(_ticks(g, 120, "water", false, false), -1, "carried or flying")
	check_eq(_ticks(g, 120, "water", true, true), -1, "protected")
