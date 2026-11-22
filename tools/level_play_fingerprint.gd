extends SceneTree
## Writes the play fingerprint baselines (tests/support/play_fingerprint.gd) of the given levels to
## tests/fixtures/levels/play_baseline_<id>.json. Run it only on a state whose gameplay is the reference.
## Usage: godot --headless --path . --script res://tools/level_play_fingerprint.gd -- l1_beach_camp l2_farm_meadow

const LEVEL_DIR := "res://scenes/levels/"


func _initialize() -> void:
	await process_frame
	# Runtime load: the support script names classes that use autoloads.
	var fingerprint: Script = load("res://tests/support/play_fingerprint.gd")
	var ids := OS.get_cmdline_user_args()
	if ids.is_empty():
		printerr("level_play_fingerprint: give at least one level id")
		quit(1)
		return
	for level_id in ids:
		var level := (load(LEVEL_DIR + level_id + ".tscn") as PackedScene).instantiate()
		root.add_child(level)
		var fp: Dictionary = fingerprint.fingerprint(level)
		root.remove_child(level)
		level.free()
		var path: String = fingerprint.baseline_path(level_id)
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			printerr("cannot write %s" % path)
			quit(1)
			return
		file.store_string(JSON.stringify(fp, "\t", true) + "\n")
		file.close()
		print("WROTE %s" % path)
	quit(0)
