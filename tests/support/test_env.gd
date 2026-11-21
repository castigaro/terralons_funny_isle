extends RefCounted
## Resets the global environment between tests (loaded by tests/runner.gd); duck-typed so it names no autoload.


static func reset() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var balance := tree.root.get_node_or_null("Balance")
	if balance != null and balance.has_method("clear_overrides"):
		balance.call("clear_overrides")
	var i18n := tree.root.get_node_or_null("I18n")
	if i18n != null and i18n.has_method("get_locale") and i18n.call("get_locale") != "en":
		i18n.call("set_locale", "en")
