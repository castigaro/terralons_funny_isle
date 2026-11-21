class_name LevelDef
extends RefCounted
## Parsed, read-only level definition; parse() applies the same rule set as tools/validate_levels.py.

const BalanceScript := preload("res://scripts/autoload/balance.gd")
const FORMAT_VERSION := 1
const EVENTS_PATH := "res://data/events.json"
const LEVELS_DIR := "res://data/levels"
const ID_PATTERN := "^[a-z][a-z0-9_]*$"
const PLAYER := "player"
const LEVEL_REQUIRED := ["format_version", "id", "title_key", "theme", "music", "seed", "timer_seconds", "tasks",
		"events"]
const LEVEL_OPTIONAL := ["three_star_share", "prompts"]
const TASK_REQUIRED := ["id", "required", "conditions", "hint_key", "fail_key"]
const TASK_OPTIONAL := ["modifiers", "title_key"]
## Contextual key prompts (BI-6): {id, anchor, action, text_key}; anchors are checked again by LevelBase.
const PROMPT_FIELDS := ["id", "anchor", "action", "text_key"]
const PROMPT_ACTIONS := ["move", "dash", "grab", "throw", "use"]
const ANCHOR_PATTERN := "^(player|zone:[a-z][a-z0-9_]*|entity:[a-z][a-z0-9_]*)$"
const EVENT_REQUIRED := ["id", "type", "window", "duration_s"]
const EVENT_OPTIONAL := ["params"]
const RULE_KEYS := ["timer_min_seconds", "timer_max_seconds", "tasks_min", "tasks_max", "events_min"]
## Condition grammar: type -> [{required field: kind}, {optional field: kind}].
const CONDITIONS := {
	"in_zone": [{"entity": "name", "zone": "name"}, {"count": "count"}],
	"held": [{"entity": "name"}, {}],
	"worn": [{"item": "name"}, {"wearer": "name"}],
	"delivered_to": [{"entity": "name", "target": "name"}, {"count": "count"}],
	"count_reached": [{"counter": "name", "count": "count"}, {}],
	"before_time": [{"seconds": "seconds"}, {}],
}
const MODIFIER_ONLY := {"before_event": [{"event": "event"}, {}]}
## Condition fields that name an entity kind (checked against the known kinds, except "player").
const ENTITY_FIELDS := {"in_zone": ["entity"], "held": ["entity"], "delivered_to": ["entity"], "worn": ["item", "wearer"]}
const PARAM_TYPES := ["string", "int", "float", "bool"]
const EFFECTS := ["relocate_entities", "take_held", "take_worn", "stun_player", "panic_animals", "slippery_ground"]

static var _id_re: RegEx = null
static var _anchor_re: RegEx = null

var id := ""
var title_key := ""
var theme := ""
var music := ""
var level_seed := 0
var timer_seconds := 0.0
## Share of the timer needed for 3 stars, or -1.0 when the level uses the balance default.
var three_star_share := -1.0
## Normalized tasks: {id, required, conditions, modifiers, target, hint_key, fail_key, title_key ("" when absent)}.
var tasks: Array[Dictionary] = []
## Normalized events: {id, type, window: [min, max], duration_s, params}.
var events: Array[Dictionary] = []
## Normalized prompts: {id, anchor, action, text_key} (empty when the level has none).
var prompts: Array[Dictionary] = []


## Returns the context for parse(): balance section "rules", event types, i18n messages {key: {en, de}} and the
## known entity kinds {kind: true} (animals and items); with no kinds the entity names are not checked. music_ids
## lists the music ids of data/audio.json (AudioMap.music_ids()); empty means the music id is not checked.
static func make_context(rules: Dictionary, event_types: Dictionary, messages: Dictionary,
		entity_kinds: Dictionary = {}, music_ids: Array = []) -> Dictionary:
	return {"rules": rules, "event_types": event_types, "messages": messages, "entity_kinds": entity_kinds,
			"music_ids": music_ids}


