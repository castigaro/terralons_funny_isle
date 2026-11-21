class_name TestCase
extends RefCounted
## Base class for headless tests: methods named test_* are run by tests/runner.gd (coroutines allowed).

var failures: Array[String] = []
var _tree: SceneTree = null
var _nodes: Array = []


func _setup_runner(tree: SceneTree) -> void:
	_tree = tree


func tree() -> SceneTree:
	if _tree == null:
		_tree = Engine.get_main_loop() as SceneTree
	return _tree


func root() -> Window:
	return tree().root


## Frame rate of this run: the --fps=N user argument set by run_tests.py for "## run-fps:" files (default 60).
func run_fps() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fps="):
			return int(arg.get_slice("=", 1))
	return 60


# --- Checks ------------------------------------------------------------------

func fail(message: String) -> void:
	failures.append(message)


func check(condition: bool, message: String = "check failed") -> void:
	if not condition:
		failures.append(message)


func check_true(condition: bool, message: String = "expected true") -> void:
	check(condition, message)


func check_false(condition: bool, message: String = "expected false") -> void:
	check(not condition, message)


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _same(actual, expected):
		failures.append("%s expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])


func check_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if _same(actual, unexpected):
		failures.append("%s did not expect %s" % [message, var_to_str(actual)])


func check_has(container: Variant, item: Variant, message: String = "") -> void:
	var ok := false
	if container is Dictionary or container is Array or container is String:
		ok = container.has(item) if not container is String else String(container).contains(str(item))
	elif typeof(container) >= TYPE_PACKED_BYTE_ARRAY:
		ok = item in container
	if not ok:
		failures.append("%s %s does not contain %s" % [message, var_to_str(container), var_to_str(item)])


func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		if (a is int or a is float) and (b is int or b is float):
			return a == b
		return false
	return a == b


# --- Scene helpers -------------------------------------------------------------

## Adds a node to the root and frees it after the test.
func add_node(node: Node) -> Node:
	root().add_child(node)
	_nodes.append(node)
	return node


## Waits n process frames.
func frames(n: int = 1) -> void:
	for i in n:
		await tree().process_frame


## Waits n physics frames.
func physics_frames(n: int = 1) -> void:
	for i in n:
		await tree().physics_frame


## Frees tracked nodes and waits one frame.
func _teardown() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()
	await tree().process_frame
