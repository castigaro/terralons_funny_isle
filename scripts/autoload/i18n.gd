extends Node
## Loads every i18n/<area>.csv (columns key,en,de) into the TranslationServer; English is the default locale.

signal locale_changed(code: String)

const I18N_DIR := "res://i18n"
const LOCALES := ["en", "de"]
const DEFAULT_LOCALE := "en"
const HEADER := ["key", "en", "de"]

## Locale active right after startup (recorded for tests).
var startup_locale := ""
var _messages := {}
var _errors: Array = []
var _translations: Array = []


func _ready() -> void:
	var parsed := parse_dir(I18N_DIR)
	_messages = parsed["messages"]
	_errors = parsed["errors"]
	for err in _errors:
		push_error("I18n: %s" % err)
	_install()
	set_locale(DEFAULT_LOCALE)
	startup_locale = TranslationServer.get_locale()


func _install() -> void:
	for old in _translations:
		TranslationServer.remove_translation(old)
	_translations.clear()
	for loc in LOCALES:
		var res := Translation.new()
		res.locale = loc
		for key in _messages:
			res.add_message(key, _messages[key][loc])
		TranslationServer.add_translation(res)
		_translations.append(res)


## Pure loader for res:// or absolute folders: returns {messages: {key: {en, de, file}}, errors: Array}.
static func parse_dir(path: String) -> Dictionary:
	var messages := {}
	var errors: Array = []
	if not DirAccess.dir_exists_absolute(path):
		errors.append("missing folder %s" % path)
		return {"messages": messages, "errors": errors}
	var names := Array(DirAccess.get_files_at(path))
	names.sort()
	for name in names:
		if name.get_extension() != "csv":
			continue
		var file_path: String = path.path_join(name)
		var raw := FileAccess.get_file_as_bytes(file_path)
		if raw.size() >= 3 and raw[0] == 0xEF and raw[1] == 0xBB and raw[2] == 0xBF:
			errors.append("%s: UTF-8 BOM is not allowed" % name)
			continue
		var fa := FileAccess.open(file_path, FileAccess.READ)
		if fa == null:
			errors.append("%s: cannot open" % name)
			continue
		var header := Array(fa.get_csv_line())
		if header != HEADER:
			errors.append("%s: header must be key,en,de" % name)
			continue
		var line_no := 1
		while not fa.eof_reached():
			var row := fa.get_csv_line()
			line_no += 1
			if row.size() == 1 and row[0].strip_edges() == "":
				continue
			if row.size() != 3:
				errors.append("%s:%d: expected 3 columns, got %d" % [name, line_no, row.size()])
				continue
			var key := row[0].strip_edges()
			if key == "":
				errors.append("%s:%d: empty key" % [name, line_no])
				continue
			if messages.has(key):
				errors.append("%s:%d: duplicate key %s (also in %s)" % [name, line_no, key, messages[key]["file"]])
				continue
			if row[1].strip_edges() == "" or row[2].strip_edges() == "":
				errors.append("%s:%d: empty text for %s" % [name, line_no, key])
			messages[key] = {"en": row[1], "de": row[2], "file": name}
	return {"messages": messages, "errors": errors}


## Translates a key and fills {placeholders}; a Dictionary arg {key, args} renders as its own translation and
## an Array arg as its rendered elements joined by ", ", so stored messages follow a language switch.
func t(key: String, args: Dictionary = {}) -> String:
	var text := String(TranslationServer.translate(key))
	if args.is_empty():
		return text
	var resolved := {}
	for arg_name in args:
		resolved[arg_name] = _resolve_arg(args[arg_name])
	return text.format(resolved)


func _resolve_arg(value: Variant) -> Variant:
	if value is Dictionary:
		var ref_key: Variant = value.get("key")
		if ref_key is String or ref_key is StringName:
			var nested: Variant = value.get("args", {})
			return t(String(ref_key), nested if nested is Dictionary else {})
		return value
	if value is Array:
		var parts := PackedStringArray()
		for element in value:
			parts.append(str(_resolve_arg(element)))
		return ", ".join(parts)
	return value


func has_key(key: String) -> bool:
	return _messages.has(key)


## Returns the text of a key in a given locale without switching ("" if missing).
func text_in(key: String, locale: String) -> String:
	if not _messages.has(key):
		return ""
	return _messages[key].get(locale, "")


func keys() -> Array:
	var all := _messages.keys()
	all.sort()
	return all


func last_errors() -> Array:
	return _errors.duplicate()


## Switches the active locale ("en" or "de") and always emits locale_changed.
func set_locale(code: String) -> void:
	TranslationServer.set_locale(code)
	locale_changed.emit(code)


func get_locale() -> String:
	return TranslationServer.get_locale()


func apply_default_locale() -> void:
	set_locale(DEFAULT_LOCALE)
