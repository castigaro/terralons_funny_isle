class_name FeedbackMap
extends RefCounted
## Pure model of data/feedback.json: which visual entries every EventBus signal (and every event warning and
## start) plays. parse() applies the structural checks (known signals, effect and anchor enums, strength keys);
## tools/validate_feedback.py runs the full validation.

const FORMAT_VERSION := 1
const EFFECTS := ["popup", "splat", "puff", "particles", "emote", "shake", "flash", "hitstop", "squash", "recoil"]
const ANCHORS := ["auto", "screen", "follow", "event_zone"]
const ENTRY_KEYS := ["effect", "anchor", "strength", "asset", "frames", "frame_count", "word", "material", "offset"]
const SIGNAL_KEYS := ["variant_arg", "default", "variants"]
const TOP_KEYS := ["format_version", "materials", "no_visual", "signals", "events"]
const PHASES := ["warning", "start"]
## Signals whose visuals also come from the events section (phase per signal).
const EVENT_SIGNALS := {"event_warning": "warning", "event_triggered": "start"}
const SIGNAL_DECL_PATTERN := "(?m)^signal\\s+(\\w+)\\s*\\(([^)]*)\\)"

var signals := {}
var events := {}
var materials := {}
var _no_visual := {}
var _arg_names := {}


## Loads and checks a feedback file; decls is custom_signals() of the EventBus, strengths the balance section
## "strengths". Returns {map: FeedbackMap, errors: Array}.
static func parse(path: String, decls: Array, strengths: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"map": FeedbackMap.new(), "errors": ["%s: missing" % path]}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"map": FeedbackMap.new(), "errors": ["%s:%d: %s" % [path, json.get_error_line(),
				json.get_error_message()]]}
	return from_data(json.data, decls, strengths)


static func from_data(data: Variant, decls: Array, strengths: Dictionary) -> Dictionary:
	var map := FeedbackMap.new()
	var errors: Array = []
	if not data is Dictionary:
		return {"map": map, "errors": ["top level must be an object"]}
	var d: Dictionary = data
	for key in d:
		if not TOP_KEYS.has(key):
			errors.append("unknown top-level key %s" % key)
	if int(d.get("format_version", 0)) != FORMAT_VERSION:
		errors.append("format_version must be %d" % FORMAT_VERSION)
	var known := {}
	for decl in decls:
		known[decl["name"]] = true
		map._arg_names[decl["name"]] = decl["args"]
	var mats: Variant = d.get("materials", {})
	if mats is Dictionary:
		for name in mats:
			map.materials[name] = Color.from_string(str(mats[name]), Color.WHITE)
	var nv: Variant = d.get("no_visual", {})
	if nv is Dictionary:
		map._no_visual = (nv as Dictionary).duplicate()
	for name in map._no_visual:
		if not known.has(name):
			errors.append("no_visual.%s: not an EventBus signal" % name)
	var sigs: Variant = d.get("signals", {})
	if sigs is Dictionary:
		for name in sigs:
			if not known.has(name):
				errors.append("signals.%s: not an EventBus signal" % name)
				continue
			if map._no_visual.has(name):
				errors.append("signals.%s: also listed in no_visual" % name)
			var spec: Variant = sigs[name]
			if not spec is Dictionary:
				errors.append("signals.%s: must be an object" % name)
				continue
			for key in spec:
				if not SIGNAL_KEYS.has(key):
					errors.append("signals.%s.%s: unknown key" % [name, key])
			var variant_arg := str(spec.get("variant_arg", ""))
			if variant_arg != "" and not map._arg_names[name].has(variant_arg):
				errors.append("signals.%s.variant_arg: %s is not an argument" % [name, variant_arg])
			_check_entries(spec.get("default", []), "signals.%s.default" % name, map, strengths, errors)
			var variants: Variant = spec.get("variants", {})
			if variants is Dictionary:
				for value in variants:
					_check_entries(variants[value], "signals.%s.variants.%s" % [name, value], map, strengths,
							errors)
			map.signals[name] = spec
	var evs: Variant = d.get("events", {})
	if evs is Dictionary:
		for type in evs:
			var spec: Variant = evs[type]
			if not spec is Dictionary:
				errors.append("events.%s: must be an object" % type)
				continue
			for phase in spec:
				if not PHASES.has(phase):
					errors.append("events.%s.%s: unknown phase" % [type, phase])
					continue
				_check_entries(spec[phase], "events.%s.%s" % [type, phase], map, strengths, errors)
			map.events[type] = spec
	for decl in decls:
		var name: String = decl["name"]
		if not map.signals.has(name) and not map._no_visual.has(name) and not EVENT_SIGNALS.has(name):
			errors.append("signal %s is neither mapped nor listed in no_visual" % name)
	return {"map": map, "errors": errors}


