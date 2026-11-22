extends RefCounted
## Measures the on-screen height of the castaway body sprite in a windowed run with three frames: A (body shown),
## B (body hidden) and C (body shown again). Only pixels that change between A and B but not between A and C count,
## so animated water, pulsing prompts and HUD changes do not inflate the box.

const PIXEL_DELTA := 0.15
const REACH_PX := 160


## Returns {px, px_1080, box, image_size}; probe is any node in the scene tree, castaway the castaway node.
static func measure(probe: Node, castaway: Node2D) -> Dictionary:
	var body: CanvasItem = castaway.get_node("Visual/Body")
	var viewport := probe.get_viewport()
	var a := await _grab(probe)
	var screen := viewport.get_canvas_transform() * castaway.global_position
	body.visible = false
	var b := await _grab(probe)
	body.visible = true
	var c := await _grab(probe)
	var stretch := float(a.get_height()) / float(viewport.get_visible_rect().size.y)
	var centre := Vector2i(screen * stretch)
	var reach := int(REACH_PX * stretch)
	var box := Rect2i()
	for y in range(maxi(0, centre.y - reach), mini(a.get_height(), centre.y + reach)):
		for x in range(maxi(0, centre.x - reach), mini(a.get_width(), centre.x + reach)):
			var pa := a.get_pixel(x, y)
			if _delta(pa, b.get_pixel(x, y)) > PIXEL_DELTA and _delta(pa, c.get_pixel(x, y)) <= PIXEL_DELTA:
				var p := Rect2i(x, y, 1, 1)
				box = p if box.size == Vector2i.ZERO else box.merge(p)
	var px := box.size.y
	return {"px": px, "px_1080": float(px) * 1080.0 / float(a.get_height()), "box": box, "image": a,
			"image_size": Vector2i(a.get_width(), a.get_height())}


static func _grab(probe: Node) -> Image:
	await probe.get_tree().process_frame
	await RenderingServer.frame_post_draw
	return probe.get_viewport().get_texture().get_image()


static func _delta(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
