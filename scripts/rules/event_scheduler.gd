class_name EventScheduler
extends RefCounted
## Computes the deterministic event schedule of a level from its seed; triggering happens in LevelSession.

const MODE_SEEDED := "seeded"
const MODE_EARLIEST := "earliest"
const MODE_LATEST := "latest"


## Returns [{id, type, params, index, start, end}] sorted by (start, data index).
## Seeded mode draws once per event in data order, so appending an event never shifts earlier start times;
## earliest and latest force every event to its window minimum or maximum (worst-case runs).
static func build(events: Array, run_seed: int, mode: String = MODE_SEEDED) -> Array:
	var rng := SeededRng.new(run_seed)
	var entries: Array = []
	for i in events.size():
		var ev: Dictionary = events[i]
		var lo := float(ev["window"][0])
		var hi := float(ev["window"][1])
		var drawn := rng.randf_range(lo, hi)
		var start := drawn
		if mode == MODE_EARLIEST:
			start = lo
		elif mode == MODE_LATEST:
			start = hi
		entries.append({
			"id": ev["id"],
			"type": ev["type"],
			"params": ev.get("params", {}).duplicate(true),
			"index": i,
			"start": start,
			"end": start + float(ev["duration_s"]),
		})
	entries.sort_custom(_before)
	return entries


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["start"] != b["start"]:
		return a["start"] < b["start"]
	return a["index"] < b["index"]
