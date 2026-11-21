extends Node
## Folder for persistent files (settings, progress): -- --data-dir= beats TFI_DATA_DIR beats user://.
## The statics are pure or process-wide so that --script entry scripts can preload and use them.

const CliArgsScript := preload("res://scripts/core/cli_args.gd")
const ENV_VAR := "TFI_DATA_DIR"
const CLI_KEY := "data-dir"
const DEFAULT_DIR := "user://"


## Pure precedence rule: a non-empty CLI string wins over a non-empty environment value, else user://.
static func resolve(cli: Dictionary, env_value: String) -> String:
	var cli_value: Variant = cli.get(CLI_KEY, "")
	if cli_value is String and cli_value != "":
		return cli_value
	if env_value != "":
		return env_value
	return DEFAULT_DIR


## Returns the data folder of this process.
static func current_dir() -> String:
	return resolve(CliArgsScript.current(), OS.get_environment(ENV_VAR))


## Turns a user:// path into an absolute path; other paths are returned unchanged.
static func globalize(dir: String) -> String:
	if dir.begins_with("user://"):
		return ProjectSettings.globalize_path(dir)
	return dir


## Returns the data folder of this process.
func path() -> String:
	return current_dir()


## Returns the path of a file below the data folder.
func file(rel: String) -> String:
	return current_dir().path_join(rel)


## Creates the data folder or a sub folder if needed and returns the Error code.
func ensure_dir(rel: String = "") -> Error:
	var dir := current_dir() if rel == "" else file(rel)
	return DirAccess.make_dir_recursive_absolute(globalize(dir)) as Error
