class_name AudioMap
extends RefCounted
## Loads and validates data/audio.json and resolves EventBus signals to sounds, jingles and announcer lines.

const DEFAULT_PATH := "res://data/audio.json"
const DENY_PATH := "res://data/assets/deny_list.json"
const LEVELS_DIR := "res://data/levels"
const FORMAT_VERSION := 1
const SECTIONS := ["music", "sfx", "pitch", "signals", "jingles", "announcer", "ignored"]
const SIGNAL_SPECIAL := ["jingle", "announcer"]
const DEFAULT_KEY := "default"

var music := {}
var sfx := {}
var pitch := {}
var signals := {}
var jingles := {}
var announcer := {}
var ignored := {}
var _errors: Array = []


## Reads and checks the structure of an audio map file; errors() lists the problems.
static func load_file(path: String = DEFAULT_PATH) -> AudioMap:
	var map := AudioMap.new()
	if not FileAccess.file_exists(path):
		map._errors.append("%s: missing" % path)
		return map
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		map._errors.append("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return map
	map.apply(json.data, path.get_file())
	return map


## Fills the map from parsed data and records structural errors.
func apply(data: Variant, label: String = "audio.json") -> void:
	if not data is Dictionary:
		_errors.append("%s: top level must be an object" % label)
		return
	if not (data.get("format_version") is float or data.get("format_version") is int) \
			or int(data["format_version"]) != FORMAT_VERSION:
		_errors.append("%s: format_version must be %d" % [label, FORMAT_VERSION])
	for section in SECTIONS:
		if not data.get(section) is Dictionary:
			_errors.append("%s: %s must be an object" % [label, section])
	music = _dict(data, "music")
	sfx = _dict(data, "sfx")
	pitch = _dict(data, "pitch")
	signals = _dict(data, "signals")
	jingles = _dict(data, "jingles")
	announcer = _dict(data, "announcer")
	ignored = _dict(data, "ignored")
	for id in sfx:
		var spec: Variant = sfx[id]
		if not spec is Dictionary or not spec.get("files") is Array or spec["files"].is_empty():
			_errors.append("%s: sfx.%s needs a non-empty files list" % [label, id])
	for sig in signals:
		var entry: Variant = signals[sig]
		if not entry is Dictionary:
			_errors.append("%s: signals.%s must be an object" % [label, sig])
			continue
		for key in entry:
			var target := String(entry[key])
			if key == "jingle":
				if not jingles.has(target):
					_errors.append("%s: signals.%s.jingle: unknown jingle %s" % [label, sig, target])
			elif key == "announcer":
				if not announcer.has(target):
					_errors.append("%s: signals.%s.announcer: unknown line %s" % [label, sig, target])
			elif not sfx.has(target):
				_errors.append("%s: signals.%s.%s: unknown sfx %s" % [label, sig, key, target])
	for line in announcer:
		var spec: Variant = announcer[line]
		if not spec is Dictionary or not spec.get("file") is String or not spec.get("caption") is String:
			_errors.append("%s: announcer.%s needs file and caption" % [label, line])


static func _dict(data: Dictionary, key: String) -> Dictionary:
	var v: Variant = data.get(key, {})
	return v if v is Dictionary else {}


func errors() -> Array:
	return _errors.duplicate()


func music_ids() -> Array:
	var ids := music.keys()
	ids.sort()
	return ids


## res:// path of a music id, or "" when unknown.
func music_path(id: String) -> String:
	return "res://" + String(music[id]) if music.has(id) else ""


## res:// paths of the variants of a sound.
func sfx_paths(sound_id: String) -> Array:
	var paths: Array = []
	var spec: Variant = sfx.get(sound_id, {})
	if spec is Dictionary:
		for f in spec.get("files", []):
			paths.append("res://" + String(f))
	return paths


func sfx_volume_db(sound_id: String) -> float:
	var spec: Variant = sfx.get(sound_id, {})
	return float(spec.get("volume_db", 0.0)) if spec is Dictionary else 0.0


func sfx_pitch(sound_id: String) -> float:
	var spec: Variant = sfx.get(sound_id, {})
	return float(spec.get("pitch", 1.0)) if spec is Dictionary else 1.0


func jingle_path(id: String) -> String:
	return "res://" + String(jingles[id]) if jingles.has(id) else ""


func announcer_path(line_id: String) -> String:
	var spec: Variant = announcer.get(line_id, {})
	return "res://" + String(spec.get("file", "")) if spec is Dictionary and spec.has("file") else ""


func announcer_caption(line_id: String) -> String:
	var spec: Variant = announcer.get(line_id, {})
	return String(spec.get("caption", "")) if spec is Dictionary else ""


func has_signal_entry(signal_name: String) -> bool:
	return signals.has(signal_name)


## Resolves a signal: {sfx, pitch, jingle, announcer, mapped}. The first String argument that is a key of the
## entry refines the sound (surface, kind, reason, event type), else "default"; pitch comes from the first String
## argument that names a kind in "pitch" times the sound's own pitch.
func resolve(signal_name: String, args: Array) -> Dictionary:
	var out := {"sfx": "", "pitch": 1.0, "jingle": "", "announcer": "", "mapped": signals.has(signal_name)}
	var entry: Variant = signals.get(signal_name)
	if not entry is Dictionary:
		return out
	var sound := ""
	for arg in args:
		if (arg is String or arg is StringName) and not SIGNAL_SPECIAL.has(String(arg)) \
				and String(arg) != DEFAULT_KEY and entry.has(String(arg)):
			sound = String(entry[String(arg)])
			break
	if sound == "":
		sound = String(entry.get(DEFAULT_KEY, ""))
	out["sfx"] = sound
	var kind_pitch := 1.0
	for arg in args:
		if (arg is String or arg is StringName) and pitch.has(String(arg)):
			kind_pitch = float(pitch[String(arg)])
			break
	out["pitch"] = kind_pitch * (sfx_pitch(sound) if sound != "" else 1.0)
	out["jingle"] = String(entry.get("jingle", ""))
	out["announcer"] = String(entry.get("announcer", ""))
	return out


## Every repo-relative asset path referenced by the map.
func all_files() -> Array:
	var files: Array = []
	for id in music:
		files.append(String(music[id]))
	for id in sfx:
		var spec: Variant = sfx[id]
		if spec is Dictionary:
			for f in spec.get("files", []):
				files.append(String(f))
	for id in jingles:
		files.append(String(jingles[id]))
	for id in announcer:
		var spec: Variant = announcer[id]
		if spec is Dictionary and spec.has("file"):
			files.append(String(spec["file"]))
	return files


## Full check against the running game: bus signals mapped or ignored with a reason, kinds and event types
## resolvable, files existing, imported, outside .gdignore folders and free of deny-list tokens.
func validate(bus_signals: Array, animal_kinds: Array, event_types: Array, deny_tokens: Array = []) -> Array:
	var errs := errors()
	for sig in bus_signals:
		if signals.has(sig):
			continue
		if not ignored.has(sig):
			errs.append("signal %s is neither mapped nor ignored" % sig)
		elif String(ignored[sig]).strip_edges() == "":
			errs.append("ignored signal %s needs a reason" % sig)
	for sig in signals:
		if not bus_signals.has(sig):
			errs.append("signals.%s is not an EventBus signal" % sig)
	for sig in ignored:
		if String(ignored[sig]).strip_edges() == "":
			errs.append("ignored signal %s needs a reason" % sig)
	for sig in signals:
		if not String(sig).begins_with("animal_"):
			continue
		for kind in animal_kinds:
			if resolve(sig, [kind])["sfx"] == "":
				errs.append("signals.%s: animal %s has no sound" % [sig, kind])
	for kind in animal_kinds:
		if not pitch.has(kind):
			errs.append("pitch: animal %s has no pitch" % kind)
	if signals.has("event_triggered"):
		for type in event_types:
			if resolve("event_triggered", [type])["sfx"] == "":
				errs.append("signals.event_triggered: event type %s has no sound" % type)
	for f in all_files():
		errs.append_array(file_problems(f, deny_tokens))
	return errs


## Problems of one referenced asset file (repo-relative path).
static func file_problems(rel: String, deny_tokens: Array) -> Array:
	var errs: Array = []
	var path := "res://" + rel
	if not rel.begins_with("assets/"):
		errs.append("%s: must be below assets/" % rel)
	if not FileAccess.file_exists(path):
		errs.append("%s: file missing" % rel)
		return errs
	if not FileAccess.file_exists(path + ".import"):
		errs.append("%s: not imported (no .import file)" % rel)
	var dir := path.get_base_dir()
	while dir.begins_with("res://assets"):
		if FileAccess.file_exists(dir.path_join(".gdignore")):
			errs.append("%s: inside a .gdignore folder" % rel)
			break
		dir = dir.get_base_dir()
	var hit := deny_hit(rel.get_file(), deny_tokens)
	if hit != "":
		errs.append("%s: matches deny-list token %s" % [rel, hit])
	return errs


## Reads the deny-list tokens of data/assets/deny_list.json.
static func load_deny_tokens(path: String = DENY_PATH) -> Array:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return []
	var tokens: Variant = json.data.get("tokens", [])
	return tokens if tokens is Array else []


## The first deny token whose word sequence occurs in the file name (camelCase and separators split words).
static func deny_hit(file_name: String, deny_tokens: Array) -> String:
	var words := split_words(file_name.get_basename())
	for token in deny_tokens:
		var seq := String(token).to_lower().split("_", false)
		for i in range(words.size() - seq.size() + 1):
			var same := true
			for j in seq.size():
				if words[i + j] != seq[j]:
					same = false
					break
			if same:
				return String(token)
	return ""


static func split_words(text: String) -> Array:
	var re := RegEx.new()
	re.compile("[A-Z]?[a-z]+|[A-Z]+(?![a-z])|[0-9]+")
	var words: Array = []
	for m in re.search_all(text):
		words.append(m.get_string().to_lower())
	return words


## Reads the music id and the event types {event id: type} of a level file; {} when the file is missing.
static func level_info(level_id: String, dir: String = LEVELS_DIR) -> Dictionary:
	var path := dir.path_join(level_id + ".json")
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {}
	var types := {}
	var events: Variant = json.data.get("events", [])
	if events is Array:
		for ev in events:
			if ev is Dictionary and ev.get("id") is String and ev.get("type") is String:
				types[ev["id"]] = ev["type"]
	var tune: Variant = json.data.get("music", "")
	return {"music": tune if tune is String else "", "event_types": types}


## Music id of a level file, or "" when the file or the field is missing.
static func music_for_level(level_id: String, dir: String = LEVELS_DIR) -> String:
	return String(level_info(level_id, dir).get("music", ""))
