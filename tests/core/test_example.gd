extends TestCase
## Example GDScript test for the headless runner.


func test_arithmetic() -> void:
	check_eq(1 + 1, 2, "addition")


func test_project_settings() -> void:
	check_eq(int(ProjectSettings.get_setting("display/window/size/viewport_width")), 1920, "viewport width")
