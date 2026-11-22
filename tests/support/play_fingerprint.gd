extends RefCounted
## Play fingerprint of a level (BI-20 guard): everything that decides how a level plays – level JSON and layout,
## tile data, zones, home points, markers, event anchors, entity starts, use targets with their slots, solid props
## and every static collision shape. Set dressing must leave it unchanged. Values are strings (two decimals), so the
## committed JSON fixture compares exactly. Call it right after the level entered the tree, before any physics tick.

const LAYOUT_DIR := "res://scenes/levels/layouts/"
const BASELINE_DIR := "res://tests/fixtures/levels/"
const TILE_LAYERS := ["Sand", "Grass", "Shore", "Details"]
const MARKER_PARENTS := ["Zones", "HomePoints", "Markers", "EventAnchors"]
const TARGETS := ["PenGate", "PondJetty", "Trough", "CageGate", "LagoonJetty", "BeachFlag", "Sandcastle"]
const ENTITY_GROUP := "level_entity"


static func fingerprint(level: Node) -> Dictionary:
	var json_path: String = level.get("level_json_path")
	var level_id := json_path.get_file().get_basename()
	var fp := {
		"level_id": level_id,
		"json_sha": _file_sha(json_path),
		"layout_sha": _file_sha(LAYOUT_DIR + level_id + ".layout.txt"),
		"tiles": {},
		"markers": {},
		"entities": {},
		"targets": {},
		"props": {},
		"collisions": {},
	}
	for layer_name in TILE_LAYERS:
		var layer := level.get_node_or_null(layer_name) as TileMapLayer
		fp["tiles"][layer_name] = _bytes_sha(layer.tile_map_data) if layer != null else "missing"
	for parent_name in MARKER_PARENTS:
		var parent := level.get_node_or_null(parent_name)
		if parent == null:
			continue
		for child in parent.get_children():
			if not child is Node2D:
				continue
			var entry := _vec((child as Node2D).position)
			for shape_node in child.get_children():
				if shape_node is CollisionShape2D:
					entry += " " + _shape((shape_node as CollisionShape2D).shape) + " @" + _vec(shape_node.position)
			fp["markers"][parent_name + "/" + child.name] = entry
	var actors := level.get_node_or_null("Actors")
	if actors != null:
		for child in actors.get_children():
			if child.is_in_group(ENTITY_GROUP):
				fp["entities"][String(child.get("uid"))] = _vec((child as Node2D).position)
			elif child is Castaway:
				fp["entities"]["castaway"] = _vec((child as Node2D).position)
			elif TARGETS.has(String(child.name)):
				var slots := []
				for slot in child.get_children():
					if slot is Marker2D:
						slots.append("%s %s" % [slot.name, _vec(slot.position)])
				fp["targets"][String(child.name)] = _vec((child as Node2D).position) + " | " + ", ".join(slots)
			elif child is SwayProp:
				fp["props"][String(child.name)] = "%s r%.2f" % [_vec(child.position), (child as SwayProp).footprint_radius]
			elif child is StaticBody2D:
				fp["props"][String(child.name)] = _vec((child as Node2D).position)
	# Runtime-built shapes get names like @CollisionShape2D@49 whose number depends on the instance count.
	var auto_name := RegEx.create_from_string("@([A-Za-z0-9]+)@[0-9]+")
	for shape_node in collision_shapes(level):
		var path := auto_name.sub(String(level.get_path_to(shape_node)), "@$1", true)
		fp["collisions"][path] = "%s @%s" % [_shape(shape_node.shape), _vec(shape_node.global_position)]
	return fp


## Every static CollisionShape2D of the level; shapes of entities and the castaway move with them and are covered by
## the entity starts.
static func collision_shapes(level: Node) -> Array:
	var out := []
	for node in level.find_children("*", "CollisionShape2D", true, false):
		if _moves(level, node):
			continue
		out.append(node)
	return out


static func _moves(level: Node, node: Node) -> bool:
	var n := node.get_parent()
	while n != null and n != level:
		if n.is_in_group(ENTITY_GROUP) or n is Castaway:
			return true
		n = n.get_parent()
	return false


## Differences between a fingerprint and a baseline as readable lines; empty when equal.
static func diff(actual: Dictionary, baseline: Dictionary) -> Array:
	var lines := []
	for key in baseline:
		if not actual.has(key):
			lines.append("%s missing" % key)
			continue
		var a: Variant = actual[key]
		var b: Variant = baseline[key]
		if b is Dictionary and a is Dictionary:
			for sub in b:
				if not a.has(sub):
					lines.append("%s/%s removed (was %s)" % [key, sub, b[sub]])
				elif str(a[sub]) != str(b[sub]):
					lines.append("%s/%s changed: %s -> %s" % [key, sub, b[sub], a[sub]])
			for sub in a:
				if not b.has(sub):
					lines.append("%s/%s added: %s" % [key, sub, a[sub]])
		elif str(a) != str(b):
			lines.append("%s changed: %s -> %s" % [key, b, a])
	return lines


static func baseline_path(level_id: String) -> String:
	return BASELINE_DIR + "play_baseline_" + level_id + ".json"


static func _vec(v: Vector2) -> String:
	return "%.2f,%.2f" % [v.x, v.y]


static func _shape(shape: Shape2D) -> String:
	if shape is RectangleShape2D:
		return "Rect " + _vec((shape as RectangleShape2D).size)
	if shape is CircleShape2D:
		return "Circle %.2f" % (shape as CircleShape2D).radius
	if shape is CapsuleShape2D:
		return "Capsule %.2f,%.2f" % [(shape as CapsuleShape2D).radius, (shape as CapsuleShape2D).height]
	if shape is SegmentShape2D:
		return "Segment %s %s" % [_vec((shape as SegmentShape2D).a), _vec((shape as SegmentShape2D).b)]
	if shape is ConvexPolygonShape2D:
		return "Convex %s" % str((shape as ConvexPolygonShape2D).points)
	if shape is ConcavePolygonShape2D:
		return "Concave %s" % str((shape as ConcavePolygonShape2D).segments)
	return "none" if shape == null else shape.get_class()


static func _file_sha(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "missing"
	return _bytes_sha(FileAccess.get_file_as_bytes(path))


static func _bytes_sha(data: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	if not data.is_empty():
		ctx.update(data)
	return ctx.finish().hex_encode()
