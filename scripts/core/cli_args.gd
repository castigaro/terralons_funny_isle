class_name CliArgs
extends RefCounted
## Parses the user command-line arguments given after "--".


## Returns a Dictionary: "--k=v" becomes k: "v", "--flag" becomes flag: true; other arguments are ignored.
static func parse(args: PackedStringArray) -> Dictionary:
	var result := {}
	for arg in args:
		if not arg.begins_with("--") or arg.length() <= 2:
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		if eq < 0:
			result[body] = true
		else:
			result[body.substr(0, eq)] = body.substr(eq + 1)
	return result


## Returns the parsed user arguments of this process.
static func current() -> Dictionary:
	return parse(OS.get_cmdline_user_args())


## Returns d[key] as int, or default when missing; an invalid value logs a warning and gives default.
static func get_int(d: Dictionary, key: String, default: int) -> int:
	if not d.has(key):
		return default
	var raw := str(d[key])
	if not raw.is_valid_int():
		push_warning("Invalid integer for --%s: '%s'" % [key, raw])
		return default
	return raw.to_int()
