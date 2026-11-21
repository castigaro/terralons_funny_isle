class_name ProgressModel
extends RefCounted
## Level progress (pure): which levels are won, best stars and best completion time per level. Unlocks are
## derived, never stored as truth: the first level is always open, level N+1 opens when level N is won, and a won
## level always stays replayable. Losses and abandoned runs are never recorded.

const SCHEMA_VERSION := 1

var _ids: Array = []
## level id -> {won: bool, best_stars: int, best_time_s: float}
var _levels := {}


static func defaults(ids: Array) -> ProgressModel:
	var model := ProgressModel.new()
	model._ids = ids.duplicate()
	return model


## Builds a model from parsed progress.json; every field is checked on its own and bad values are dropped.
## Wins are read in campaign order and stop at the first level that is not won, so a hand-edited file can never
## put stars on a locked level.
static func from_dict(data: Variant, ids: Array) -> ProgressModel:
	var model := defaults(ids)
	if not data is Dictionary:
		return model
	var version: Variant = data.get("schema_version")
	if not _is_number(version) or int(version) < 1 or int(version) > SCHEMA_VERSION:
		return model
	var levels: Variant = data.get("levels")
	if not levels is Dictionary:
		return model
	for level_id in ids:
		var raw: Variant = levels.get(level_id)
		if not raw is Dictionary or not raw.get("won") is bool or not raw["won"]:
			break
		var entry := {"won": true, "best_stars": 0, "best_time_s": -1.0}
		var stars: Variant = raw.get("best_stars")
		if _is_number(stars):
			entry["best_stars"] = clampi(int(stars), 0, Stars.MAX_STARS)
		var best: Variant = raw.get("best_time_s")
		if _is_number(best) and float(best) > 0.0:
			entry["best_time_s"] = float(best)
		model._levels[level_id] = entry
	return model


static func _is_number(v: Variant) -> bool:
	return (v is int) or (v is float and is_finite(v))


func to_dict() -> Dictionary:
	var levels := {}
	for level_id in _ids:
		if _levels.has(level_id):
			levels[level_id] = (_levels[level_id] as Dictionary).duplicate()
	return {"schema_version": SCHEMA_VERSION, "unlocked": unlocked_ids(), "levels": levels}


func ids() -> Array:
	return _ids.duplicate()


func is_unlocked(level_id: String) -> bool:
	var i := _ids.find(level_id)
	if i < 0:
		return false
	return i == 0 or is_won(String(_ids[i - 1]))


func unlocked_ids() -> Array:
	var out: Array = []
	for level_id in _ids:
		if is_unlocked(level_id):
			out.append(level_id)
	return out


func is_won(level_id: String) -> bool:
	return _levels.has(level_id)


## Best stars of a won level, 0 otherwise.
func best_stars(level_id: String) -> int:
	return int(_levels[level_id]["best_stars"]) if _levels.has(level_id) else 0


## Best completion time in seconds of a won level, -1.0 when unknown.
func best_time(level_id: String) -> float:
	return float(_levels[level_id]["best_time_s"]) if _levels.has(level_id) else -1.0


## First unlocked level that is not won yet, else the first level (focus target of the level select).
func first_open_id() -> String:
	for level_id in _ids:
		if is_unlocked(level_id) and not is_won(level_id):
			return level_id
	return String(_ids[0]) if not _ids.is_empty() else ""


## Records a win; best stars and best time are independent records. Returns
## {new_best_stars: bool, new_best_time: bool, first_win: bool (no earlier entry), unlocked_id: String ("" when
## nothing new opened)}.
func record_win(level_id: String, stars: int, completion_s: float) -> Dictionary:
	var result := {"new_best_stars": false, "new_best_time": false, "first_win": false, "unlocked_id": ""}
	var i := _ids.find(level_id)
	if i < 0:
		return result
	var next := String(_ids[i + 1]) if i + 1 < _ids.size() else ""
	var next_was_open := next != "" and is_unlocked(next)
	var had := _levels.has(level_id)
	result["first_win"] = not had
	var entry: Dictionary = _levels[level_id] if had else {"won": true, "best_stars": 0, "best_time_s": -1.0}
	var clamped := clampi(stars, 0, Stars.MAX_STARS)
	if not had or clamped > int(entry["best_stars"]):
		entry["best_stars"] = clamped
		result["new_best_stars"] = true
	if is_finite(completion_s) and completion_s > 0.0:
		var prev := float(entry["best_time_s"])
		if prev <= 0.0 or completion_s < prev:
			entry["best_time_s"] = completion_s
			result["new_best_time"] = true
	_levels[level_id] = entry
	if next != "" and not next_was_open:
		result["unlocked_id"] = next
	return result