static func _check_entries(entries: Variant, where: String, map: FeedbackMap, strengths: Dictionary,
		errors: Array) -> void:
	if not entries is Array:
		errors.append("%s: must be a list" % where)
		return
	for i in entries.size():
		var entry: Variant = entries[i]
		var at := "%s[%d]" % [where, i]
		if not entry is Dictionary:
			errors.append("%s: must be an object" % at)
			continue
		for key in entry:
			if not ENTRY_KEYS.has(key):
				errors.append("%s.%s: unknown key" % [at, key])
		var effect := str(entry.get("effect", ""))
		if not EFFECTS.has(effect):
			errors.append("%s.effect: unknown effect %s" % [at, effect])
			continue
		var anchor := str(entry.get("anchor", "auto"))
		if not ANCHORS.has(anchor):
			errors.append("%s.anchor: unknown anchor %s" % [at, anchor])
		var strength := str(entry.get("strength", ""))
		var group: Variant = strengths.get(effect, {})
		if not group is Dictionary or not (group as Dictionary).has(strength):
			errors.append("%s.strength: strengths.%s.%s missing" % [at, effect, strength])
		var material := str(entry.get("material", ""))
		if material != "" and not map.materials.has(material):
			errors.append("%s.material: unknown material %s" % [at, material])


## Returns [{name, argc, args: [names]}] of the signals the script itself declares (no Node built-ins).
static func custom_signals(script: Script) -> Array:
	var out: Array = []
	for s in script.get_script_signal_list():
		var args: Array = []
		for a in s["args"]:
			args.append(String(a["name"]))
		out.append({"name": String(s["name"]), "argc": args.size(), "args": args})
	return out


## Parses "signal name(args)" declarations from source text with the same pattern as validate_feedback.py.
static func parse_signal_decls(text: String) -> Array:
	var re := RegEx.new()
	re.compile(SIGNAL_DECL_PATTERN)
	var out: Array = []
	for m in re.search_all(text):
		var args: Array = []
		for part in m.get_string(2).split(",", false):
			var arg_name := part.strip_edges().get_slice(":", 0).strip_edges()
			if arg_name != "":
				args.append(arg_name)
		out.append({"name": m.get_string(1), "argc": args.size(), "args": args})
	return out


## Visual entries of a signal for the given arguments (variant chosen by the variant_arg value).
func entries_for(signal_name: String, args: Array) -> Array:
	var spec: Dictionary = signals.get(signal_name, {})
	if spec.is_empty():
		return []
	var variant_arg := str(spec.get("variant_arg", ""))
	if variant_arg != "":
		var idx: int = _arg_names.get(signal_name, []).find(variant_arg)
		var variants: Dictionary = spec.get("variants", {})
		if idx >= 0 and idx < args.size() and variants.has(str(args[idx])):
			return variants[str(args[idx])]
	return spec.get("default", [])


## Visual entries of an event type for phase "warning" or "start".
func event_entries(type: String, phase: String) -> Array:
	var spec: Dictionary = events.get(type, {})
	return spec.get(phase, [])


func is_no_visual(signal_name: String) -> bool:
	return _no_visual.has(signal_name)


func no_visual() -> Dictionary:
	return _no_visual.duplicate()


func is_mapped(signal_name: String) -> bool:
	return signals.has(signal_name) or EVENT_SIGNALS.has(signal_name)


func material_color(name: String) -> Color:
	return materials.get(name, Color.WHITE)


## Every entry of the file (signals with variants and events), for preloading and tests.
func all_entries() -> Array:
	var out: Array = []
	for name in signals:
		out.append_array(signals[name].get("default", []))
		var variants: Dictionary = signals[name].get("variants", {})
		for value in variants:
			out.append_array(variants[value])
	for type in events:
		for phase in events[type]:
			out.append_array(events[type][phase])
	return out
