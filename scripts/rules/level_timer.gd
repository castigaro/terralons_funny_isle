class_name LevelTimer
extends RefCounted
## Level countdown that only moves when advanced; it never reads the clock.

var total := 0.0
var remaining := 0.0
var warning_seconds := 0.0
var warned := false
var last_whole := 0


func _init(total_seconds: float, warn_at: float) -> void:
	total = total_seconds
	warning_seconds = warn_at
	reset()


## Restores the full time and re-arms the warning.
func reset() -> void:
	remaining = total
	warned = false
	last_whole = ceili(remaining)


## Counts down by delta: returns {whole_changed, warn_now, expired}; warn_now is true exactly once per run.
func advance(delta: float) -> Dictionary:
	if delta > 0.0:
		remaining = maxf(0.0, remaining - delta)
	var whole := ceili(remaining)
	var whole_changed := whole != last_whole
	last_whole = whole
	var warn_now := false
	if not warned and remaining <= warning_seconds and delta > 0.0:
		warned = true
		warn_now = true
	return {"whole_changed": whole_changed, "warn_now": warn_now, "expired": remaining <= 0.0}
