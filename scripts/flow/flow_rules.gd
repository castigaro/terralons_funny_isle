class_name FlowRules
extends RefCounted
## Pure decisions of the game flow: screens, where Next and Back lead, input guards and time formatting.

enum Screen { NONE, TITLE, LEVEL_SELECT, SETTINGS, CREDITS, INTRO, PLAYING, PAUSE, RESULT }

const TARGET_LEVEL := "level"
const TARGET_CREDITS := "credits"
const TARGET_RETRY := "retry"
const SECONDS_PER_MINUTE := 60  # balance-exempt: unit conversion


## Where Next leads after a result: {target: level|credits|retry, level_id}. A win of the last level leads to the
## credits, a win to the next level; a loss leads to the next level only when it is already unlocked.
static func next_after_result(campaign: Campaign, progress: ProgressModel, level_id: String, won: bool) -> Dictionary:
	var next := campaign.next_id(level_id)
	if won and next == "":
		return {"target": TARGET_CREDITS, "level_id": ""}
	if next != "" and progress.is_unlocked(next) and bool(campaign.entry(next).get("available", false)):
		return {"target": TARGET_LEVEL, "level_id": next}
	return {"target": TARGET_RETRY, "level_id": level_id}


## Screen that Back (Esc) returns to; NONE when Back does nothing (title, intro, playing).
static func back_target(screen: int, came_from: int) -> int:
	match screen:
		Screen.LEVEL_SELECT, Screen.CREDITS:
			return came_from if came_from != Screen.NONE else Screen.TITLE
		Screen.SETTINGS:
			return Screen.PAUSE if came_from == Screen.PAUSE else Screen.TITLE
		Screen.PAUSE:
			return Screen.PLAYING
		Screen.RESULT:
			return Screen.LEVEL_SELECT
	return Screen.NONE


static func accepts_input(elapsed_s: float, guard_s: float) -> bool:
	return elapsed_s >= guard_s


## Seconds the player needed to win: timer length minus the time left.
static func completion_time(timer_seconds: float, time_left: float) -> float:
	return maxf(timer_seconds - time_left, 0.0)


## "m:ss"; round_up shows a countdown value (time left), otherwise whole seconds are cut (completion times).
static func format_time(seconds: float, round_up: bool = false) -> String:
	var s := maxf(seconds, 0.0)
	var whole := int(ceilf(s)) if round_up else int(floorf(s))
	@warning_ignore("integer_division")
	var minutes := whole / SECONDS_PER_MINUTE
	return "%d:%02d" % [minutes, whole % SECONDS_PER_MINUTE]
