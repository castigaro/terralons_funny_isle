extends RefCounted
## One bot playthrough of a shipped level scene: (level_id, mode, seed, variant) -> summary entry.
## The bot reaches the game only through ActionInput (InputMap actions move, dash, interact and the finish event);
## it never sets an input source, moves an entity or calls the session. Variants: plain (3 stars), hold (worst-case
## schedule, the final unit is held back until every event has ended), inject (every task entity is thrown into the
## water once and must come back), finish_off (auto-finish off, the finish action ends the level), determinism.

const BotPlans := preload("res://tests/support/bot_plans.gd")
const BotPlanner := preload("res://tests/support/bot_planner.gd")
const LevelDriver := preload("res://tests/support/level_driver.gd")
const ActionInput := preload("res://tests/support/action_input.gd")

const TICKS_PER_SECOND := 60
## A run ends at the latest this long after the level timer (the session itself loses at timer 0).
const END_MARGIN_S := 5.0
## No task progress for this long (while not holding and no respawn pending) stops the run as stuck.
const STUCK_SECONDS := 45.0
## Extra time on top of throw flight and respawn delay before a missing respawn counts as an error.
const RESPAWN_MARGIN_S := 1.0
## A swimmer thrown into the water must be free and grabbable from a reachable cell within this time.
const SWIMMER_RETURN_SECONDS := 25.0
## finish_off: ticks the bot keeps the finish action back after every task is done.
const FINISH_HOLD_TICKS := 30
const SETTLE_PHYSICS_FRAMES := 2
## A respawn belongs to the thrown instance standing this close to the respawn position.
const RESPAWN_MATCH_PX := 1.0
## TFI_BOT_TRACE=1 prints throws, losses and respawns with their tick (debugging only).
const TRACE_ENV := "TFI_BOT_TRACE"

var level: LevelBase
var driver: RefCounted
var planner: RefCounted
var input: Node
var _session: LevelSession
var _won := false
var _triggered: Array = []
var _ended: Array = []
var _respawns := 0
var _pending: Array = []
var _inject_errors: Array = []
var _last_lost := {}
var _last_label := ""
var _tick := 0
var _connections: Array = []
var _trace := OS.get_environment(TRACE_ENV) != ""


## opts: level_id, mode ("seeded" | "earliest" | "latest"), seed, variant, hold, inject, auto_finish (default true),
## finish_hold (finish_off: keep finish back for FINISH_HOLD_TICKS), scene and plan (overrides for self tests),
## stuck_seconds and limit_seconds (overrides). Returns the summary entry.
func run(case: TestCase, opts: Dictionary) -> Dictionary:
	var started_msec := Time.get_ticks_msec()
	var level_id := String(opts.get("level_id", ""))
	var plan: Dictionary = opts.get("plan", BotPlans.plan(level_id))
	var mode := String(opts.get("mode", EventScheduler.MODE_SEEDED))
	var run_seed := int(opts.get("seed", 0))
	var variant := String(opts.get("variant", "plain"))
	var auto_finish := bool(opts.get("auto_finish", true))
	var overridden := false
	if not auto_finish:
		Balance.set_override("rules", "auto_finish_when_all_done", false)
		overridden = true
	var scene: PackedScene = load(String(opts.get("scene", plan.get("scene", ""))))
	level = scene.instantiate() as LevelBase
	level.session_options = {"seed_override": run_seed, "schedule_mode": mode}
	_connect_bus()
	case.add_node(level)
	await case.physics_frames(SETTLE_PHYSICS_FRAMES)
	_session = level.level_session()
	driver = LevelDriver.new(level, Callable())
	planner = BotPlanner.new(driver, plan, {"hold": bool(opts.get("hold", false)),
			"hold_style": String(opts.get("hold_style", plan.get("hold_style", BotPlanner.HOLD_STAGED))),
			"inject": bool(opts.get("inject", false))})
	driver.planner = planner.goal
	if _trace:
		planner.trace = _log
		driver.trace = _log
	input = ActionInput.new()
	input.source = driver.decide
	case.add_node(input)

	var timer_s := _session.time_left()
	var limit_ticks := int((float(opts.get("limit_seconds", timer_s + END_MARGIN_S))) * TICKS_PER_SECOND)
	var stuck_ticks := int(float(opts.get("stuck_seconds", STUCK_SECONDS)) * TICKS_PER_SECOND)
	var finish_hold := bool(opts.get("finish_hold", false))
	var finish_held_ticks := 0
	var finish_held_ok := true
	var reason := ""
	var signature := -1
	var still := 0
	while _tick < limit_ticks:
		var state := _session.get_state()
		if state == LevelSession.State.WON or state == LevelSession.State.LOST:
			break
		if finish_hold and state == LevelSession.State.REQUIRED_DONE and driver.open_tasks() == 0 \
				and finish_held_ticks < FINISH_HOLD_TICKS:
			driver.allow_finish = false
			finish_held_ticks += 1
		else:
			driver.allow_finish = true
		await case.physics_frames(1)
		_tick += 1
		if finish_held_ticks > 0 and finish_held_ticks <= FINISH_HOLD_TICKS and not driver.allow_finish \
				and _session.get_state() != LevelSession.State.REQUIRED_DONE:
			finish_held_ok = false
		_watch_injection()
		if _trace and planner.current_goal_label() != _last_label:
			_last_label = planner.current_goal_label()
			_log("goal %s pos %s verb %s facing %.0f" % [_last_label, str(level.castaway().global_position.round()),
					level.castaway().get_interact_verb(), rad_to_deg(level.castaway().get_facing())])
		if planner.missed_task() != "":
			reason = "stuck"
			break
		var sig := _progress_signature()
		if sig != signature:
			signature = sig
			still = 0
		elif planner.is_holding() or _respawn_pending():
			still = 0
		else:
			still += 1
			if still >= stuck_ticks:
				reason = "stuck"
				break
	var entry := _entry(level_id, variant, mode, run_seed, reason)
	entry["finish_presses"] = int(input.pressed_counts["finish"])
	entry["finish_held_ok"] = finish_held_ok and finish_held_ticks >= FINISH_HOLD_TICKS if finish_hold else true
	entry["wall_seconds"] = snappedf((Time.get_ticks_msec() - started_msec) / 1000.0, 0.01)
	await _teardown(case, overridden)
	return entry


