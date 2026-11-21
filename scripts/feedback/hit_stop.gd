class_name HitStop
extends RefCounted
## Pure hit-stop state machine with an injected clock (milliseconds). It never touches Engine.time_scale itself:
## the FeedbackDirector applies and restores the freeze. Overlapping requests extend the freeze to the later end
## (max, not sum), one freeze never lasts longer than max_ms, requests while paused, during the cooldown after a
## freeze or with a non-positive duration are dropped.

var max_ms := 0.0
var cooldown_ms := 0.0
var grace_ms := 0.0
var active := false
var start_ms := 0.0
var end_ms := 0.0
var generation := 0
var cooldown_until_ms := -INF
var accepted_count := 0
var rejected_count := 0
var frozen_ms_total := 0.0


func _init(max_duration_ms: float, cooldown_duration_ms: float, safety_grace_ms: float) -> void:
	max_ms = maxf(0.0, max_duration_ms)
	cooldown_ms = maxf(0.0, cooldown_duration_ms)
	grace_ms = maxf(0.0, safety_grace_ms)


## Asks for a freeze of duration_ms at now_ms; returns {accepted, started, rearm, end_ms, generation}.
## rearm is true when the end moved later, so the caller must arm a new timer for the given generation.
func request(now_ms: float, duration_ms: float, paused: bool) -> Dictionary:
	var ms := minf(duration_ms, max_ms)
	var refused := paused or ms <= 0.0 or (not active and now_ms < cooldown_until_ms)
	if refused:
		rejected_count += 1
		return {"accepted": false, "started": false, "rearm": false, "end_ms": end_ms, "generation": generation}
	var started := not active
	var rearm := false
	if started:
		active = true
		start_ms = now_ms
		end_ms = now_ms + ms
		generation += 1
		rearm = true
	else:
		var wanted := minf(now_ms + ms, start_ms + max_ms)
		if wanted > end_ms:
			end_ms = wanted
			generation += 1
			rearm = true
	accepted_count += 1
	return {"accepted": true, "started": started, "rearm": rearm, "end_ms": end_ms, "generation": generation}


## True when the timer armed for gen may end the freeze (only the latest generation may).
func timer_fired(gen: int) -> bool:
	return active and gen == generation


## Safety net: true when an active freeze is past its end plus the grace (for example a lost timer).
func check(now_ms: float) -> bool:
	return active and now_ms >= end_ms + grace_ms


## Ends the freeze at now_ms and starts the cooldown; returns false when nothing was active.
func restore(now_ms: float) -> bool:
	if not active:
		return false
	active = false
	frozen_ms_total += maxf(0.0, minf(now_ms, end_ms) - start_ms)
	cooldown_until_ms = now_ms + cooldown_ms
	generation += 1
	return true


## Remaining freeze time in milliseconds at now_ms (0 when inactive).
func remaining_ms(now_ms: float) -> float:
	return maxf(0.0, end_ms - now_ms) if active else 0.0


## Clears the cooldown and the counters (level restart).
func reset() -> void:
	active = false
	cooldown_until_ms = -INF
	generation += 1


func state() -> Dictionary:
	return {"active": active, "generation": generation, "end_ms": end_ms, "cooldown_until_ms": cooldown_until_ms,
			"accepted_count": accepted_count, "rejected_count": rejected_count, "frozen_ms_total": frozen_ms_total}
