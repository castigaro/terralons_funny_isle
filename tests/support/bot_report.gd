extends RefCounted
## Per-level bot summary files below the testdata folder: <dir>/<level_id>.json = {level, runs: [...]}.
## A run with the same (variant, mode, seed) replaces its old entry; nothing is ever deleted. Each stored run gets
## written_at (Unix seconds), so tools/run_tests.py can tell the runs of the current test run from older ones.

const ENV_DIR := "TFI_BOT_REPORT_DIR"
const ENV_DATA_DIR := "TFI_DATA_DIR"
const VARIANT_ORDER := ["plain", "hold", "inject", "finish_off", "determinism"]
## Entry fields that are whole numbers (JSON reads every number back as float).
const INT_KEYS := ["seed", "tasks_done", "tasks_total", "stars", "respawns", "throws", "finish_presses"]


## The report folder, or "" when none is configured or it would lie inside the project or user:// folder.
static func report_dir() -> String:
	var dir := OS.get_environment(ENV_DIR)
	if dir == "":
		var data_dir := OS.get_environment(ENV_DATA_DIR)
		if data_dir != "":
			dir = data_dir.replace("\\", "/").trim_suffix("/").get_base_dir() + "/bot"
	if dir == "" or not is_allowed_dir(dir):
		print("bot report skipped")
		return ""
	return dir.replace("\\", "/").trim_suffix("/")


## False for a path inside res:// or user://.
static func is_allowed_dir(dir: String) -> bool:
	var norm := dir.replace("\\", "/").trim_suffix("/").to_lower()
	if norm.begins_with("res://") or norm.begins_with("user://"):
		return false
	for root in [ProjectSettings.globalize_path("res://"), ProjectSettings.globalize_path("user://")]:
		var r := String(root).replace("\\", "/").trim_suffix("/").to_lower()
		if r != "" and (norm == r or norm.begins_with(r + "/")):
			return false
	return true


## Writes or replaces the run of entry in <dir>/<level_id>.json; returns the file path or "".
static func upsert(level_id: String, entry: Dictionary, dir: String = "") -> String:
	if dir == "":
		dir = report_dir()
	if dir == "" or not is_allowed_dir(dir):
		return ""
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%s.json" % [dir, level_id]
	var data := {"level": level_id, "runs": []}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.get("runs") is Array:
			data = parsed
	var runs: Array = []
	for run in data["runs"]:
		if run is Dictionary and not _same_key(run, entry):
			for key in INT_KEYS:
				if run.has(key):
					run[key] = int(run[key])
			runs.append(run)
	var stamped := entry.duplicate(true)
	stamped["written_at"] = snappedf(Time.get_unix_time_from_system(), 0.001)
	runs.append(stamped)
	runs.sort_custom(_before)
	data["level"] = level_id
	data["runs"] = runs
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.close()
	return path


static func _same_key(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("variant", "")) == String(b.get("variant", "")) \
			and String(a.get("mode", "")) == String(b.get("mode", "")) \
			and int(a.get("seed", 0)) == int(b.get("seed", 0))


static func _before(a: Dictionary, b: Dictionary) -> bool:
	var va := VARIANT_ORDER.find(String(a.get("variant", "")))
	var vb := VARIANT_ORDER.find(String(b.get("variant", "")))
	if va != vb:
		return va < vb
	if String(a.get("mode", "")) != String(b.get("mode", "")):
		return String(a.get("mode", "")) < String(b.get("mode", ""))
	return int(a.get("seed", 0)) < int(b.get("seed", 0))
