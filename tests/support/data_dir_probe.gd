extends SceneTree
## Entry script for the data-dir test: writes tfi_marker.txt into the resolved data folder and prints its path.
## Preloads the DataDir script instead of naming the autoload, so it compiles as a --script entry.

const DataDirScript := preload("res://scripts/autoload/data_dir.gd")


func _initialize() -> void:
	var abs_dir: String = DataDirScript.globalize(DataDirScript.current_dir())
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var f := FileAccess.open(abs_dir.path_join("tfi_marker.txt"), FileAccess.WRITE)
	if f != null:
		f.store_string("marker")
		f.close()
	print("DATA_DIR=%s" % abs_dir)
	quit(0)
