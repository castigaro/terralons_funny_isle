extends TestCase
## DataDir autoload and CliArgs: precedence rule and the redirected test folder.

const DataDirScript := preload("res://scripts/autoload/data_dir.gd")


func test_resolve_precedence() -> void:
	check_eq(DataDirScript.resolve({"data-dir": "X"}, "Y"), "X", "cli wins")
	check_eq(DataDirScript.resolve({}, "Y"), "Y", "env next")
	check_eq(DataDirScript.resolve({}, ""), "user://", "default")
	check_eq(DataDirScript.resolve({"data-dir": ""}, "Y"), "Y", "empty cli ignored")
	check_eq(DataDirScript.resolve({"data-dir": true}, "Y"), "Y", "flag cli ignored")


func test_cli_args_parse() -> void:
	var parsed := CliArgs.parse(PackedStringArray(["--k=v", "--flag", "plain", "--", "--seed=7"]))
	check_eq(parsed, {"k": "v", "flag": true, "seed": "7"}, "parsed")
	check_eq(CliArgs.get_int(parsed, "seed", 0), 7, "int")
	check_eq(CliArgs.get_int(parsed, "missing", 3), 3, "default")


func test_autoload_uses_redirected_folder() -> void:
	var env := OS.get_environment("TFI_DATA_DIR")
	check_ne(env, "", "run_tests sets TFI_DATA_DIR")
	var data_dir := root().get_node("DataDir")
	check_eq(data_dir.path(), env, "path")
	check_eq(data_dir.file("a.json"), env.path_join("a.json"), "file")
	check(env.replace("\\", "/").to_lower().contains(".testdata"), "below testdata: %s" % env)


func test_ensure_dir_creates_folder() -> void:
	var data_dir := root().get_node("DataDir")
	check_eq(data_dir.ensure_dir("sub"), OK, "ensure_dir")
	check(DirAccess.dir_exists_absolute(data_dir.file("sub")), "folder exists")


func test_globalize() -> void:
	check_false(DataDirScript.globalize("user://").begins_with("user://"), "user:// globalized")
	check_eq(DataDirScript.globalize("C:/x"), "C:/x", "absolute unchanged")
