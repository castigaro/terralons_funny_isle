extends Node
## Windowed capture probe (opt-in, tools/capture_level.py): opens a level, saves a screenshot and measures the
## on-screen height of the castaway body sprite by diffing a frame with and without it.
## Usage: Godot_v4.7.2-stable_win64.exe --path . res://tests/scenes/capture_probe.tscn -- --level=<tscn>
##        --out=<png> [--size=1920x1080] [--frames=30] [--focus=x,y]

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
	await RenderingServer.frame_post_draw
	var with_body := get_viewport().get_texture().get_image()
	if _out != "":
		with_body.save_png(_out)
	var castaway: Node2D = _level.get_node("Actors/Castaway")
	var body: Sprite2D = castaway.get_node("Visual/Body")
	var screen := get_viewport().get_canvas_transform() * castaway.global_position
	var stretch := float(with_body.get_height()) / float(get_viewport().get_visible_rect().size.y)
	body.visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var without := get_viewport().get_texture().get_image()
	var centre := Vector2i(screen * stretch)
	var reach := int(160 * stretch)
	var box := Rect2i()
	for y in range(maxi(0, centre.y - reach), mini(with_body.get_height(), centre.y + reach)):
		for x in range(maxi(0, centre.x - reach), mini(with_body.get_width(), centre.x + reach)):
			var a := with_body.get_pixel(x, y)
			var b := without.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.15:
				var p := Rect2i(x, y, 1, 1)
				box = p if box.size == Vector2i.ZERO else box.merge(p)
	var px := box.size.y
	var at_1080 := float(px) * 1080.0 / float(with_body.get_height())
	print("CAPTURE image=%dx%d castaway_px=%d castaway_px_1080=%.1f" % [with_body.get_width(), with_body.get_height(),
			px, at_1080])
	get_tree().quit(0)
