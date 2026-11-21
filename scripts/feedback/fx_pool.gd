class_name FxPool
extends RefCounted
## Fixed-size pool of one effect type, preallocated to its cap: acquire() hands out a free slot or recycles the
## oldest active one, so the active count never exceeds the cap and nothing is allocated after setup.
## A slot is a Dictionary {node, active, seq, age, duration, ...effect state}; node may be null for node-less
## effects such as squash and recoil.

var type := ""
var slots: Array[Dictionary] = []
## Number of effects ever started (uncapped, for tests and stats).
var played := 0
var recycled := 0
var _seq := 0


## factory returns the node of one slot (or null); size is the cap.
func _init(effect_type: String, size: int, factory: Callable) -> void:
	type = effect_type
	for i in maxi(1, size):
		var node: Variant = factory.call() if factory.is_valid() else null
		slots.append({"node": node, "active": false, "seq": 0, "age": 0.0, "duration": 0.0})


func acquire() -> Dictionary:
	var pick: Dictionary = {}
	for slot in slots:
		if not slot["active"]:
			pick = slot
			break
	if pick.is_empty():
		pick = slots[0]
		for slot in slots:
			if slot["seq"] < pick["seq"]:
				pick = slot
		recycled += 1
	_seq += 1
	played += 1
	pick["active"] = true
	pick["seq"] = _seq
	pick["age"] = 0.0
	pick["duration"] = 0.0
	return pick


func release(slot: Dictionary) -> void:
	slot["active"] = false
	var node: Variant = slot["node"]
	if node is CanvasItem and is_instance_valid(node):
		(node as CanvasItem).visible = false


func release_all() -> void:
	for slot in slots:
		release(slot)


func active_count() -> int:
	var n := 0
	for slot in slots:
		if slot["active"]:
			n += 1
	return n


func active_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in slots:
		if slot["active"]:
			out.append(slot)
	return out


func size() -> int:
	return slots.size()
