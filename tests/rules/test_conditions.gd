extends TestCase
## Conditions: every condition and modifier against hand-built snapshots.

const H := preload("res://tests/support/rules_helpers.gd")


func _eval(cond: Dictionary, snapshot: Dictionary, counters: Dictionary = {}, ctx: Dictionary = {}) -> Dictionary:
	var full := {"elapsed": 0.0, "triggered_events": {}}
	full.merge(ctx, true)
	return Conditions.evaluate(cond, Conditions.index(snapshot), counters, full)


func test_in_zone_player() -> void:
	var cond := {"type": "in_zone", "entity": "player", "zone": "dock"}
	check(_eval(cond, H.snap(["dock", "beach"]))["ok"], "player on dock")
	check_false(_eval(cond, H.snap(["beach"]))["ok"], "player elsewhere")


func test_in_zone_count_and_carried() -> void:
	var cond := {"type": "in_zone", "entity": "chicken", "zone": "coop", "count": 2}
	var one := H.snap([], "", "", [H.ent("a", "chicken", ["coop"]), H.ent("b", "chicken", ["yard"])])
	check_eq(_eval(cond, one), {"current": 1, "target": 2, "ok": false}, "one in coop")
	var carried := H.snap([], "chicken", "", [H.ent("a", "chicken", ["coop"]),
			H.ent("b", "chicken", ["coop"], "player")])
	check_eq(_eval(cond, carried)["current"], 1, "carried chicken does not count")
	var two := H.snap([], "", "", [H.ent("a", "chicken", ["coop"]), H.ent("b", "chicken", ["coop"]),
			H.ent("g", "goat", ["coop"])])
	check_eq(_eval(cond, two), {"current": 2, "target": 2, "ok": true}, "two in coop")


func test_held() -> void:
	var cond := {"type": "held", "entity": "pig"}
	check(_eval(cond, H.snap([], "pig"))["ok"], "holding pig")
	check_false(_eval(cond, H.snap([], "duck"))["ok"], "holding duck")
	check_false(_eval(cond, H.snap())["ok"], "empty hands")


func test_worn() -> void:
	check(_eval({"type": "worn", "item": "hat"}, H.snap([], "", "hat"))["ok"], "player wears hat")
	check_false(_eval({"type": "worn", "item": "hat"}, H.snap())["ok"], "no hat")
	var goat := {"type": "worn", "item": "hat", "wearer": "goat"}
	check(_eval(goat, H.snap([], "", "", [H.ent("h", "hat", [], "", "goat")]))["ok"], "goat wears hat")
	check_false(_eval(goat, H.snap([], "", "", [H.ent("h", "hat", [], "", "pig")]))["ok"], "pig wears hat")
	check_false(_eval(goat, H.snap([], "", "hat"))["ok"], "player hat is not goat hat")


func test_counters() -> void:
	var cond := {"type": "delivered_to", "entity": "coconut", "target": "monkey", "count": 3}
	var counters := {Conditions.counter_key_delivery("coconut", "monkey"): 2}
	check_eq(_eval(cond, H.snap(), counters), {"current": 2, "target": 3, "ok": false}, "2 of 3")
	counters[Conditions.counter_key_delivery("coconut", "monkey")] = 3
	check(_eval(cond, H.snap(), counters)["ok"], "3 of 3")
	var other := {Conditions.counter_key_delivery("coconut", "goat"): 9}
	check_false(_eval(cond, H.snap(), other)["ok"], "other target does not count")
	var cr := {"type": "count_reached", "counter": "sand", "count": 2}
	check_false(_eval(cr, H.snap(), {Conditions.counter_key("sand"): 1})["ok"], "1 of 2")
	check(_eval(cr, H.snap(), {Conditions.counter_key("sand"): 5})["ok"], "5 of 2")


func test_before_time_boundary() -> void:
	var cond := {"type": "before_time", "seconds": 60}
	check(_eval(cond, H.snap(), {}, {"elapsed": 60.0})["ok"], "exactly at deadline")
	check_false(_eval(cond, H.snap(), {}, {"elapsed": 60.01})["ok"], "just after")
	check(Conditions.is_deadline(cond), "deadline")


func test_before_event() -> void:
	var cond := {"type": "before_event", "event": "e_wave"}
	check(_eval(cond, H.snap())["ok"], "before trigger")
	check_false(_eval(cond, H.snap(), {}, {"triggered_events": {"e_wave": true}})["ok"], "after trigger")
	check(Conditions.is_deadline(cond), "deadline")
	check_false(Conditions.is_deadline({"type": "held", "entity": "pig"}), "held is no deadline")


func test_empty_snapshot() -> void:
	var idx := Conditions.index({})
	check_eq(idx["player_held"], "", "held")
	check_eq(idx["free"], {}, "free")
	var ctx := {"elapsed": 0.0, "triggered_events": {}}
	check_false(Conditions.evaluate({"type": "held", "entity": "pig"}, idx, {}, ctx)["ok"], "nothing held")
