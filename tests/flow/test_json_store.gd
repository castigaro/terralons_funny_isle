extends "res://tests/support/flow_case.gd"
## JsonStore: round trip, read statuses, atomic overwrite and a write into an impossible path.


func test_round_trip_and_overwrite() -> void:
	var dir := use_data_dir("json_store")
	var path := dir.path_join("store.json")
	check_eq(JsonStore.write_atomic(path, {"a": 1}), OK, "first write")
	check_eq(JsonStore.write_atomic(path, {"a": 2, "b": [true]}), OK, "overwrite existing")
	var res := JsonStore.read(path)
	check_eq(res["status"], "ok", "status")
	check_eq(res["data"], {"a": 2.0, "b": [true]}, "data")
	check_false(FileAccess.file_exists(path + ".tmp"), "no temp file left")


func test_read_statuses() -> void:
	var dir := use_data_dir("json_store")
	check_eq(JsonStore.read(dir.path_join("nope.json"))["status"], "missing", "missing")
	check_eq(JsonStore.read("")["status"], "missing", "empty path")
	write_file(dir.path_join("empty.json"), "  \n")
	check_eq(JsonStore.read(dir.path_join("empty.json"))["status"], "empty", "empty")
	write_file(dir.path_join("corrupt.json"), "{\"a\": ")
	var corrupt := JsonStore.read(dir.path_join("corrupt.json"))
	check_eq(corrupt["status"], "corrupt", "corrupt")
	check_eq(corrupt["data"], null, "no data")


func test_write_below_a_file_fails_softly() -> void:
	var dir := use_data_dir("json_store")
	var blocker := dir.path_join("blocker")
	write_file(blocker, "x")
	var err := JsonStore.write_atomic(blocker.path_join("settings.json"), {"a": 1})
	check_ne(err, OK, "write fails")
	check_ne(JsonStore.write_atomic("", {}), OK, "empty path fails")