## Loads data/events.json: returns {types: Dictionary, errors: Array}.
static func load_event_types(path: String = EVENTS_PATH) -> Dictionary:
	var parsed := _read_json(path)
	if not parsed["errors"].is_empty():
		return {"types": {}, "errors": parsed["errors"]}
	var data: Variant = parsed["data"]
	var errors: Array = []
	if not data is Dictionary:
		return {"types": {}, "errors": ["%s: top level must be an object" % path.get_file()]}
	if not (data.get("format_version") is int and data["format_version"] == FORMAT_VERSION):
		errors.append("%s: format_version: must be %d" % [path.get_file(), FORMAT_VERSION])
	var types: Variant = data.get("types")
	if not types is Dictionary or types.is_empty():
		errors.append("%s: types: must be a non-empty object" % path.get_file())
		return {"types": {}, "errors": errors}
	for type_name in types:
		var spec: Variant = types[type_name]
		if not spec is Dictionary or not spec.get("params", {}) is Dictionary:
			errors.append("%s: types.%s: needs params {name: {type, required}}" % [path.get_file(), type_name])
			continue
		for effect in spec.get("effects", []):
			if not EFFECTS.has(effect):
				errors.append("%s: types.%s.effects: unknown effect %s" % [path.get_file(), type_name, effect])
	return {"types": types, "errors": errors}


## Returns the sorted res:// paths of the level files, or [] when the folder is missing.
static func list_level_files(dir: String = LEVELS_DIR) -> Array:
	var files: Array = []
	if not DirAccess.dir_exists_absolute(dir):
		return files
	for name in DirAccess.get_files_at(dir):
		if name.get_extension() == "json":
			files.append(dir.path_join(name))
	files.sort()
	return files


## Reads, normalizes and parses a level file: returns {ok, def, errors}.
static func load_file(path: String, ctx: Dictionary) -> Dictionary:
	var parsed := _read_json(path)
	if not parsed["errors"].is_empty():
		return {"ok": false, "def": null, "errors": parsed["errors"]}
	return parse(parsed["data"], ctx, path.get_file())