func _connect_bus() -> void:
	_bind("event_triggered", func(id: String) -> void:
		if not _won:
			_triggered.append(id))
	_bind("event_ended", func(id: String) -> void:
		if not _won:
			_ended.append(id))
	_bind("level_won", func(_id: String, _stars: int) -> void: _won = true)
	_bind("object_thrown", _on_thrown)
	_bind("entity_lost", _on_lost)
	_bind("entity_respawned", _on_respawned)
	if _trace:
		_bind("object_landed", func(kind: String, pos: Vector2, surface: String) -> void:
			_log("landed %s at %s on %s" % [kind, str(pos.round()), surface]))


func _bind(signal_name: String, callable: Callable) -> void:
	EventBus.connect(signal_name, callable)
	_connections.append([signal_name, callable])


func _on_thrown(kind: String) -> void:
	if planner == null:
		return
	_log("thrown %s at %s facing %.0f" % [kind, str(level.castaway().global_position.round()),
			rad_to_deg(level.castaway().get_facing())])
	if _trace:
		for t in level.get_tree().get_nodes_in_group(UseTarget.GROUP) + level.get_tree().get_nodes_in_group(UseTarget.THROW_GROUP):
			if t is Node2D and (t as Node2D).global_position.distance_to(level.castaway().global_position) < 600.0:
				_log("  target %s at %s" % [str(level.get_path_to(t)), str((t as Node2D).global_position.round())])
	var before: int = planner.throws.size()
	planner.on_thrown(kind)
	if planner.throws.size() == before:
		return
	var t: Dictionary = planner.throws[-1]
	var seconds: float = SWIMMER_RETURN_SECONDS if t["swimmer"] else level.castaway().cfg.throw_flight_time \
			+ float(Balance.get_section("entities").get("respawn_delay", 0.0)) + RESPAWN_MARGIN_S
	_pending.append({"kind": kind, "id": t["id"], "swimmer": t["swimmer"],
			"deadline": _tick + int(ceil(seconds * TICKS_PER_SECOND))})


func _on_lost(kind: String, why: String) -> void:
	_log("lost %s %s" % [kind, why])
	_last_lost[kind] = why


## Matches the respawn to the thrown instance that now stands at pos and checks its reason and position.
func _on_respawned(kind: String, pos: Vector2) -> void:
	_log("respawned %s at %s" % [kind, str(pos.round())])
	_respawns += 1
	for i in _pending.size():
		var p: Dictionary = _pending[i]
		var e := instance_from_id(int(p["id"])) as Node2D
		if p["swimmer"] or p["kind"] != kind or e == null or e.global_position.distance_to(pos) > RESPAWN_MATCH_PX:
			continue
		if String(_last_lost.get(kind, "")) != "water":
			_inject_errors.append("%s lost with reason '%s' instead of water" % [kind, _last_lost.get(kind, "")])
		if not driver.is_reachable_pos(pos):
			_inject_errors.append("%s respawned at unreachable %s" % [kind, str(pos.round())])
		_pending.remove_at(i)
		return


