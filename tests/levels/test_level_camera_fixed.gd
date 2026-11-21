extends "res://tests/support/level_case.gd"
## A level that fits the screen uses a fixed camera; the water backdrop covers a viewport beyond every level edge.

const VIEW := Vector2(1920, 1080)


func test_small_level_camera_stays_fixed() -> void:
	await open_level(SMALL_LEVEL)
	var cam := level.camera()
	check(cam.is_fixed_axis(0) and cam.is_fixed_axis(1), "both axes fixed")
	var centre := level.get_bounds_rect().get_center()
	check_eq(cam.global_position, centre, "camera at the bounds centre")
	var moved := 0
	for i in 120:
		move = Vector2.RIGHT if i < 60 else Vector2(-1, -1).normalized()
		if i % 20 == 0:
			press_dash()
		await physics_frames(1)
		var vp := level.get_viewport()
		var screen := vp.get_canvas_transform().affine_inverse() * (vp.get_visible_rect().size / 2.0)
		if cam.global_position != centre or screen.distance_to(centre) > 0.001:
			moved += 1
	check_eq(moved, 0, "frames with a moved camera")


func test_backdrop_covers_a_viewport_around_the_level() -> void:
	for path in [SAMPLE_LEVEL, SMALL_LEVEL]:
		await open_level(path)
		var grown := level.get_bounds_rect().grow_individual(VIEW.x, VIEW.y, VIEW.x, VIEW.y)
		check(level.backdrop_rect().encloses(grown), "%s backdrop %s covers %s" % [path, level.backdrop_rect(), grown])
		level.queue_free()
		await frames(1)


func test_clear_colour_is_the_palette_water() -> void:
	var clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	check(clear.is_equal_approx(ArtPalette.color("water")), "clear %s vs water %s" % [clear, ArtPalette.color("water")])
