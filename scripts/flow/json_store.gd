class_name JsonStore
extends RefCounted
## Small JSON file store for settings.json and progress.json: tolerant reads and atomic writes (temp file plus
## rename). Failures are reported with push_warning and an Error code; the game keeps running.

const STATUS_OK := "ok"
const STATUS_MISSING := "missing"
const STATUS_EMPTY := "empty"
const STATUS_CORRUPT := "corrupt"
const TMP_SUFFIX := ".tmp"


## Reads a JSON file: {status: ok|missing|empty|corrupt, data: Variant (null unless ok)}.
static func read(path: String) -> Dictionary:
	var abs_path := _globalize(path)
	if abs_path == "" or not FileAccess.file_exists(abs_path):
		return {"status": STATUS_MISSING, "data": null}
	var text := FileAccess.get_file_as_string(abs_path)
	if text.strip_edges() == "":
		return {"status": STATUS_EMPTY, "data": null}
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("JsonStore: %s is not valid JSON (line %d), using defaults" % [path, json.get_error_line()])
		return {"status": STATUS_CORRUPT, "data": null}
	return {"status": STATUS_OK, "data": json.data}


## Writes data as JSON to path + ".tmp" and renames it over path; returns OK or the failing Error code.
static func write_atomic(path: String, data: Variant) -> Error:
	var abs_path := _globalize(path)
	if abs_path == "":
		push_warning("JsonStore: empty path")
		return ERR_FILE_BAD_PATH
	var dir := abs_path.get_base_dir()
	if FileAccess.file_exists(dir):
		push_warning("JsonStore: cannot write %s, %s is a file" % [path, dir])
		return ERR_FILE_BAD_PATH
	if not DirAccess.dir_exists_absolute(dir):
		var made := DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			push_warning("JsonStore: cannot create folder %s (%s)" % [dir, error_string(made)])
			return made
	var tmp := abs_path + TMP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		var open_err := FileAccess.get_open_error()
		push_warning("JsonStore: cannot write %s (%s)" % [tmp, error_string(open_err)])
		return open_err
	f.store_string(JSON.stringify(data, "\t") + "\n")
	f.close()
	var err := DirAccess.rename_absolute(tmp, abs_path)
	if err != OK and FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)
		err = DirAccess.rename_absolute(tmp, abs_path)
	if err != OK:
		push_warning("JsonStore: cannot replace %s (%s)" % [path, error_string(err)])
		DirAccess.remove_absolute(tmp)
	return err


static func _globalize(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("user://") else path
