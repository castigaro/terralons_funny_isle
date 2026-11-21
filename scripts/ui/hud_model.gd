class_name HudModel
extends RefCounted
## Pure HUD logic without nodes: time format, warning and star-goal checks, hint selection, failure cue
## classification from data/hud.json and the cue throttle. The Hud scene feeds it EventBus signals.

const CONFIG_PATH := "res://data/hud.json"
const FORMAT_VERSION := 1
const NO_HINT_KEY := "hud.hint.none"
const KIND_CLASSES := ["animal", "item"]
const TRIGGER_FIELDS := ["signal", "kind_class", "reasons", "effects"]
const SECONDS_PER_MINUTE := 60
const EPSILON := 0.000001
## Signal that ends a dismissible prompt -> the prompt action it stands for.
const DISMISS_ACTIONS := {
	"castaway_step": "move",
	"castaway_dashed": "dash",
	"object_grabbed": "grab",
	"object_thrown": "throw",
	"object_used": "use",
}

var _failure_types: Dictionary = {}
var _priority: Array = []
var _animals: Dictionary = {}
var _items: Dictionary = {}
var _event_effects: Dictionary = {}
var _def_tasks: Array = []


## failure_cfg is the parsed data/hud.json; event_effects maps a scheduled event id to its effect list.
func _init(failure_cfg: Dictionary = {}, animal_kinds: Array = [], item_kinds: Array = [],
		event_effects: Dictionary = {}, def_tasks: Array = []) -> void:
	_failure_types = failure_cfg.get("failure_types", {})
	_priority = failure_cfg.get("priority", [])
	for kind in animal_kinds:
		_animals[String(kind)] = true
	for kind in item_kinds:
		_items[String(kind)] = true
	_event_effects = event_effects
	_def_tasks = def_tasks


# --- Pure helpers -----------------------------------------------------------------------------------------

## Countdown text m:ss, rounded up to the next whole second and never negative.
static func format_time(seconds: float) -> String:
	var whole := maxi(int(ceilf(seconds - EPSILON)), 0) if seconds > 0.0 else 0
	@warning_ignore("integer_division")
	var minutes := whole / SECONDS_PER_MINUTE
	return "%d:%02d" % [minutes, whole % SECONDS_PER_MINUTE]


## True in the last warn_seconds while the level is running (also after the required tasks are done).
static func is_warning(time_left: float, warn_seconds: float, state: int) -> bool:
	if state != LevelSession.State.RUNNING and state != LevelSession.State.REQUIRED_DONE:
		return false
	return time_left <= warn_seconds + EPSILON


static func star_goal_reachable(time_left: float, three_star_time: float) -> bool:
	return time_left + EPSILON >= three_star_time


## Hint key of the first open required task, else the first open optional task, else hud.hint.none.
## Done and missed (deadline passed) tasks are skipped; progress is LevelSession.task_progress().
static func select_hint(def_tasks: Array, progress: Array) -> String:
	var state := {}
	for entry in progress:
		state[String(entry.get("id", ""))] = entry
	for want_required in [true, false]:
		for task in def_tasks:
			if bool(task.get("required", false)) != want_required:
				continue
			var st: Dictionary = state.get(String(task.get("id", "")), {})
			if bool(st.get("done", false)) or bool(st.get("missed", false)):
				continue
			return String(task.get("hint_key", NO_HINT_KEY))
	return NO_HINT_KEY


## Title key of a task: title_key, or the hint key when a level has no titles.
static func task_title_key(task: Dictionary) -> String:
	var title := String(task.get("title_key", ""))
	return title if title != "" else String(task.get("hint_key", ""))


static func prompt_dismiss_action(signal_name: String) -> String:
	return String(DISMISS_ACTIONS.get(signal_name, ""))


## Reads and checks data/hud.json: returns {config: Dictionary, errors: Array}. bus provides the signal
## names, messages the i18n catalogue {key: {en, de}} (empty skips the key check).
static func load_config(path: String, bus: Object, messages: Dictionary) -> Dictionary:
	var fname := path.get_file()
	if not FileAccess.file_exists(path):
		return {"config": {}, "errors": ["%s: cannot read" % fname]}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {"config": {}, "errors": ["%s: invalid JSON" % fname]}
	var data: Dictionary = json.data
	return {"config": data, "errors": validate_config(data, bus, messages, fname)}


static func validate_config(data: Dictionary, bus: Object, messages: Dictionary, fname: String = "hud.json") -> Array:
	var errors: Array = []
	if int(data.get("format_version", 0)) != FORMAT_VERSION:
		errors.append("%s: format_version: must be %d" % [fname, FORMAT_VERSION])
	var types: Variant = data.get("failure_types")
	if not types is Dictionary or types.is_empty():
		errors.append("%s: failure_types: must be a non-empty object" % fname)
		types = {}
	for type_name in types:
		var spec: Variant = types[type_name]
		var path := "%s: failure_types.%s" % [fname, type_name]
		if not spec is Dictionary:
			errors.append("%s: must be an object" % path)
			continue
		_check_key(spec.get("key"), path + ".key", messages, errors)
		var icon: Variant = spec.get("icon")
		if not icon is String or not ResourceLoader.exists(icon):
			errors.append("%s.icon: missing texture %s" % [path, str(icon)])
		var triggers: Variant = spec.get("triggers")
		if not triggers is Array or triggers.is_empty():
			errors.append("%s.triggers: must be a non-empty list" % path)
			continue
		for i in triggers.size():
			_check_trigger(triggers[i], "%s.triggers[%d]" % [path, i], bus, errors)
	for type_name in data.get("priority", []):
		if not types.has(type_name):
			errors.append("%s: priority: unknown failure type %s" % [fname, str(type_name)])
	var verbs: Variant = data.get("verbs")
	if not verbs is Dictionary:
		errors.append("%s: verbs: must be an object" % fname)
	else:
		for verb in ["grab", "throw", "use"]:
			_check_key(verbs.get(verb), "%s: verbs.%s" % [fname, verb], messages, errors)
	return errors


