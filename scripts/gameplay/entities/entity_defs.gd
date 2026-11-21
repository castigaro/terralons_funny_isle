class_name EntityDefs
extends RefCounted
## Animal and item kinds from data/animals.json and data/items.json. parse() applies the same rules as
## tools/validate_entities.py, except the deny-list and on-screen size checks of the sprites (Python only).
## Behaviour is generic: the code never names a kind, every difference between animals is data.

const BalanceScript := preload("res://scripts/autoload/balance.gd")
const I18nScript := preload("res://scripts/autoload/i18n.gd")
const FORMAT_VERSION := 1
const ANIMALS_PATH := "res://data/animals.json"
const ITEMS_PATH := "res://data/items.json"
const ID_PATTERN := "^[a-z][a-z0-9_]*$"
## Field kinds: "sprite", "number" (> 0), "bool", "lure" ("" or an item kind), "key" (i18n key).
const ANIMAL_FIELDS := {
	"sprite": "sprite", "sprite_scale": "number", "speed": "number", "wander_radius": "number",
	"flee_radius": "number", "flee_speed_factor": "number", "panic_duration": "number", "lure_item": "lure",
	"lure_radius": "number", "follow_distance": "number", "herdable": "bool", "swims": "bool",
	"carry_weight": "number", "pitch": "number", "name_key": "key",
}
const ITEM_FIELDS := {
	"sprite": "sprite", "sprite_scale": "number", "carry_weight": "number", "wearable": "bool", "swims": "bool",
	"name_key": "key",
}
## Reason of an entity_lost signal -> i18n key of the cue shown to the player (A9).
const LOST_CUE_KEYS := {"water": "entities.lost_water", "bounds": "entities.lost_bounds",
		"stuck": "entities.lost_stuck"}

static var _cache: Dictionary = {}
static var _id_re: RegEx = null


## Returns the context for parse(): i18n messages {key: {en, de}}, the castaway and entities balance sections.
static func make_context(messages: Dictionary, castaway: Dictionary, entities: Dictionary,
		check_files: bool = true) -> Dictionary:
	return {"messages": messages, "castaway": castaway, "entities": entities, "check_files": check_files}


## Validates parsed animals and items data: returns {animals: {kind: def}, items: {kind: def}, errors: Array}.
static func parse(animals_data: Variant, items_data: Variant, ctx: Dictionary) -> Dictionary:
	var errors: Array = []
	var item_kinds := {}
	var items := _section(items_data, "items", "items.json", errors)
	for kind in items:
		item_kinds[kind] = true
	var animals := _section(animals_data, "animals", "animals.json", errors)
	var out_items := {}
	for kind in items:
		var entry: Variant = items[kind]
		if _check_entry(entry, ITEM_FIELDS, "items.json: items.%s" % kind, item_kinds, ctx, errors):
			if entry.get("swims") == true:
				errors.append("items.json: items.%s.swims: items cannot swim, swims must be false" % kind)
			out_items[kind] = entry
	var out_animals := {}
	var ent: Dictionary = ctx.get("entities", {})
	for kind in animals:
		var entry: Variant = animals[kind]
		var path := "animals.json: animals.%s" % kind
		if item_kinds.has(kind):
			errors.append("%s: kind %s is both an animal and an item" % [path, kind])
		if not _check_entry(entry, ANIMAL_FIELDS, path, item_kinds, ctx, errors):
			continue
		if ent.has("bonk_seconds") and ent.has("reaction_max_seconds") and _is_number(entry.get("panic_duration")):
			if float(ent["bonk_seconds"]) + float(entry["panic_duration"]) > float(ent["reaction_max_seconds"]):
				errors.append("%s.panic_duration: bonk_seconds + panic_duration exceeds reaction_max_seconds" % path)
		out_animals[kind] = entry
	return {"animals": out_animals, "items": out_items, "errors": errors}


## Loads and parses the real data files with the running Balance and the i18n catalogue (no cache).
static func load_default() -> Dictionary:
	var a := _read_json(ANIMALS_PATH)
	var i := _read_json(ITEMS_PATH)
	var errors: Array = a["errors"] + i["errors"]
	if not errors.is_empty():
		return {"animals": {}, "items": {}, "errors": errors}
	var balance: Node = _balance()
	var castaway: Dictionary = balance.call("get_section", "castaway") if balance != null else {}
	var entities: Dictionary = balance.call("get_section", EntityConfig.NAMESPACE) if balance != null else {}
	var messages: Dictionary = I18nScript.parse_dir("res://i18n")["messages"]
	return parse(a["data"], i["data"], make_context(messages, castaway, entities))


## Animal definition of kind from the cached default data, or {} for an unknown kind.
static func get_animal(kind: String) -> Dictionary:
	return _cached()["animals"].get(kind, {})


