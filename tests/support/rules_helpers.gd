extends RefCounted
## Shared builders for the rules tests: inline levels, world snapshots and the declared event effects.

const EVENTS_PATH := "res://data/events.json"


## Returns the merged balance section "rules" of the running Balance autoload.
static func rules() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node("Balance").call("get_section", "rules")


## Returns the EventBus autoload.
static func bus() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node("EventBus")


static func event_types() -> Dictionary:
	return LevelDef.load_event_types(EVENTS_PATH)["types"]


## A valid inline level: two required and two optional tasks, two events, 180 s timer.
static func level_data() -> Dictionary:
	return {
		"format_version": 1, "id": "lvl_inline", "title_key": "t.title", "theme": "palm_beach",
		"music": "tune_a", "seed": 9001, "timer_seconds": 180,
		"tasks": [
			_task("t_alpha", true, [{"type": "in_zone", "entity": "chicken", "zone": "coop", "count": 2}]),
			_task("t_bravo", true, [{"type": "held", "entity": "pig"}]),
			_task("t_charlie", false, [{"type": "delivered_to", "entity": "coconut", "target": "monkey",
					"count": 3}]),
			_task("t_delta", false, [{"type": "count_reached", "counter": "sand", "count": 2}]),
		],
		"events": [
			{"id": "e_one", "type": "parrot_steal_hat", "window": [30, 60], "duration_s": 5},
			{"id": "e_two", "type": "wave_wash", "window": [100, 150], "duration_s": 8},
		],
	}


static func _task(id: String, required: bool, conds: Array) -> Dictionary:
	return {"id": id, "required": required, "conditions": conds, "hint_key": "t.%s_hint" % id,
			"fail_key": "t.%s_fail" % id}


## Parses level data with a catalogue generated from its own text keys; returns the LevelDef or null.
static func make_def(data: Dictionary, rules_section: Dictionary = {}) -> LevelDef:
	var messages := {}
	messages[data.get("title_key", "")] = {"en": "x", "de": "x"}
	for task in data.get("tasks", []):
		for key in ["hint_key", "fail_key"]:
			messages[task.get(key, "")] = {"en": "x", "de": "x"}
	var section := rules_section if not rules_section.is_empty() else rules()
	var res := LevelDef.parse(data, LevelDef.make_context(section, event_types(), messages), "")
	if not res["ok"]:
		push_warning("make_def: %s" % str(res["errors"]))
		return null
	return res["def"]


## Snapshot {player, entities}.
static func snap(zones: Array = [], held: String = "", worn: String = "", entities: Array = []) -> Dictionary:
	return {"player": {"zones": zones, "held": held, "worn": worn}, "entities": entities}


static func ent(uid: String, kind: String, zones: Array = [], held_by: String = "", worn_by: String = "") -> Dictionary:
	return {"uid": uid, "kind": kind, "zones": zones, "held_by": held_by, "worn_by": worn_by}


## Snapshot that satisfies t_alpha (two free chickens in the coop) and t_bravo (pig held).
static func snap_required_done() -> Dictionary:
	return snap(["yard"], "pig", "", [ent("c1", "chicken", ["coop"]), ent("c2", "chicken", ["coop"]),
			ent("p1", "pig", [], "player")])


## Applies the declared effects of an event type to a snapshot copy, as a level scene would.
static func apply_effects(snapshot: Dictionary, effects: Array) -> Dictionary:
	var out: Dictionary = snapshot.duplicate(true)
	for effect in effects:
		match effect:
			"relocate_entities":
				for e in out["entities"]:
					e["zones"] = []
			"take_held":
				out["player"]["held"] = ""
				for e in out["entities"]:
					e["held_by"] = ""
			"take_worn":
				out["player"]["worn"] = ""
			"steal_wearable":
				var held := String(out["player"]["held"])
				if held != "" and bool(EntityDefs.get_item(held).get("wearable", false)):
					out["player"]["held"] = ""
					for e in out["entities"]:
						if String(e["kind"]) == held:
							e["held_by"] = ""
				out["player"]["worn"] = ""
			"stun_player":
				out["player"]["stunned"] = true
			_:
				pass
	return out


## Ticks a session n times by delta with the same snapshot.
static func run(session: LevelSession, n: int, delta: float, snapshot: Dictionary) -> void:
	for i in n:
		session.tick(delta, snapshot)
