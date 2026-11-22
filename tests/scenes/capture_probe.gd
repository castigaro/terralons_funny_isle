extends Node
## Windowed capture probe (opt-in, tools/capture_level.py): opens a level, saves a screenshot and measures the
## on-screen height of the castaway body sprite by diffing a frame with and without it.
## Usage: Godot_v4.7.2-stable_win64.exe --path . res://tests/scenes/capture_probe.tscn -- --level=<tscn>
##        --out=<png> [--size=1920x1080] [--frames=30] [--focus=x,y]

const CastawayMeasure := preload("res://tests/support/castaway_measure.gd")

var _level: Node
var _out := ""
var _frames := 30
var _focus := Vector2i(-1, -1)


func _ready() -> void:
	var level_path := "res://tests/scenes/sample_level.tscn"
	var size := Vector2i(1920, 1080)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			level_path = arg.get_slice("=", 1)
		elif arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--frames="):
			_frames = int(arg.get_slice("=", 1))
		elif arg.begins_with("--focus="):
			var cell := arg.get_slice("=", 1).split(",")
			_focus = Vector2i(int(cell[0]), int(cell[1]))
		elif arg.begins_with("--size="):
			var parts := arg.get_slice("=", 1).split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	get_window().size = size
	_level = (load(level_path) as PackedScene).instantiate()
	add_child(_level)
	_run()


func _run() -> void:
	if _focus.x >= 0 and _level is LevelBase:
		await get_tree().physics_frame
		var level := _level as LevelBase
		level.castaway().process_mode = Node.PROCESS_MODE_DISABLED
		level.camera().target = null
		level.camera().global_position = level.camera().clamp_to_bounds(level.cell_center(_focus))
		level.camera().reset_physics_interpolation()
	for i in _frames:
		await get_tree().process_frame
	if _out != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out)
	var castaway: Node2D = _level.get_node("Actors/Castaway")
	var m: Dictionary = await CastawayMeasure.measure(self, castaway)
	var size: Vector2i = m["image_size"]
	var px := int(m["px"])
	var at_1080 := float(m["px_1080"])
	print("CAPTURE image=%dx%d castaway_px=%d castaway_px_1080=%.1f" % [size.x, size.y, px, at_1080])
	get_tree().quit(0)
