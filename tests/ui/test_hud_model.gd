extends TestCase
## HudModel: time format, warning and star-goal rules, hint selection, failure cue classification, throttle and
## the data/hud.json loader.

const S := LevelSession.State

var _tasks: Array = [
	{"id": "t_req_a", "required": true, "hint_key": "h.req_a", "fail_key": "f.req_a",
			"conditions": [{"type": "in_zone", "entity": "chicken", "zone": "coop", "count": 2}], "modifiers": []},
	{"id": "t_req_b", "required": true, "hint_key": "h.req_b", "fail_key": "f.req_b",
			"conditions": [{"type": "held", "entity": "pig"}], "modifiers": []},
	{"id": "t_opt_c", "required": false, "hint_key": "h.opt_c", "fail_key": "f.opt_c",
			"conditions": [{"type": "worn", "item": "hat", "wearer": "goat"}], "modifiers": []},
	{"id": "t_opt_d", "required": false, "hint_key": "h.opt_d", "fail_key": "f.opt_d",
			"conditions": [{"type": "delivered_to", "entity": "coconut", "target": "monkey"}], "modifiers": []},
]


func _progress(done: Array = [], missed: Array = []) -> Array:
	var out: Array = []
	for task in _tasks:
		out.append({"id": task["id"], "current": 0, "target": 1, "done": done.has(task["id"]),
				"missed": missed.has(task["id"]), "required": task["required"]})
	return out


func _model() -> HudModel:
	var cfg := Hud.config()
	var effects := {"ev_parrot": ["take_worn"], "ev_coconuts": ["stun_player", "take_held"], "ev_rain": ["panic_animals"]}
	return HudModel.new(cfg, EntityDefs.animal_kinds(), EntityDefs.item_kinds(), effects, _tasks)


func test_format_time() -> void:
	check_eq(HudModel.format_time(300.0), "5:00", "300")
	check_eq(HudModel.format_time(61.2), "1:02", "61.2")
	check_eq(HudModel.format_time(59.01), "1:00", "59.01")
	check_eq(HudModel.format_time(0.4), "0:01", "0.4")
	check_eq(HudModel.format_time(0.0), "0:00", "0")
	check_eq(HudModel.format_time(-3.0), "0:00", "negative")
	check_eq(HudModel.format_time(9.0), "0:09", "9")


func test_warning_and_star_goal() -> void:
	check(HudModel.is_warning(10.0, 10.0, S.RUNNING), "warning at 10.0")
	check(HudModel.is_warning(3.0, 10.0, S.REQUIRED_DONE), "warning after required done")
	check_false(HudModel.is_warning(10.01, 10.0, S.RUNNING), "no warning at 10.01")
	for state in [S.WON, S.LOST, S.PAUSED, S.READY]:
		check_false(HudModel.is_warning(5.0, 10.0, state), "no warning in state %d" % state)
	check(HudModel.star_goal_reachable(45.0, 45.0), "reachable at the threshold")
	check(HudModel.star_goal_reachable(46.0, 45.0), "reachable above")
	check_false(HudModel.star_goal_reachable(44.9, 45.0), "unreachable below")


func test_select_hint() -> void:
	check_eq(HudModel.select_hint(_tasks, _progress()), "h.req_a", "nothing done")
	check_eq(HudModel.select_hint(_tasks, _progress(["t_req_a"])), "h.req_b", "first required done")
	check_eq(HudModel.select_hint(_tasks, _progress(["t_req_a", "t_req_b"])), "h.opt_c", "required done")
	check_eq(HudModel.select_hint(_tasks, _progress(["t_req_a", "t_req_b"], ["t_opt_c"])), "h.opt_d", "missed skipped")
	check_eq(HudModel.select_hint(_tasks, _progress(["t_req_a", "t_req_b", "t_opt_c", "t_opt_d"])), HudModel.NO_HINT_KEY,
			"all done")
	check(I18n.has_key(HudModel.NO_HINT_KEY), "no-hint key exists")


func test_task_title_falls_back_to_hint() -> void:
	check_eq(HudModel.task_title_key({"title_key": "x.title", "hint_key": "x.hint"}), "x.title", "title")
	check_eq(HudModel.task_title_key({"title_key": "", "hint_key": "x.hint"}), "x.hint", "fallback")


