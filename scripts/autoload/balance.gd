extends Node
## Tuning numbers: merges every data/balance/*.json namespaced by file stem (core.json -> "core") plus an
## override layer for tests; overrides win over file values.

const BALANCE_DIR := "res://data/balance"
const MAX_SAFE_INT := 9007199254740992.0

var _data := {}
var _overrides := {}
var _errors: Array = []


func _ready() -> void:
	reload()
	for err in _errors:
		push_error("Balance: %s" % err)


## Re-reads every balance file and keeps the overrides.
func reload() -> void:
	var parsed := parse_dir(BALANCE_DIR)
	_data = parsed["data"]
	_errors = parsed["errors"]


## Returns the errors of the last load.
func last_errors() -> Array:
	return _errors.duplicate()


## Pure loader for res:// or absolute folders: returns {data: {stem: Dictionary}, errors: Array} and never prints.
static func parse_dir(path: String) -> Dictionary:
	var data := {}
	var errors: Array = []
	if not DirAccess.dir_exists_absolute(path):
		errors.append("missing folder %s" % path)
		return {"data": data, "errors": errors}
	var names := Array(DirAccess.get_files_at(path))
	names.sort()
	for name in names:
		if name.get_extension() != "json":
			continue
		var json := JSON.new()
		var status := json.parse(FileAccess.get_file_as_string(path.path_join(name)))
		if status != OK:
			errors.append("%s:%d: %s" % [name, json.get_error_line(), json.get_error_message()])
			continue
		if not json.data is Dictionary:
			errors.append("%s: top level must be an object" % name)
			continue
		data[name.get_basename()] = normalize_json(json.data)
	return {"data": data, "errors": errors}


## Returns a deep copy in which integral floats (as produced by the JSON parser) are ints again.
static func normalize_json(v: Variant) -> Variant:
	if v is float:
		if is_finite(v) and v == floorf(v) and absf(v) < MAX_SAFE_INT:
			return int(v)
		return v
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = normalize_json(v[k])
		return out
	if v is Array:
		var items := []
		for item in v:
			items.append(normalize_json(item))
		return items
	return v


## Pure int read: returns {ok, value, error}; integral floats count as ints.
static func read_int(section: Dictionary, key: String) -> Dictionary:
	if not section.has(key):
		return {"ok": false, "value": 0, "error": "missing key '%s'" % key}
	var v: Variant = section[key]
	if v is int:
		return {"ok": true, "value": v, "error": ""}
	if v is float and is_finite(v) and v == floorf(v):
		return {"ok": true, "value": int(v), "error": ""}
	return {"ok": false, "value": 0, "error": "'%s' is not an integer: %s" % [key, str(v)]}


## Returns the merged section (file values plus overrides).
func get_section(ns: String) -> Dictionary:
	var merged: Dictionary = normalize_json(_data.get(ns, {}))
	var over: Dictionary = _overrides.get(ns, {})
	for key in over:
		merged[key] = normalize_json(over[key])
	return merged


func has_value(ns: String, key: String) -> bool:
	return get_section(ns).has(key)


func get_value(ns: String, key: String, default: Variant = null) -> Variant:
	return get_section(ns).get(key, default)


## Returns an int; a missing or non-integral value is reported via push_error and gives 0.
func get_int(ns: String, key: String) -> int:
	var res := read_int(get_section(ns), key)
	if not res["ok"]:
		push_error("Balance %s: %s" % [ns, res["error"]])
	return res["value"]


func get_float(ns: String, key: String) -> float:
	return float(get_section(ns).get(key, 0.0))


func get_bool(ns: String, key: String) -> bool:
	return bool(get_section(ns).get(key, false))


func set_override(ns: String, key: String, value: Variant) -> void:
	if not _overrides.has(ns):
		_overrides[ns] = {}
	_overrides[ns][key] = value


func set_overrides(ns: String, values: Dictionary) -> void:
	for key in values:
		set_override(ns, key, values[key])


func clear_overrides() -> void:
	_overrides.clear()
