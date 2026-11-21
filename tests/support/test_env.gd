extends RefCounted
## Resets the global environment between tests (loaded by tests/runner.gd); duck-typed so it names no autoload.
## Also restores Engine.time_scale in case a hit-stop test failed half-way.

const RELEASED_ACTIONS := ["move_up", "move_down", "move_left", "move_right", "dash", "interact", "finish"]


static func reset() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	tree.paused = false
	Engine.time_scale = 1.0
	for action in RELEASED_ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)
	var balance := tree.root.get_node_or_null("Balance")
	if balance != null and balance.has_method("clear_overrides"):
		balance.call("clear_overrides")
	var audio := tree.root.get_node_or_null("Audio")
	if audio != null and audio.has_method("reset_for_tests"):
		audio.call("reset_for_tests")
	(load("res://scripts/ui/prompt_memory.gd") as GDScript).call("reset")
	var i18n := tree.root.get_node_or_null("I18n")
	if i18n != null and i18n.has_method("get_locale") and i18n.call("get_locale") != "en":
		i18n.call("set_locale", "en")
	for autoload_name in ["Settings", "Progress"]:
		var node := tree.root.get_node_or_null(autoload_name)
		if node != null and node.has_method("reset_for_tests"):
			node.call("reset_for_tests")
