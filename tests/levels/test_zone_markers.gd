extends "res://tests/support/level_case.gd"
## Zone markers (BI-19): every player-action zone of a shipped level is outlined by one decoration-only ZoneMarker
## that sits on the zone bounds below the actors; helper and area zones stay unmarked.

const Art := preload("res://tests/support/ground_art.gd")
const MarkerTool := preload("res://tools/derive_zone_marker.gd")
## Action zones per level (mirrors tools/validate_level_art.py: task zones, delivered_to and Pen/Delivery/Build
## target kinds that are zone ids, minus the area zones beach and lagoon of L4).
const ACTION_ZONES := {"l1_beach_camp": ["cage"], "l2_farm_meadow": ["pond", "pig_pen", "trough"],
		"l3_jungle": ["pond", "perch", "goat_pen"], "l4_lagoon": ["sandcastle"],
		"l5_volcano_cliffs": ["shelter", "mud_pool"]}
const AREA_ZONES := {"l4_lagoon": ["beach", "lagoon"]}
const LEVEL_DIR := "res://scenes/levels/"
const RECT_TOLERANCE := 16.0
const VIEW_SCALE_720 := 720.0 / 1080.0


func _open(level_id: String) -> void:
	await open_level(LEVEL_DIR + level_id + ".tscn")


func _markers() -> Array:
	return level.get_node("ZoneMarkers").get_children().filter(func(n: Node) -> bool: return n is ZoneMarker)


func test_every_action_zone_has_a_marker() -> void:
	for level_id in ACTION_ZONES:
		await _open(level_id)
		var by_zone := {}
		for marker: ZoneMarker in _markers():
			by_zone[marker.zone_id] = by_zone.get(marker.zone_id, []) + [marker]
		for zone_id in ACTION_ZONES[level_id]:
			var found: Array = by_zone.get(zone_id, [])
			check_eq(found.size(), 1, "%s: one marker for %s" % [level_id, zone_id])
			if found.size() != 1:
				continue
			var marker := found[0] as ZoneMarker
			check(marker.visible, "%s: marker %s visible" % [level_id, zone_id])
			check(marker.zone_node() == level.zone(zone_id), "%s: marker %s bound to its zone" % [level_id, zone_id])
			var want := ZoneMarker.zone_rect(level.zone(zone_id))
			var got := marker.marker_rect()
			check(want.size.x > 0.0, "%s: zone %s has a shape" % [level_id, zone_id])
			check(got.position.distance_to(want.position) <= RECT_TOLERANCE
					and got.end.distance_to(want.end) <= RECT_TOLERANCE,
					"%s: marker %s rect %s on zone %s" % [level_id, zone_id, got, want])
		level.queue_free()
		level = null
		await frames(1)


func test_helper_and_area_zones_have_no_marker() -> void:
	for level_id in ACTION_ZONES:
		await _open(level_id)
		var marked := {}
		for marker: ZoneMarker in _markers():
			marked[marker.zone_id] = true
		var helpers := 0
		for zone in level.get_node("Zones").get_children():
			if not zone is Zone:
				continue
			var zone_id := (zone as Zone).zone_id
			if not ACTION_ZONES[level_id].has(zone_id):
				helpers += 1
				check_false(marked.has(zone_id), "%s: helper or area zone %s is not marked" % [level_id, zone_id])
		for zone_id in AREA_ZONES.get(level_id, []):
			check(level.zone(zone_id) != null, "%s: area zone %s exists" % [level_id, zone_id])
		check(helpers >= 1, "%s has helper zones" % level_id)
		level.queue_free()
		level = null
		await frames(1)


func _descendants(node: Node, out: Array) -> Array:
	for child in node.get_children():
		out.append(child)
		_descendants(child, out)
	return out


func test_marker_is_decoration_only() -> void:
	await _open("l2_farm_meadow")
	var holder := level.get_node("ZoneMarkers") as Node2D
	check_eq(holder.z_index, -2, "ZoneMarkers z_index")
	check(holder.get_index() < level.get_node("Actors").get_index(), "ZoneMarkers before Actors")
	check(holder.get_index() > level.get_node("Details").get_index(), "ZoneMarkers after Details")
	check_false(LevelBase.REQUIRED_CHILDREN.has("ZoneMarkers"), "not a required child")
	for marker: ZoneMarker in _markers():
		check_false(marker.has_method("_process"), "%s has no per-frame work" % marker.name)
		for node in _descendants(marker, []):
			check_false(node is CollisionObject2D or node is CollisionShape2D, "%s: no collision" % node.name)
			if node is Control:
				check_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % node.name)
			if node is NinePatchRect:
				var path := (node as NinePatchRect).texture.resource_path
				check(path.begins_with("res://assets/"), "%s texture from assets: %s" % [node.name, path])
				check_false((node as NinePatchRect).draw_center, "no centre fill")
	var img := Art.load_png(MarkerTool.OUT)
	var alpha := 0.0
	var centre := Rect2i(16, 16, 32, 32)
	for y in range(centre.position.y, centre.end.y):
		for x in range(centre.position.x, centre.end.x):
			alpha += img.get_pixel(x, y).a
	check(alpha / float(centre.get_area()) < 0.1, "marker texture is an outline, not a filled panel")


func test_marker_contrast_and_width() -> void:
	var dark := ArtPalette.color("outline")
	var fill := Art.mean_color(Art.load_png("res://assets/graphics/pirate-pack-derived/grass_edges@2.png"),
			Rect2i(0, 4 * 128, 128, 128))
	check(Art.contrast(dark, fill) >= 3.0, "dark stroke on grass %.2f:1" % Art.contrast(dark, fill))
	check(Art.contrast(dark, ArtPalette.color("sand")) >= 3.0,
			"dark stroke on sand %.2f:1" % Art.contrast(dark, ArtPalette.color("sand")))
	var src := Art.load_png("res://assets/ui/ui-pack/PNG/Extra/Default/button_round_line.png")
	var dark_px := MarkerTool.stroke_width(src) + 1.0
	check(dark_px * ZoneMarker.LINE_SCALE * VIEW_SCALE_720 >= 2.0, "dark line at least 2 px at 720p")
	var img := Art.load_png(MarkerTool.OUT)
	var edge := img.get_pixel(32, 1)
	check(Color(edge, 1.0).is_equal_approx(Color(dark, 1.0)), "outer stroke is palette outline: %s" % edge)
	var inner := img.get_pixel(32, int(dark_px) + 1)
	check(Color(inner, 1.0).is_equal_approx(Color(ArtPalette.color("zone_marker"), 1.0)),
			"inner stroke is palette zone_marker: %s" % inner)


func test_missing_zone_hides_the_marker() -> void:
	await _open("l1_beach_camp")
	var marker := (load("res://scenes/levels/props/zone_marker.tscn") as PackedScene).instantiate() as ZoneMarker
	marker.zone_id = "no_such_zone"
	level.get_node("ZoneMarkers").add_child(marker)
	await frames(1)
	check_false(marker.visible, "marker without a zone is hidden")
	check(marker.zone_node() == null, "no zone bound")
