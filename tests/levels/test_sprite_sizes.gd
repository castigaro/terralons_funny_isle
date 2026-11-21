extends "res://tests/support/level_case.gd"
## Readable sprite sizes: geometric screen boxes (sprite rect x global transform x canvas_items stretch scale).
## The castaway is at least 64 px tall at 1920x1080; animals and items are at least 24 px on their shorter side at
## 1280x720. tools/capture_level.py confirms the castaway size in a real windowed capture.

const BASE := Vector2(1920, 1080)


func _screen_size(sprite: Sprite2D, window: Vector2) -> Vector2:
	var stretch := minf(window.x / BASE.x, window.y / BASE.y)
	var rect := sprite.get_rect()
	var xf := sprite.get_global_transform()
	var corners := [xf * rect.position, xf * Vector2(rect.end.x, rect.position.y), xf * rect.end,
			xf * Vector2(rect.position.x, rect.end.y)]
	var box := Rect2(corners[0], Vector2.ZERO)
	for c in corners:
		box = box.expand(c)
	return box.size * stretch


func test_castaway_is_at_least_64_px_tall_at_1080p() -> void:
	await open_level()
	await place_castaway(level.spawn_position(), -PI / 2.0)
	var body := castaway.get_node("Visual/Body") as Sprite2D
	var size := _screen_size(body, BASE)
	check(size.y >= 64.0, "castaway %.1f px tall facing up" % size.y)
	await place_castaway(level.spawn_position(), 0.0)
	size = _screen_size(body, BASE)
	check(minf(size.x, size.y) >= 64.0, "castaway %s px facing right" % size)


func test_animals_and_items_are_at_least_24_px_at_720p() -> void:
	await open_level()
	var count := 0
	for group in ["animal", "item"]:
		for node in tree().get_nodes_in_group(group):
			if not level.is_ancestor_of(node):
				continue
			var sprite := node.get_node("Visual/Body") as Sprite2D
			var size := _screen_size(sprite, Vector2(1280, 720))
			check(minf(size.x, size.y) >= 24.0, "%s %s px at 1280x720" % [node.name, size])
			count += 1
	check_eq(count, 2, "sample animal and item measured")


func test_frog_is_at_least_24_px_at_720p() -> void:
	await open_level("res://scenes/levels/l3_jungle.tscn")
	var frogs := tree().get_nodes_in_group("animal").filter(
			func(n: Node) -> bool: return level.is_ancestor_of(n) and String(n.get("kind")) == "frog")
	check_eq(frogs.size(), 3, "three frogs")
	for frog in frogs:
		var size := _screen_size(frog.get_node("Visual/Body") as Sprite2D, Vector2(1280, 720))
		check(minf(size.x, size.y) >= 24.0, "%s %s px at 1280x720" % [frog.name, size])
