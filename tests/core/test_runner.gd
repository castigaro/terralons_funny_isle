extends TestCase
## Runner behaviour: hooks, coroutines and the environment reset between tests (declaration order matters).

static var dirty_done := false

var _before := false


func before_each() -> void:
	_before = true


func after_each() -> void:
	_before = false


func test_0_before_each_ran() -> void:
	check(_before, "before_each ran")


func test_0_coroutine_is_awaited() -> void:
	await frames(2)
	check(true)


func test_1_dirty_state() -> void:
	root().get_node("Balance").set_override("core", "x", 5)
	root().get_node("I18n").set_locale("de")
	dirty_done = true


func test_2_state_was_reset() -> void:
	check(dirty_done, "dirty test ran first")
	check_false(root().get_node("Balance").has_value("core", "x"), "override cleared")
	check_eq(root().get_node("I18n").get_locale(), "en", "locale reset")