static func _check_key(value: Variant, path: String, messages: Dictionary, errors: Array) -> void:
	if not value is String or value == "":
		errors.append("%s: must be a text key" % path)
	elif not messages.is_empty() and not messages.has(value):
		errors.append("%s: text key %s not in the i18n catalogue" % [path, value])


static func _check_trigger(trigger: Variant, path: String, bus: Object, errors: Array) -> void:
	if not trigger is Dictionary:
		errors.append("%s: must be an object" % path)
		return
	for key in trigger:
		if not TRIGGER_FIELDS.has(key):
			errors.append("%s.%s: unknown field" % [path, key])
	var sig: Variant = trigger.get("signal")
	if not sig is String or bus == null or not bus.has_signal(sig):
		errors.append("%s.signal: unknown EventBus signal %s" % [path, str(sig)])
	if trigger.has("kind_class") and not KIND_CLASSES.has(trigger["kind_class"]):
		errors.append("%s.kind_class: must be animal or item" % path)
	for effect in trigger.get("effects", []):
		if not LevelDef.EFFECTS.has(effect):
			errors.append("%s.effects: unknown effect %s" % [path, str(effect)])


# --- Classification -----------------------------------------------------------------------------------------

## Returns {} (no cue) or {type, key, icon} for an EventBus signal. ctx: player_held and player_worn kinds and
## progress (LevelSession.task_progress()) for the task fail_key override.
func classify(signal_name: String, args: Array, ctx: Dictionary = {}) -> Dictionary:
	for type_name in _failure_types:
		var spec: Dictionary = _failure_types[type_name]
		for trigger in spec.get("triggers", []):
			if String(trigger.get("signal", "")) != signal_name:
				continue
			var involved: Variant = _match(trigger, args, ctx)
			if involved == null:
				continue
			var key := String(spec.get("key", ""))
			var override := _task_fail_key(String(involved), ctx.get("progress", []))
			return {"type": String(type_name), "key": override if override != "" else key,
					"icon": String(spec.get("icon", ""))}
	return {}


## Returns null when the trigger does not match, else the involved entity kind ("" when none).
func _match(trigger: Dictionary, args: Array, ctx: Dictionary) -> Variant:
	var kind := String(args[0]) if not args.is_empty() and args[0] is String else ""
	if trigger.has("kind_class"):
		var pool: Dictionary = _animals if trigger["kind_class"] == "animal" else _items
		if not pool.has(kind):
			return null
	if trigger.has("reasons"):
		var reason := String(args[1]) if args.size() > 1 else ""
		if not trigger["reasons"].has(reason):
			return null
	if trigger.has("effects"):
		var effects: Array = _event_effects.get(kind, [])
		var held := String(ctx.get("player_held", ""))
		var worn := String(ctx.get("player_worn", ""))
		if trigger["effects"].has("take_held") and effects.has("take_held") and held != "":
			return held
		if trigger["effects"].has("take_worn") and effects.has("take_worn") and worn != "":
			return worn
		return null
	return kind if trigger.has("kind_class") else ""


func _task_fail_key(kind: String, progress: Array) -> String:
	if kind == "":
		return ""
	var open := {}
	for entry in progress:
		if not bool(entry.get("done", false)) and not bool(entry.get("missed", false)):
			open[String(entry.get("id", ""))] = true
	for want_required in [true, false]:
		for task in _def_tasks:
			if bool(task.get("required", false)) != want_required or not open.has(String(task.get("id", ""))):
				continue
			if _task_mentions(task, kind):
				return String(task.get("fail_key", ""))
	return ""


static func _task_mentions(task: Dictionary, kind: String) -> bool:
	for cond in task.get("conditions", []) + task.get("modifiers", []):
		for field in LevelDef.ENTITY_FIELDS.get(String(cond.get("type", "")), []):
			if String(cond.get(field, "")) == kind:
				return true
	return false


func is_priority(type_name: String) -> bool:
	return _priority.has(type_name)


## Effect lists per scheduled event id from a LevelSession schedule and the event type catalogue.
static func event_effects_for(schedule: Array, event_types: Dictionary) -> Dictionary:
	var out := {}
	for entry in schedule:
		var spec: Variant = event_types.get(String(entry.get("type", "")), {})
		out[String(entry.get("id", ""))] = spec.get("effects", []) if spec is Dictionary else []
	return out


## Keeps at most one cue visible: an identical key inside min_interval only extends the visible time, a different
## key replaces the visible one, and a priority cue (time's up) is never replaced while visible.
class CueThrottle:
	extends RefCounted

	enum Result { BLOCKED, SHOWN, MERGED }

	var seconds := 0.0
	var min_interval := 0.0
	var _key := ""
	var _priority := false
	var _shown_at := 0.0
	var _until := 0.0

	func _init(cue_seconds: float, cue_min_interval: float) -> void:
		seconds = cue_seconds
		min_interval = cue_min_interval

	func offer(key: String, now: float, priority: bool = false) -> int:
		var showing := visible_key(now)
		if showing != "" and _priority and key != showing:
			return Result.BLOCKED
		if showing == key and now - _shown_at < min_interval:
			_until = now + seconds
			return Result.MERGED
		_key = key
		_priority = priority
		_shown_at = now
		_until = now + seconds
		return Result.SHOWN

	func visible_key(now: float) -> String:
		return _key if _key != "" and now < _until else ""

	func clear() -> void:
		_key = ""
		_priority = false
		_until = 0.0