func test_classify_table() -> void:
	var m := _model()
	var none := {"progress": _progress(["t_req_a", "t_req_b", "t_opt_c", "t_opt_d"])}
	for reason in ["water", "bounds", "stuck", "weird"]:
		check_eq(m.classify("entity_lost", ["duck", reason], none).get("key"), "hud.cue.animal_escaped", "duck " + reason)
	check_eq(m.classify("entity_lost", ["bucket", "water"], none).get("key"), "hud.cue.item_lost_sea", "item water")
	check_eq(m.classify("entity_lost", ["bucket", "bounds"], none).get("key"), "hud.cue.item_lost_sea", "item bounds")
	check_eq(m.classify("entity_lost", ["bucket", "stuck"], none), {}, "item stuck ignored")
	check_eq(m.classify("entity_lost", ["bucket", "weird"], none), {}, "unknown reason ignored")
	check_eq(m.classify("level_lost", ["lvl", []], none).get("key"), "hud.cue.time_up", "time up")
	check_eq(m.classify("castaway_dizzy_started", ["coconut"], none).get("key"), "hud.cue.dizzy_hit", "dizzy")
	var worn := {"player_worn": "bucket", "player_held": "", "progress": none["progress"]}
	check_eq(m.classify("event_triggered", ["ev_parrot"], worn).get("key"), "hud.cue.event_stole", "stole worn")
	check_eq(m.classify("event_triggered", ["ev_parrot"], none), {}, "nothing worn -> ignored")
	var held := {"player_held": "bucket", "progress": none["progress"]}
	check_eq(m.classify("event_triggered", ["ev_coconuts"], held).get("key"), "hud.cue.event_stole", "stole held")
	check_eq(m.classify("event_triggered", ["ev_rain"], held), {}, "rain steals nothing")
	check_eq(m.classify("animal_fled", ["duck"], none), {}, "animal_fled off by default")
	check_eq(m.classify("object_grabbed", ["duck"], none), {}, "unrelated signal")
	var cue := m.classify("castaway_dizzy_started", ["x"], none)
	check_eq(cue.get("type"), "dizzy_hit", "type")
	check(ResourceLoader.exists(String(cue.get("icon"))), "icon exists")


func test_task_fail_key_override() -> void:
	var m := _model()
	check_eq(m.classify("entity_lost", ["chicken", "water"], {"progress": _progress()}).get("key"), "f.req_a",
			"open required task names the chicken")
	check_eq(m.classify("entity_lost", ["chicken", "water"], {"progress": _progress(["t_req_a"])}).get("key"),
			"hud.cue.animal_escaped", "generic once that task is done")
	check_eq(m.classify("entity_lost", ["coconut", "water"], {"progress": _progress()}).get("key"), "f.opt_d",
			"optional task override")
	check_eq(m.classify("event_triggered", ["ev_parrot"], {"player_worn": "hat", "progress": _progress()}).get("key"),
			"f.opt_c", "stolen hat names the goat task")
	check_eq(m.classify("entity_lost", ["goat", "water"], {"progress": _progress()}).get("key"), "f.opt_c",
			"wearer field counts")


func test_cue_throttle() -> void:
	var t := HudModel.CueThrottle.new(2.5, 1.5)
	check_eq(t.offer("a", 0.0), HudModel.CueThrottle.Result.SHOWN, "first")
	check_eq(t.offer("a", 1.0), HudModel.CueThrottle.Result.MERGED, "merge inside the interval")
	check_eq(t.visible_key(3.4), "a", "timer refreshed by the merge")
	check_eq(t.visible_key(3.6), "", "expired")
	check_eq(t.offer("a", 3.7), HudModel.CueThrottle.Result.SHOWN, "again after the interval")
	check_eq(t.offer("b", 3.8), HudModel.CueThrottle.Result.SHOWN, "different key replaces")
	check_eq(t.visible_key(3.9), "b", "one visible")
	check_eq(t.offer("time", 4.0, true), HudModel.CueThrottle.Result.SHOWN, "priority shows")
	check_eq(t.offer("c", 4.5), HudModel.CueThrottle.Result.BLOCKED, "priority not replaced")
	check_eq(t.visible_key(4.6), "time", "priority still visible")
	check_eq(t.offer("c", 7.0), HudModel.CueThrottle.Result.SHOWN, "after priority expired")
	t.clear()
	check_eq(t.visible_key(7.1), "", "cleared")


func test_dismiss_actions() -> void:
	check_eq(HudModel.prompt_dismiss_action("castaway_step"), "move", "step")
	check_eq(HudModel.prompt_dismiss_action("castaway_dashed"), "dash", "dash")
	check_eq(HudModel.prompt_dismiss_action("object_grabbed"), "grab", "grab")
	check_eq(HudModel.prompt_dismiss_action("object_thrown"), "throw", "throw")
	check_eq(HudModel.prompt_dismiss_action("object_used"), "use", "use")
	check_eq(HudModel.prompt_dismiss_action("animal_fled"), "", "other")


func test_config_loads_clean() -> void:
	var messages: Dictionary = I18n.parse_dir("res://i18n")["messages"]
	var res := HudModel.load_config(HudModel.CONFIG_PATH, EventBus, messages)
	check_eq(res["errors"], [], "data/hud.json errors")
	check_eq(res["config"]["failure_types"].keys().size(), 5, "five failure types")


func test_config_rejects_bad_entries() -> void:
	var messages: Dictionary = I18n.parse_dir("res://i18n")["messages"]
	var data: Dictionary = HudModel.load_config(HudModel.CONFIG_PATH, EventBus, messages)["config"].duplicate(true)
	data["failure_types"]["time_up"]["triggers"][0]["signal"] = "level_exploded"
	data["failure_types"]["dizzy_hit"]["key"] = "hud.cue.nope"
	data["failure_types"]["event_stole"]["icon"] = "res://" + "missing_icon" + ".png"
	var errors := HudModel.validate_config(data, EventBus, messages)
	var text := "\n".join(errors)
	check(text.contains("unknown EventBus signal level_exploded"), "unknown signal: " + text)
	check(text.contains("hud.cue.nope"), "missing key: " + text)
	check(text.contains("missing texture"), "missing icon: " + text)
	check_eq(HudModel.load_config("res://" + "no_such_hud" + ".json", EventBus, messages)["errors"].size(), 1, "missing file")