## Validates a parsed level: returns {ok, def: LevelDef or null, errors: Array of "<file>: <path>: <message>"}.
static func parse(data: Variant, ctx: Dictionary, fname: String = "") -> Dictionary:
	var errors: Array = []
	var label := fname if fname != "" else "level"
	var err := func(path: String, message: String) -> void:
		errors.append("%s: %s: %s" % [label, path, message])
	if not data is Dictionary:
		err.call("(top)", "top level must be an object")
		return {"ok": false, "def": null, "errors": errors}
	var rules: Dictionary = ctx.get("rules", {})
	var types: Dictionary = ctx.get("event_types", {})
	var messages: Dictionary = ctx.get("messages", {})
	var kinds: Dictionary = ctx.get("entity_kinds", {})
	for key in RULE_KEYS:
		if not rules.get(key) is int:
			err.call("rules", "balance key %s missing or not an integer" % key)
	if not errors.is_empty():
		return {"ok": false, "def": null, "errors": errors}

	_check_keys(data, LEVEL_REQUIRED, LEVEL_OPTIONAL, "", err)
	if data.has("format_version") and not (data["format_version"] is int and data["format_version"] == FORMAT_VERSION):
		err.call("format_version", "must be %d" % FORMAT_VERSION)
	var level_id: Variant = data.get("id")
	if data.has("id"):
		if not _is_name(level_id):
			err.call("id", "must match %s" % ID_PATTERN)
		elif fname != "" and level_id != fname.get_basename():
			err.call("id", "level id %s must equal the file name %s" % [level_id, fname.get_basename()])
	if data.has("title_key"):
		_check_text_key(data["title_key"], "title_key", messages, err)
	for key in ["theme", "music"]:
		if data.has(key) and not _is_name(data[key]):
			err.call(key, "must match %s" % ID_PATTERN)
	var music_ids: Array = ctx.get("music_ids", [])
	if not music_ids.is_empty() and _is_name(data.get("music")) and not music_ids.has(data["music"]):
		err.call("music", "unknown music id %s (not in the music section of data/audio.json)" % data["music"])
	if data.has("seed") and not data["seed"] is int:
		err.call("seed", "must be an integer")
	var timer: Variant = data.get("timer_seconds")
	if data.has("timer_seconds"):
		if not timer is int:
			err.call("timer_seconds", "must be an integer")
			timer = null
		elif timer < rules["timer_min_seconds"] or timer > rules["timer_max_seconds"]:
			err.call("timer_seconds", "%d outside %d..%d" % [timer, rules["timer_min_seconds"], rules["timer_max_seconds"]])
	if data.has("three_star_share"):
		var share: Variant = data["three_star_share"]
		if not _is_number(share) or share <= 0 or share >= 1:
			err.call("three_star_share", "must be a number between 0 and 1 (exclusive)")

	var events_raw: Array = []
	var event_ids := {}
	if data.has("events"):
		if not data["events"] is Array:
			err.call("events", "must be a list")
		else:
			events_raw = data["events"]
			if events_raw.size() < rules["events_min"]:
				err.call("events", "%d event(s), at least %d needed" % [events_raw.size(), rules["events_min"]])
			for ev in events_raw:
				if ev is Dictionary and ev.get("id") is String:
					event_ids[ev["id"]] = true

	var tasks_raw: Array = []
	if data.has("tasks"):
		if not data["tasks"] is Array:
			err.call("tasks", "must be a list")
		else:
			tasks_raw = data["tasks"]
			if tasks_raw.size() < rules["tasks_min"] or tasks_raw.size() > rules["tasks_max"]:
				err.call("tasks", "%d task(s), expected %d..%d" % [tasks_raw.size(), rules["tasks_min"], rules["tasks_max"]])

	var modifier_grammar := CONDITIONS.duplicate()
	modifier_grammar.merge(MODIFIER_ONLY)
	var ids: Array = []
	if _is_name(level_id):
		ids.append(["id", level_id])
	var flags: Array = []
	var norm_tasks: Array[Dictionary] = []
	for i in tasks_raw.size():
		var task: Variant = tasks_raw[i]
		var tpath := "tasks[%d]" % i
		if not task is Dictionary:
			err.call(tpath, "must be an object")
			continue
		_check_keys(task, TASK_REQUIRED, TASK_OPTIONAL, tpath, err)
		if task.has("id"):
			if _is_name(task["id"]):
				ids.append([tpath + ".id", task["id"]])
			else:
				err.call(tpath + ".id", "must match %s" % ID_PATTERN)
		var required: Variant = task.get("required")
		if task.has("required"):
			if required is bool:
				flags.append(required)
			else:
				err.call(tpath + ".required", "must be a bool")
		for key in ["hint_key", "fail_key", "title_key"]:
			if task.has(key):
				_check_text_key(task[key], "%s.%s" % [tpath, key], messages, err)
		var conds: Array = []
		if task.has("conditions"):
			if not task["conditions"] is Array or task["conditions"].is_empty():
				err.call(tpath + ".conditions", "must be a non-empty list")
			else:
				conds = task["conditions"]
			var only_time := not conds.is_empty()
			for j in conds.size():
				_check_condition(conds[j], "%s.conditions[%d]" % [tpath, j], CONDITIONS, timer, event_ids, err, kinds)
				if not (conds[j] is Dictionary and conds[j].get("type") == "before_time"):
					only_time = false
			if only_time:
				err.call(tpath + ".conditions", "before_time cannot be the only condition")
		var mods: Array = []
		if task.has("modifiers"):
			if not task["modifiers"] is Array:
				err.call(tpath + ".modifiers", "must be a list")
			else:
				mods = task["modifiers"]
		for j in mods.size():
			var mpath := "%s.modifiers[%d]" % [tpath, j]
			_check_condition(mods[j], mpath, modifier_grammar, timer, event_ids, err, kinds)
			if mods[j] is Dictionary and mods[j].get("type") == "before_event" and required is bool and required:
				err.call(mpath + ".type", "before_event is only allowed on optional tasks")
		var counting := _counting(conds + mods)
		if counting.size() > 1:
			err.call(tpath + ".conditions", "more than one condition with count > 1 (ambiguous progress target)")
		norm_tasks.append({
			"id": str(task.get("id", "")),
			"required": required is bool and required,
			"conditions": conds.duplicate(true),
			"modifiers": mods.duplicate(true),
			"target": int(counting[0]["count"]) if counting.size() == 1 else 1,
			"hint_key": str(task.get("hint_key", "")),
			"fail_key": str(task.get("fail_key", "")),
			"title_key": str(task.get("title_key", "")),
		})
	if not tasks_raw.is_empty():
		if not flags.has(true):
			err.call("tasks", "at least one required task is needed")
		if not flags.has(false):
			err.call("tasks", "at least one optional task is needed")

	var norm_events: Array[Dictionary] = []
	for i in events_raw.size():
		var ev: Variant = events_raw[i]
		var epath := "events[%d]" % i
		if not ev is Dictionary:
			err.call(epath, "must be an object")
			continue
		_check_keys(ev, EVENT_REQUIRED, EVENT_OPTIONAL, epath, err)
		if ev.has("id"):
			if _is_name(ev["id"]):
				ids.append([epath + ".id", ev["id"]])
			else:
				err.call(epath + ".id", "must match %s" % ID_PATTERN)
		var etype: Variant = ev.get("type")
		var spec: Variant = types.get(etype) if etype is String else null
		if ev.has("type") and not spec is Dictionary:
			err.call(epath + ".type", "unknown event type %s" % str(etype))
		var window: Variant = ev.get("window")
		var window_ok := false
		if ev.has("window"):
			if not window is Array or window.size() != 2 or not _is_number(window[0]) or not _is_number(window[1]):
				err.call(epath + ".window", "must be [min_s, max_s]")
			elif window[0] < 0 or window[0] > window[1]:
				err.call(epath + ".window", "needs 0 <= min <= max, got %s" % str(window))
			elif _is_number(timer) and window[1] >= timer:
				err.call(epath + ".window", "max %s must be below timer_seconds %s" % [str(window[1]), str(timer)])
			else:
				window_ok = true
		var duration: Variant = ev.get("duration_s")
		if ev.has("duration_s") and (not _is_number(duration) or duration <= 0):
			err.call(epath + ".duration_s", "must be a number > 0")
		var params: Variant = ev.get("params", {})
		if not params is Dictionary:
			err.call(epath + ".params", "must be an object")
			params = {}
		elif spec is Dictionary:
			_check_params(params, spec.get("params", {}), epath, err)
		norm_events.append({
			"id": str(ev.get("id", "")),
			"type": str(etype),
			"window": [float(window[0]), float(window[1])] if window_ok else [0.0, 0.0],
			"duration_s": float(duration) if _is_number(duration) else 0.0,
			"params": params.duplicate(true),
		})

	var norm_prompts := _check_prompts(data.get("prompts", []), messages, err) if data.has("prompts") else []

	var reserved := {PLAYER: true}
	for key in modifier_grammar:
		reserved[key] = true
	for key in types:
		reserved[key] = true
	var seen := {}
	for entry in ids:
		var value: String = entry[1]
		if seen.has(value):
			err.call(entry[0], "duplicate id %s (also at %s)" % [value, seen[value]])
		else:
			seen[value] = entry[0]
		if reserved.has(value):
			err.call(entry[0], "id %s is a reserved word" % value)

	if not errors.is_empty():
		return {"ok": false, "def": null, "errors": errors}
	var def := LevelDef.new()
	def.id = level_id
	def.title_key = data["title_key"]
	def.theme = data["theme"]
	def.music = data["music"]
	def.level_seed = data["seed"]
	def.timer_seconds = float(timer)
	def.three_star_share = float(data["three_star_share"]) if data.has("three_star_share") else -1.0
	def.tasks = norm_tasks
	def.events = norm_events
	def.prompts.assign(norm_prompts)
	return {"ok": true, "def": def, "errors": errors}


