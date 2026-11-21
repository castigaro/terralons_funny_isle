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


const EXPECTED_KEYS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"dash": [KEY_SHIFT, KEY_SHIFT],
	"interact": [KEY_SPACE, KEY_E],
	"pause": [KEY_ESCAPE],
	"restart": [KEY_R],
	"hint": [KEY_H],
	"finish": [KEY_ENTER, KEY_KP_ENTER, KEY_F],
}
const EXPECTED_LAYERS := ["world_solid", "water", "bounds", "castaway", "animals", "items", "zones"]


func test_input_map_actions_and_physical_keys() -> void:
	for action in EXPECTED_KEYS:
		check(InputMap.has_action(action), "missing action %s" % action)
		if not InputMap.has_action(action):
			continue
		var codes := []
		for event in InputMap.action_get_events(action):
			check(event is InputEventKey, "%s: non-key event" % action)
			if event is InputEventKey:
				check_eq(event.keycode, KEY_NONE, "%s uses physical keycodes only" % action)
				codes.append(event.physical_keycode)
		check_eq(codes, EXPECTED_KEYS[action], "%s keys" % action)


func test_dash_has_both_shift_keys() -> void:
	var locations := []
	for event in InputMap.action_get_events("dash"):
		locations.append((event as InputEventKey).location)
	locations.sort()
	check_eq(locations, [KEY_LOCATION_LEFT, KEY_LOCATION_RIGHT], "shift locations")


func test_physics_layer_names() -> void:
	for i in EXPECTED_LAYERS.size():
		var value := String(ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % (i + 1), ""))
		check_eq(value, EXPECTED_LAYERS[i], "layer %d" % (i + 1))
	check_eq(PhysicsLayers.WORLD_SOLID, 1 << 0, "solid bit")
	check_eq(PhysicsLayers.ZONES, 1 << 6, "zones bit")


func test_physics_interpolation_and_stretch() -> void:
	check_eq(ProjectSettings.get_setting("physics/common/physics_interpolation"), true, "physics interpolation")
	check_eq(int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")), 60, "60 Hz tick")
	check_eq(float(ProjectSettings.get_setting("physics/common/physics_jitter_fix")), 0.0, "jitter fix off")
	check_eq(String(ProjectSettings.get_setting("display/window/stretch/aspect")), "keep", "aspect keep")
	check_eq(ProjectSettings.get_setting("display/window/size/resizable"), true, "resizable")
	check(ProjectSettings.has_setting("rendering/environment/defaults/default_clear_color"), "clear colour set")


func _collect_canvas_layers(node: Node, out: Array) -> Array:
	if node is CanvasLayer:
		out.append(node)
	for child in node.get_children():
		_collect_canvas_layers(child, out)
	return out


func test_level_interpolation_modes() -> void:
	var level := (load("res://tests/scenes/sample_level.tscn") as PackedScene).instantiate() as LevelBase
	add_node(level)
	await physics_frames(1)
	check(level.camera().physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_OFF, "camera interpolated")
	check(level.camera().is_physics_interpolated(), "camera interpolation active")
	var layers := _collect_canvas_layers(level, [])
	check(layers.size() >= 2, "overlay layers found")
	for layer in layers:
		check_eq(layer.physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF, "%s interpolation off" % layer.name)


func test_entity_interpolation_modes() -> void:
	for path in ["res://scenes/entities/animal.tscn", "res://scenes/entities/item.tscn"]:
		var node := (load(path) as PackedScene).instantiate()
		node.set("kind", "chicken" if path.contains("animal") else "coconut")
		add_node(node)
		await physics_frames(1)
		check_ne(node.physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF, "%s body interpolated" % path)
		for child in node.get_children():
			# World-space particles (local_coords off) manage their own interpolation.
			if child is CanvasItem and not child is CPUParticles2D:
				check_ne((child as CanvasItem).physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF,
						"%s/%s follows the physics-animated body" % [path, child.name])
		node.queue_free()
	var cfg := EntityConfig.from_balance()
	var puff := RespawnPuff.spawn(root(), Vector2(100, 100), cfg)
	await frames(1)
	check_eq(puff.physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF, "respawn puff (_process) not interpolated")
	puff.queue_free()
