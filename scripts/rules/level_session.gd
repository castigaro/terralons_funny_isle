class_name LevelSession
extends RefCounted
## The only writer of level rules state: timer, event schedule, task progress, win, loss and stars.
## Scenes drive it with tick(delta, snapshot) and report_*(); it announces everything on the EventBus.
## Events only receive ids through the bus, so they can never end a level, change the timer or undo a task.

enum State { READY, RUNNING, PAUSED, REQUIRED_DONE, WON, LOST }

const TRIGGER := 0
const END := 1

var _def: LevelDef
var _bus: Object
var _run_seed := 0
var _mode := EventScheduler.MODE_SEEDED
var _share := 0.0
var _auto_finish := false
var _timer: LevelTimer
var _state := State.READY
var _prior := State.READY
var _elapsed := 0.0
var _tasks: Array = []
var _counters := {}
var _schedule: Array = []
var _timeline: Array = []
var _cursor := 0
var _fired := {}
var _ended := {}
var _flags := {}
var _stars := 0
var _kinds := {}
## Per task: [[condition, is deadline, is counting], ...] over conditions and modifiers.
var _compiled: Array = []
var _ctx := {}


## options: seed_override (int), schedule_mode (EventScheduler.MODE_*); rules is the balance section "rules".
func _init(def: LevelDef, bus: Object, rules: Dictionary, options: Dictionary = {}) -> void:
	_def = def
	_bus = bus
	_run_seed = int(options.get("seed_override", def.level_seed))
	_mode = str(options.get("schedule_mode", EventScheduler.MODE_SEEDED))
	_share = def.three_star_share if def.three_star_share > 0.0 else float(rules.get("three_star_time_share", 0.0))
	_auto_finish = bool(rules.get("auto_finish_when_all_done", false))
	_timer = LevelTimer.new(def.timer_seconds, float(rules.get("timer_warning_seconds", 0.0)))
	var all_conds: Array = []
	for task in def.tasks:
		var entries: Array = []
		for cond in task["conditions"] + task["modifiers"]:
			entries.append([cond, Conditions.is_deadline(cond), int(cond.get("count", 1)) > 1])
			all_conds.append(cond)
		_compiled.append(entries)
	_kinds = Conditions.relevant_kinds(all_conds)
	if _kinds.is_empty():
		_kinds = {"": true}
	_reset_state()


func _reset_state() -> void:
	_timer.reset()
	_state = State.READY
	_prior = State.READY
	_elapsed = 0.0
	_tasks.clear()
	for _i in _def.tasks.size():
		_tasks.append({"current": 0, "done": false, "missed": false})
	_counters = {}
	_schedule = EventScheduler.build(_def.events, _run_seed, _mode)
	_timeline.clear()
	for pos in _schedule.size():
		_timeline.append([_schedule[pos]["start"], TRIGGER, pos])
		_timeline.append([_schedule[pos]["end"], END, pos])
	_timeline.sort_custom(_point_before)
	_cursor = 0
	_fired = {}
	_ended = {}
	_ctx = {"elapsed": 0.0, "triggered_events": _fired}
	_flags = {"started": false, "required_done": false, "warned": false, "won": false, "lost": false}
	_stars = 0


static func _point_before(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] < b[0]
	if a[1] != b[1]:
		return a[1] < b[1]
	return a[2] < b[2]


# --- Flow ------------------------------------------------------------------------

## READY -> RUNNING; emits level_started once per attempt.
func start() -> void:
	if _state != State.READY:
		return
	_state = State.RUNNING
	if not _flags["started"]:
		_flags["started"] = true
		_emit("level_started", [_def.id])


## Stops the timer, events and task checks until resume().
func pause() -> void:
	if _state == State.RUNNING or _state == State.REQUIRED_DONE:
		_prior = _state
		_state = State.PAUSED


func resume() -> void:
	if _state == State.PAUSED:
		_state = _prior


## Ends the level as won after all required tasks are done (D-3); returns false without side effects otherwise.
func finish() -> bool:
	if _state != State.REQUIRED_DONE:
		return false
	_win()
	return true


## Back to the initial READY state with the same seed, schedule, timer and empty progress.
func restart() -> void:
	_reset_state()


## Advances the level by delta seconds of gameplay; order: timer, events, tasks, win and loss.
func tick(delta: float, snapshot: Dictionary) -> void:
	if _state != State.RUNNING and _state != State.REQUIRED_DONE:
		return
	var step := maxf(delta, 0.0)
	_elapsed += step
	var t := _timer.advance(step)
	if t["whole_changed"]:
		_emit("level_timer_tick", [_timer.remaining])
	if t["warn_now"] and not _flags["warned"]:
		_flags["warned"] = true
		_emit("timer_warning", [_def.id, _timer.remaining])
	_run_events()
	_evaluate_tasks(snapshot)
	_check_end(t["expired"])


## Counts one delivery of an entity kind to a target (cumulative, never decreases).
func report_delivery(entity: String, target: String) -> void:
	if _state != State.RUNNING and _state != State.REQUIRED_DONE:
		return
	var key := Conditions.counter_key_delivery(entity, target)
	_counters[key] = int(_counters.get(key, 0)) + 1


## Adds n to a named counter; n <= 0 is ignored, so totals never drop.
func report_count(counter: String, n: int = 1) -> void:
	if n <= 0 or (_state != State.RUNNING and _state != State.REQUIRED_DONE):
		return
	var key := Conditions.counter_key(counter)
	_counters[key] = int(_counters.get(key, 0)) + n


