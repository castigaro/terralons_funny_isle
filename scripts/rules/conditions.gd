class_name Conditions
extends RefCounted
## Pure evaluation of the generic real-time conditions against a world snapshot (see docs/rules.md).

const PLAYER := "player"
const SEP := "|"


## Builds the per-tick lookup index of a snapshot {player: {zones, held, worn}, entities: [{kind, zones, held_by, worn_by}]};
## a non-empty kinds set limits the entity scan to the kinds the level's conditions name (see relevant_kinds()).
static func index(snapshot: Dictionary, kinds: Dictionary = {}) -> Dictionary:
	var player: Variant = snapshot.get("player", {})
	if not player is Dictionary:
		player = {}
	var zones := {}
	for zone in player.get("zones", []):
		zones[zone] = true
	var free := {}
	var worn := {}
	var held := {}
	var filtered := not kinds.is_empty()
	var entities: Array = snapshot.get("entities", [])
	for entity: Dictionary in entities:
		var kind: String = entity.get("kind", "")
		if filtered and not kinds.has(kind):
			continue
		var worn_by: String = entity.get("worn_by", "")
		if worn_by != "":
			worn[kind + SEP + worn_by] = true
		var held_by: String = entity.get("held_by", "")
		if held_by != "":
			held[kind + SEP + held_by] = true
			continue
		for zone in entity.get("zones", []):
			var key: String = kind + SEP + zone
			free[key] = free.get(key, 0) + 1
	return {
		"player_zones": zones,
		"player_held": str(player.get("held", "")),
		"player_worn": str(player.get("worn", "")),
		"free": free,
		"worn": worn,
		"held": held,
	}


## Evaluates one condition or modifier: returns {current, target, ok}; ctx = {elapsed, triggered_events}.
static func evaluate(cond: Dictionary, idx: Dictionary, counters: Dictionary, ctx: Dictionary) -> Dictionary:
	var target := int(cond.get("count", 1))
	var current := 0
	match cond.get("type", ""):
		"in_zone":
			var entity: String = cond.get("entity", "")
			if entity == PLAYER:
				target = 1
				current = 1 if idx.get("player_zones", {}).has(cond.get("zone", "")) else 0
			else:
				current = idx.get("free", {}).get(entity + SEP + str(cond.get("zone", "")), 0)
		"held":
			current = 1 if idx.get("player_held", "") == cond.get("entity", "") else 0
		"worn":
			var wearer: String = cond.get("wearer", PLAYER)
			var item: String = cond.get("item", "")
			if wearer == PLAYER:
				current = 1 if idx.get("player_worn", "") == item else 0
			else:
				current = 1 if idx.get("worn", {}).has(item + SEP + wearer) else 0
		"delivered_to":
			current = counters.get(counter_key_delivery(cond.get("entity", ""), cond.get("target", "")), 0)
		"count_reached":
			current = counters.get(counter_key(cond.get("counter", "")), 0)
		"before_time":
			current = 1 if float(ctx.get("elapsed", 0.0)) <= float(cond.get("seconds", 0.0)) else 0
		"before_event":
			current = 0 if ctx.get("triggered_events", {}).has(cond.get("event", "")) else 1
		_:
			current = 0
	return {"current": current, "target": target, "ok": current >= target}


## Returns the set of entity kinds whose zone or wearer state the given conditions read.
static func relevant_kinds(conds: Array) -> Dictionary:
	var kinds := {}
	for cond in conds:
		match cond.get("type", ""):
			"in_zone":
				if cond.get("entity", "") != PLAYER:
					kinds[cond.get("entity", "")] = true
			"worn":
				kinds[cond.get("item", "")] = true
	return kinds


## True for conditions that can only turn false for good (time or event deadlines).
static func is_deadline(cond: Dictionary) -> bool:
	var ctype: String = cond.get("type", "")
	return ctype == "before_time" or ctype == "before_event"


## Counter key of a delivery of an entity kind to a target.
static func counter_key_delivery(entity: String, target: String) -> String:
	return "delivered:%s>%s" % [entity, target]


## Counter key of a named counter.
static func counter_key(counter: String) -> String:
	return "count:%s" % counter