func _watch_injection() -> void:
	var i := 0
	while i < _pending.size():
		var p: Dictionary = _pending[i]
		if p["swimmer"]:
			var e := instance_from_id(int(p["id"])) as Node2D
			if e != null and bool(e.call("is_free")) and driver.is_reachable_pos(e.global_position):
				_pending.remove_at(i)
				continue
		if _tick > int(p["deadline"]):
			_inject_errors.append("%s %s in time (%.1f s)" % [p["kind"],
					"not grabbable again" if p["swimmer"] else "not respawned", _tick / float(TICKS_PER_SECOND)])
			_pending.remove_at(i)
			continue
		i += 1


func _log(text: String) -> void:
	if _trace:
		print("BOT TRACE %.2f s %s" % [_tick / float(TICKS_PER_SECOND), text])


func _respawn_pending() -> bool:
	return not _pending.is_empty()


func _progress_signature() -> int:
	var sig := 0
	for entry in _session.task_progress():
		sig += int(entry["current"]) + (1000 if entry["done"] else 0)
	return sig


func _entry(level_id: String, variant: String, mode: String, run_seed: int, reason: String) -> Dictionary:
	var state := _session.get_state()
	var progress := _session.task_progress()
	var res := _session.result()
	var done := 0
	for e in progress:
		if e["done"]:
			done += 1
	var scheduled: Array = []
	for s in _session.schedule():
		scheduled.append(String(s["id"]))
	var held: Node2D = level.castaway().get_carried()
	var entry := {
		"level": level_id, "variant": variant, "mode": mode, "seed": run_seed,
		"state": _state_name(state), "tasks_done": done, "tasks_total": progress.size(),
		"done_ids": res["done_ids"], "time_left": snappedf(_session.time_left(), 0.001),
		"elapsed": snappedf(_session.elapsed(), 0.001), "three_star_time": snappedf(_session.three_star_time(), 0.001),
		"stars": int(res["stars"]), "events_triggered": _triggered.duplicate(), "events_ended": _ended.duplicate(),
		"scheduled_event_ids": scheduled, "respawns": _respawns, "throws": planner.throws.size(),
		"inject_errors": _inject_errors.duplicate(), "stuck_task": planner.stuck_task(),
		"goal": planner.current_goal_label(), "carried": String(held.get("kind")) if held != null else "",
	}
	if variant == "inject" and not planner.missing_spots.is_empty():
		var kinds: Array = planner.missing_spots.keys()
		kinds.sort()
		for kind in kinds:
			entry["inject_errors"].append("no throw spot for %s on %s" % [kind, level_id])
	var skipped: Array = planner.skipped_kinds.keys()
	skipped.sort()
	entry["inject_skipped"] = skipped
	if reason == "":
		reason = _verdict(entry, variant, state)
	entry["result"] = "pass" if reason == "" else "fail"
	entry["reason"] = reason
	return entry


static func _verdict(entry: Dictionary, variant: String, state: int) -> String:
	if state == LevelSession.State.LOST:
		return "lost"
	if state != LevelSession.State.WON:
		return "timeout"
	if entry["tasks_done"] != entry["tasks_total"]:
		return "not_all_done"
	if variant == "inject":
		return "inject" if not (entry["inject_errors"] as Array).is_empty() else ""
	if entry["stars"] != 3:
		return "not_3_stars"
	if variant == "hold":
		for id in entry["scheduled_event_ids"]:
			if not (entry["events_triggered"] as Array).has(id) or not (entry["events_ended"] as Array).has(id):
				return "events_not_ended"
	return ""


static func _state_name(state: int) -> String:
	return String(LevelSession.State.keys()[state]) if state >= 0 and state < LevelSession.State.size() else str(state)


## One line naming everything needed to reproduce a failed run.
static func format_failure(entry: Dictionary) -> String:
	var line := "BOT FAIL level=%s mode=%s seed=%s variant=%s reason=%s stuck_task=%s goal=%s carried=%s elapsed=%.1fs tasks=%d/%d time_left=%.1f" % [
			entry.get("level", ""), entry.get("mode", ""), str(entry.get("seed", "")), entry.get("variant", ""),
			entry.get("reason", ""), entry.get("stuck_task", ""), entry.get("goal", ""), entry.get("carried", ""),
			float(entry.get("elapsed", 0.0)), int(entry.get("tasks_done", 0)), int(entry.get("tasks_total", 0)),
			float(entry.get("time_left", 0.0))]
	var errors: Array = entry.get("inject_errors", [])
	if not errors.is_empty():
		line += " inject_errors=%s" % str(errors)
	return line


func _teardown(case: TestCase, overridden: bool) -> void:
	if input != null and is_instance_valid(input):
		input.source = Callable()
		input.release_all()
		input.queue_free()
	for c in _connections:
		if EventBus.is_connected(c[0], c[1]):
			EventBus.disconnect(c[0], c[1])
	_connections.clear()
	if level != null and is_instance_valid(level):
		level.queue_free()
	if overridden:
		Balance.clear_overrides()
	await case.frames(1)
