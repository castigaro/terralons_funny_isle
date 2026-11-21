class_name Campaign
extends RefCounted
## The ordered level list of data/campaign.json (order = unlock order, number = index + 1). By convention level <id>
## lives in scenes/levels/<id>.tscn with its data in data/levels/<id>.json; an entry may name other "scene" and
## "json" paths (test campaigns). An entry whose scene does not exist yet is listed as unavailable ("Coming soon")
## and cannot be started.

const SCHEMA_VERSION := 1
const ID_PATTERN := "^[a-z][a-z0-9_]*$"
const SCENE_DIR := "res://scenes/levels/"
const JSON_DIR := "res://data/levels/"

var _entries: Array = []
var _index := {}


## Loads a campaign file: {ok: bool, campaign: Campaign (never null), errors: Array}.
static func load_file(path: String) -> Dictionary:
	var res := JsonStore.read(path)
	if res["status"] != JsonStore.STATUS_OK:
		return {"ok": false, "campaign": Campaign.new(), "errors": ["%s: %s" % [path, res["status"]]]}
	return parse(res["data"], path)


## Builds a campaign from parsed JSON; invalid entries are skipped and reported.
static func parse(data: Variant, label: String = "campaign") -> Dictionary:
	var campaign := Campaign.new()
	var errors: Array = []
	if not data is Dictionary or not (data as Dictionary).get("levels") is Array:
		return {"ok": false, "campaign": campaign, "errors": ["%s: needs an object with a levels array" % label]}
	var re := RegEx.create_from_string(ID_PATTERN)
	var levels: Array = data["levels"]
	for i in levels.size():
		var raw: Variant = levels[i]
		if not raw is Dictionary:
			errors.append("%s: levels[%d] is not an object" % [label, i])
			continue
		var level_id: Variant = raw.get("id")
		var scene: Variant = raw.get("scene", SCENE_DIR + str(level_id) + ".tscn")
		var json_path: Variant = raw.get("json", JSON_DIR + str(level_id) + ".json")
		if not level_id is String or re.search(level_id) == null:
			errors.append("%s: levels[%d] has an invalid id" % [label, i])
			continue
		if not scene is String or not json_path is String:
			errors.append("%s: levels[%d] needs scene and json paths" % [label, i])
			continue
		if campaign._index.has(level_id):
			errors.append("%s: duplicate level id %s" % [label, level_id])
			continue
		campaign._index[level_id] = campaign._entries.size()
		campaign._entries.append({"id": level_id, "scene": scene, "json": json_path,
				"title_key": _title_key(json_path)})
	if campaign._entries.is_empty():
		errors.append("%s: no levels" % label)
	return {"ok": errors.is_empty(), "campaign": campaign, "errors": errors}


static func _title_key(json_path: String) -> String:
	var res := JsonStore.read(json_path)
	if res["status"] != JsonStore.STATUS_OK or not res["data"] is Dictionary:
		return ""
	var key: Variant = (res["data"] as Dictionary).get("title_key", "")
	return key if key is String else ""


func ids() -> Array:
	var out: Array = []
	for e in _entries:
		out.append(e["id"])
	return out


func size() -> int:
	return _entries.size()


func has(level_id: String) -> bool:
	return _index.has(level_id)


func index_of(level_id: String) -> int:
	return int(_index.get(level_id, -1))


## {id, number, scene, json, title_key, available}; empty when the id is unknown.
func entry(level_id: String) -> Dictionary:
	if not _index.has(level_id):
		return {}
	var e: Dictionary = _entries[_index[level_id]].duplicate()
	e["number"] = int(_index[level_id]) + 1
	e["available"] = ResourceLoader.exists(String(e["scene"]))
	return e


func first_id() -> String:
	return String(_entries[0]["id"]) if not _entries.is_empty() else ""


## Id of the next level, "" after the last or for an unknown id.
func next_id(level_id: String) -> String:
	var i := index_of(level_id)
	if i < 0 or i + 1 >= _entries.size():
		return ""
	return String(_entries[i + 1]["id"])


func is_last(level_id: String) -> bool:
	var i := index_of(level_id)
	return i >= 0 and i == _entries.size() - 1
