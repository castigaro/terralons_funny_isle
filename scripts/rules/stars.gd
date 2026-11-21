class_name Stars
extends RefCounted
## Pure star rating (D-4): 1 = required tasks, 2 = all tasks, 3 = all tasks with the time share left.

const MAX_STARS := 3  # balance-exempt: the rating scale itself, not a tuning value
const EPSILON := 0.000001  # balance-exempt: float tolerance, not a tuning value


## Returns 0..3 stars.
static func compute(required_done: bool, all_done: bool, time_left: float, time_total: float, share: float) -> int:
	if not required_done:
		return 0
	if not all_done:
		return 1
	if time_left + EPSILON >= three_star_time(time_total, share):
		return MAX_STARS
	return MAX_STARS - 1


## Seconds that must be left on the timer for 3 stars.
static func three_star_time(time_total: float, share: float) -> float:
	return time_total * share