func _run_events() -> void:
	while _cursor < _timeline.size() and _timeline[_cursor][0] <= _elapsed:
		var point: Array = _timeline[_cursor]
		var entry: Dictionary = _schedule[point[2]]
		if point[1] == TRIGGER:
			_fired[entry["id"]] = true
			_emit("event_triggered", [entry["id"]])
		else:
			_ended[entry["id"]] = true
			_emit("event_ended", [entry["id"]])
		_cursor += 1


func _evaluate_tasks(snapshot: Dictionary) -> void:
	var idx: Dictionary = {}
	var indexed := false
	_ctx["elapsed"] = _elapsed
	for i in _tasks.size():
		var st: Dictionary = _tasks[i]
		if st["done"] or st["missed"]:
			continue
		if not indexed:
			idx = Conditions.index(snapshot, _kinds)
			indexed = true
		var all_ok := true
		var missed := false
		var counting := 0
		for entry: Array in _compiled[i]:
			var r := Conditions.evaluate(entry[0], idx, _counters, _ctx)
			if not r["ok"]:
				all_ok = false
				if entry[1]:
					missed = true
			if entry[2]:
				counting = r["current"]
		var td: Dictionary = _def.tasks[i]
		var target: int = td["target"]
		var done := all_ok and not missed
		st["missed"] = missed
		var current := target if done else clampi(counting, 0, target - 1)
		if current != st["current"]:
			st["current"] = current
			_emit("task_progress", [_def.id, td["id"], current, target])
		if done:
			st["done"] = true
			_emit("task_completed", [_def.id, td["id"]])


func _check_end(expired: bool) -> void:
	var required_done := _required_done()
	if required_done and _state == State.RUNNING:
		_state = State.REQUIRED_DONE
		if not _flags["required_done"]:
			_flags["required_done"] = true
			_emit("all_required_done", [_def.id])
	if _all_done() and _auto_finish:
		_win()
	elif expired:
		if _state == State.REQUIRED_DONE:
			_win()
		else:
			_lose()


func _win() -> void:
	_state = State.WON
	_stars = Stars.compute(true, _all_done(), _timer.remaining, _timer.total, _share)
	if not _flags["won"]:
		_flags["won"] = true
		_emit("level_won", [_def.id, _stars])


func _lose() -> void:
	_state = State.LOST
	_stars = 0
	if not _flags["lost"]:
		_flags["lost"] = true
		_emit("level_lost", [_def.id, _open_ids(true)])


func _emit(signal_name: String, args: Array) -> void:
	if _bus != null:
		_bus.callv("emit_signal", [signal_name] + args)


# --- Queries ------------------------------------------------------------------------

func _required_done() -> bool:
	for i in _tasks.size():
		if _def.tasks[i]["required"] and not _tasks[i]["done"]:
			return false
	return true


func _all_done() -> bool:
	for st in _tasks:
		if not st["done"]:
			return false
	return true


func _open_ids(required: bool) -> Array:
	var ids: Array = []
	for i in _tasks.size():
		if _def.tasks[i]["required"] == required and not _tasks[i]["done"]:
			ids.append(_def.tasks[i]["id"])
	return ids


func get_state() -> int:
	return _state


func level_id() -> String:
	return _def.id


func time_left() -> float:
	return _timer.remaining


func elapsed() -> float:
	return _elapsed


func three_star_time() -> float:
	return Stars.three_star_time(_timer.total, _share)


## Returns [{id, current, target, done, missed, required}] in data order.
func task_progress() -> Array:
	var out: Array = []
	for i in _tasks.size():
		var td: Dictionary = _def.tasks[i]
		var st: Dictionary = _tasks[i]
		out.append({"id": td["id"], "current": st["current"], "target": td["target"], "done": st["done"],
				"missed": st["missed"], "required": td["required"]})
	return out


## Returns {stars, time_left, done_ids, open_required_ids, open_optional_ids}.
func result() -> Dictionary:
	var done_ids: Array = []
	for i in _tasks.size():
		if _tasks[i]["done"]:
			done_ids.append(_def.tasks[i]["id"])
	var stars := _stars
	if _state != State.WON and _state != State.LOST:
		stars = Stars.compute(_required_done(), _all_done(), _timer.remaining, _timer.total, _share)
	return {"stars": stars, "time_left": _timer.remaining, "done_ids": done_ids,
			"open_required_ids": _open_ids(true), "open_optional_ids": _open_ids(false)}


## Returns a deep copy of the schedule [{id, type, params, index, start, end}].
func schedule() -> Array:
	return _schedule.duplicate(true)


## Returns the complete rules state (for tests and the restart check).
func state_dict() -> Dictionary:
	var fired := _fired.keys()
	fired.sort()
	var ended := _ended.keys()
	ended.sort()
	return {
		"state": _state,
		"prior_state": _prior,
		"elapsed": _elapsed,
		"remaining": _timer.remaining,
		"timer_warned": _timer.warned,
		"tasks": task_progress(),
		"counters": _counters.duplicate(true),
		"schedule": schedule(),
		"cursor": _cursor,
		"fired": fired,
		"ended": ended,
		"flags": _flags.duplicate(true),
		"stars": _stars,
	}
