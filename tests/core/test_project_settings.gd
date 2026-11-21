extends TestCase
## Project settings required by the foundation item (viewport, window, physics, autoloads).

const EXPECTED_AUTOLOADS := ["Balance", "DataDir", "EventBus", "I18n"]
const FORBIDDEN_AUTOLOADS := ["Game", "Features", "Capabilities", "Actions"]


func test_features_declare_4_7() -> void:
	var features: PackedStringArray = ProjectSettings.get_setting("application/config/features")
	check(features.has("4.7"), "features %s lack 4.7" % str(features))


func test_viewport_and_window() -> void:
	check_eq(int(ProjectSettings.get_setting("display/window/size/viewport_width")), 1920, "width")
	check_eq(int(ProjectSettings.get_setting("display/window/size/viewport_height")), 1080, "height")
	check_eq(ProjectSettings.get_setting("display/window/size/resizable"), true, "resizable")
	check_eq(String(ProjectSettings.get_setting("display/window/stretch/mode")), "canvas_items", "stretch mode")


func test_physics_locale_and_main_scene() -> void:
	check_eq(int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")), 60, "physics ticks")
	check_eq(String(ProjectSettings.get_setting("internationalization/locale/fallback")), "en", "fallback")
	check_eq(String(ProjectSettings.get_setting("application/run/main_scene")), "res://scenes/main.tscn", "main")


func test_autoloads_are_exactly_the_core_set() -> void:
	var names := []
	for prop in ProjectSettings.get_property_list():
		var pname: String = prop["name"]
		if pname.begins_with("autoload/"):
			names.append(pname.trim_prefix("autoload/"))
	names.sort()
	check_eq(names, EXPECTED_AUTOLOADS, "autoloads")
	for forbidden in FORBIDDEN_AUTOLOADS:
		check_false(names.has(forbidden), "forbidden autoload %s" % forbidden)
		check(root().get_node_or_null(forbidden) == null, "node %s exists" % forbidden)