## Item definition of kind from the cached default data, or {} for an unknown kind.
static func get_item(kind: String) -> Dictionary:
	return _cached()["items"].get(kind, {})


## Every known kind (animals and items) as a set {kind: true}.
static func kinds() -> Dictionary:
	var out := {}
	for kind in _cached()["animals"]:
		out[kind] = true
	for kind in _cached()["items"]:
		out[kind] = true
	return out


static func animal_kinds() -> Array:
	var out: Array = _cached()["animals"].keys()
	out.sort()
	return out


static func item_kinds() -> Array:
	var out: Array = _cached()["items"].keys()
	out.sort()
	return out


static func cache_errors() -> Array:
	return _cached()["errors"]


static func clear_cache() -> void:
	_cache = {}


static func _cached() -> Dictionary:
	if _cache.is_empty():
		_cache = load_default()
	return _cache


static func _balance() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Balance") if tree != null else null


static func _section(data: Variant, key: String, fname: String, errors: Array) -> Dictionary:
	if not data is Dictionary:
		errors.append("%s: (top): top level must be an object" % fname)
		return {}
	for field in data:
		if field != "format_version" and field != key:
			errors.append("%s: %s: unknown field" % [fname, field])
	if not (data.get("format_version") is int and data["format_version"] == FORMAT_VERSION):
		errors.append("%s: format_version: must be %d" % [fname, FORMAT_VERSION])
	var entries: Variant = data.get(key)
	if not entries is Dictionary or entries.is_empty():
		errors.append("%s: %s: must be a non-empty object" % [fname, key])
		return {}
	var out := {}
	for kind in entries:
		if not _is_name(kind):
			errors.append("%s: %s.%s: kind must match %s" % [fname, key, kind, ID_PATTERN])
			continue
		out[kind] = entries[kind]
	return out


static func _check_entry(entry: Variant, fields: Dictionary, path: String, item_kinds: Dictionary, ctx: Dictionary,
		errors: Array) -> bool:
	if not entry is Dictionary:
		errors.append("%s: must be an object" % path)
		return false
	var before := errors.size()
	for key in fields:
		if not entry.has(key):
			errors.append("%s.%s: missing" % [path, key])
	for key in entry:
		if not fields.has(key):
			errors.append("%s.%s: unknown field" % [path, key])
	var messages: Dictionary = ctx.get("messages", {})
	var castaway: Dictionary = ctx.get("castaway", {})
	for key in fields:
		if not entry.has(key):
			continue
		var value: Variant = entry[key]
		var fpath := "%s.%s" % [path, key]
		match fields[key]:
			"number":
				if not _is_number(value) or value <= 0:
					errors.append("%s: must be a number > 0" % fpath)
			"bool":
				if not value is bool:
					errors.append("%s: must be a bool" % fpath)
			"lure":
				if not value is String or (value != "" and not item_kinds.has(value)):
					errors.append("%s: unknown lure item %s" % [fpath, str(value)])
			"sprite":
				if not value is String or not value.begins_with("res://assets/"):
					errors.append("%s: must be a res://assets/ path" % fpath)
				elif ctx.get("check_files", true) and not FileAccess.file_exists(value):
					errors.append("%s: sprite not found: %s" % [fpath, value])
			"key":
				if not value is String or value == "":
					errors.append("%s: must be a non-empty i18n key" % fpath)
				elif not messages.has(value):
					errors.append("%s: name_key %s not found in the i18n catalogue" % [fpath, value])
				else:
					for lang in ["en", "de"]:
						if str(messages[value].get(lang, "")).strip_edges() == "":
							errors.append("%s: name_key %s has no %s text" % [fpath, value, lang.to_upper()])
	var weight: Variant = entry.get("carry_weight")
	if _is_number(weight) and castaway.has("carry_weight_min") and castaway.has("carry_weight_max"):
		if weight < float(castaway["carry_weight_min"]) or weight > float(castaway["carry_weight_max"]):
			errors.append("%s.carry_weight: outside the castaway carry_weight_min..carry_weight_max" % path)
	return errors.size() == before


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"data": null, "errors": ["%s: cannot read" % path.get_file()]}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"data": null, "errors": ["%s: invalid JSON (%s)" % [path.get_file(), json.get_error_message()]]}
	return {"data": BalanceScript.normalize_json(json.data), "errors": []}


## Reads a fixture or data file: {data, errors}.
static func read_json(path: String) -> Dictionary:
	return _read_json(path)


static func _is_name(v: Variant) -> bool:
	if not v is String:
		return false
	if _id_re == null:
		_id_re = RegEx.create_from_string(ID_PATTERN)
	return _id_re.search(v) != null


static func _is_number(v: Variant) -> bool:
	return v is int or v is float
