extends TestCase
## The level catalogue and the title stub start path: -- --level=<id> boots that level, unknown ids stay on the title.

const MainScript := preload("res://scripts/main.gd")


func test_start_target() -> void:
	check_eq(MainScript.start_target({}), "", "no argument stays on the title")
	check_eq(MainScript.start_target({"level": "l2_farm_meadow"}), "res://scenes/levels/l2_farm_meadow.tscn", "level id")
	check_eq(MainScript.start_target({"level": "atlantis"}), "", "unknown id stays on the title")


func test_paths_follow_the_convention() -> void:
	check_eq(LevelCatalogue.scene_path("l1_beach_camp"), "res://scenes/levels/l1_beach_camp.tscn", "scene")
	check_eq(LevelCatalogue.json_path("l1_beach_camp"), "res://data/levels/l1_beach_camp.json", "json")
	check_eq(LevelCatalogue.scene_for("missing_level"), "", "unknown scene")
