extends SceneTree
## Headless test runner.
## Usage: godot --headless --path . --script res://tests/runner.gd -- [--watchdog=<s>] res://tests/x/test_a.gd [...]
## Runs every test_* method without parameters (coroutines are awaited) with optional before_each/after_each and an
## environment reset between tests. Prints RUN/PASS/FAIL lines, one RESULT line per file and exits 1 on
## any failure, on a file without tests or when the watchdog fires. This entry script must stay duck-typed:
## it may not name autoloads or classes that name autoloads.

const ENV_SCRIPT := "res://tests/support/test_env.gd"

var _current_file := ""
var _results: Array = []


func _initialize() -> void:
	await process_frame
	var watchdog := 60.0
	var files: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--watchdog="):
			watchdog = float(arg.get_slice("=", 1))
		elif arg.begins_with("res://"):
			files.append(arg)
	if files.is_empty():
		printerr("runner: no test script given")
		quit(1)
		return
	var any_failure := false
	for file in files:
		var counts: Array = await _run_file(file, watchdog)
		_results.append([file, counts[0], counts[1]])
		if counts[1] > 0 or counts[0] == 0:
			any_failure = true
	_current_file = ""
	for r in _results:
		print("RESULT %s passed=%d failed=%d" % r)
	await process_frame
	quit(1 if any_failure else 0)


func _run_file(file: String, watchdog: float) -> Array:
	_current_file = file
	var timer := create_timer(watchdog, true, false, true)
	timer.timeout.connect(_on_watchdog.bind(file))
	var script: Script = load(file)
	if script == null:
		printerr("FAIL %s – cannot load script" % file)
		return [0, 1]
	var env_script: Script = load(ENV_SCRIPT) if ResourceLoader.exists(ENV_SCRIPT) else null
	var passed := 0
	var failed := 0
	var seen := {}
	for method in script.get_script_method_list():
		var name: String = method["name"]
		if not name.begins_with("test_") or seen.has(name) or method["args"].size() > 0:
			continue
		seen[name] = true
		var test: Object = script.new()
		if test.has_method("_setup_runner"):
			test.call("_setup_runner", self)
		if env_script != null:
			env_script.call("reset")
		if test.has_method("before_each"):
			await test.call("before_each")
		print("RUN %s::%s" % [file, name])
		await test.call(name)
		if test.has_method("after_each"):
			await test.call("after_each")
		if test.has_method("_teardown"):
			await test.call("_teardown")
		var failures: Array = test.get("failures") if test.get("failures") != null else []
		if failures.is_empty():
			passed += 1
			print("PASS %s::%s" % [file, name])
		else:
			failed += 1
			for f in failures:
				printerr("FAIL %s::%s – %s" % [file, name, f])
	if env_script != null:
		env_script.call("reset")
	await process_frame
	return [passed, failed]


func _on_watchdog(file: String) -> void:
	if _current_file != file:
		return
	printerr("WATCHDOG %s did not finish in time" % file)
	print("RESULT %s passed=0 failed=1" % file)
	quit(1)