static func _check_prompts(raw: Variant, messages: Dictionary, err: Callable) -> Array:
	var out: Array = []
	if not raw is Array:
		err.call("prompts", "must be a list")
		return out
	if _anchor_re == null:
		_anchor_re = RegEx.create_from_string(ANCHOR_PATTERN)
	var seen := {}
	for i in raw.size():
		var prompt: Variant = raw[i]
		var ppath := "prompts[%d]" % i
		if not prompt is Dictionary:
			err.call(ppath, "must be an object")
			continue
		_check_keys(prompt, PROMPT_FIELDS, [], ppath, err)
		var pid: Variant = prompt.get("id")
		if prompt.has("id"):
			if not _is_name(pid):
				err.call(ppath + ".id", "must match %s" % ID_PATTERN)
			elif seen.has(pid):
				err.call(ppath + ".id", "duplicate prompt id %s (also at %s)" % [pid, seen[pid]])
			else:
				seen[pid] = ppath
		var anchor: Variant = prompt.get("anchor")
		if prompt.has("anchor") and (not anchor is String or _anchor_re.search(anchor) == null):
			err.call(ppath + ".anchor", "must be player, zone:<name> or entity:<uid>, got %s" % str(anchor))
		var action: Variant = prompt.get("action")
		if prompt.has("action") and not PROMPT_ACTIONS.has(action):
			err.call(ppath + ".action", "unknown action %s (one of %s)" % [str(action), ", ".join(PROMPT_ACTIONS)])
		if prompt.has("text_key"):
			_check_text_key(prompt["text_key"], ppath + ".text_key", messages, err)
		out.append({"id": str(pid), "anchor": str(anchor), "action": str(action),
				"text_key": str(prompt.get("text_key", ""))})
	return out


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"data": null, "errors": ["%s: cannot read" % path.get_file()]}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"data": null, "errors": ["%s:%d: invalid JSON (%s)" % [path.get_file(), json.get_error_line(),
				json.get_error_message()]]}
	return {"data": BalanceScript.normalize_json(json.data), "errors": []}


static func _is_name(v: Variant) -> bool:
	if not v is String:
		return false
	if _id_re == null:
		_id_re = RegEx.create_from_string(ID_PATTERN)
	return _id_re.search(v) != null


static func _is_number(v: Variant) -> bool:
	return v is int or v is float


static func _check_keys(obj: Dictionary, required: Array, optional: Array, path: String, err: Callable) -> void:
	for key in required:
		if not obj.has(key):
			err.call(_join(path, key), "missing")
	for key in obj:
		if not required.has(key) and not optional.has(key):
			err.call(_join(path, str(key)), "unknown field")


static func _join(path: String, key: String) -> String:
	return key if path == "" else "%s.%s" % [path, key]


static func _check_text_key(value: Variant, path: String, messages: Dictionary, err: Callable) -> void:
	if not value is String or value.strip_edges() == "":
		err.call(path, "must be a non-empty text key")
		return
	if not messages.has(value):
		err.call(path, "text key %s not found in the i18n catalogue" % value)
		return
	var entry: Dictionary = messages[value]
	if str(entry.get("en", "")).strip_edges() == "":
		err.call(path, "EN text missing or empty for %s" % value)
	if str(entry.get("de", "")).strip_edges() == "":
		err.call(path, "DE text missing or empty for %s" % value)


static func _check_condition(cond: Variant, path: String, grammar: Dictionary, timer: Variant, event_ids: Dictionary,
		err: Callable, kinds: Dictionary = {}) -> void:
	if not cond is Dictionary:
		err.call(path, "must be an object")
		return
	var ctype: Variant = cond.get("type")
	if not ctype is String or not grammar.has(ctype):
		err.call(path + ".type", "unknown condition type %s" % str(ctype))
		return
	var required: Dictionary = grammar[ctype][0]
	var optional: Dictionary = grammar[ctype][1]
	for key in required:
		if not cond.has(key):
			err.call("%s.%s" % [path, key], "missing")
	for key in cond:
		if key != "type" and not required.has(key) and not optional.has(key):
			err.call("%s.%s" % [path, key], "unknown field")
	var fields := required.duplicate()
	fields.merge(optional)
	for key in fields:
		if not cond.has(key):
			continue
		var value: Variant = cond[key]
		var fpath := "%s.%s" % [path, key]
		match fields[key]:
			"name":
				if not _is_name(value):
					err.call(fpath, "must match %s" % ID_PATTERN)
			"count":
				if not value is int or value < 1:
					err.call(fpath, "count must be an integer >= 1")
			"seconds":
				if not _is_number(value) or value <= 0 or (_is_number(timer) and value > timer):
					err.call(fpath, "before_time seconds must be > 0 and <= timer_seconds")
			"event":
				if not event_ids.has(value):
					err.call(fpath, "before_event must name an event of this level, got %s" % str(value))
	if kinds.is_empty():
		return
	for key in ENTITY_FIELDS.get(ctype, []):
		var name: Variant = cond.get(key)
		if _is_name(name) and name != PLAYER and not kinds.has(name):
			err.call("%s.%s" % [path, key], "unknown entity kind %s (not in data/animals.json or data/items.json)" % name)


static func _check_params(params: Dictionary, specs: Dictionary, path: String, err: Callable) -> void:
	for pname in specs:
		var pspec: Variant = specs[pname]
		if pspec is Dictionary and pspec.get("required", false) and not params.has(pname):
			err.call("%s.params.%s" % [path, pname], "missing required parameter")
	for pname in params:
		if not specs.has(pname) or not specs[pname] is Dictionary:
			err.call("%s.params.%s" % [path, pname], "unknown parameter")
			continue
		var ptype: Variant = specs[pname].get("type")
		var value: Variant = params[pname]
		var ok: bool = (ptype == "string" and value is String) or (ptype == "int" and value is int) \
				or (ptype == "float" and _is_number(value)) or (ptype == "bool" and value is bool)
		if not ok:
			err.call("%s.params.%s" % [path, pname], "must be of type %s" % str(ptype))


static func _counting(conds: Array) -> Array:
	var found: Array = []
	for c in conds:
		if c is Dictionary and CONDITIONS.has(c.get("type")) and c.get("count") is int and c["count"] > 1:
			found.append(c)
	return found
