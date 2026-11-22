extends RefCounted
## Gameplay parity snapshot of a loaded level: data and layout hashes, zones, points, use targets and their slots,
## tile data hashes, every solid or water collision shape and the legacy props. Art-only changes must leave it equal.

const TILE_LAYERS := ["Sand", "Grass", "Shore", "Details"]
const SOLID_MASK := PhysicsLayers.WORLD_SOLID | PhysicsLayers.WATER
const LAYOUT_DIR := "res://scenes/levels/layouts/"


static func _v(p: Vector2) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01)]


static func _r(r: Rect2) -> Array:
	return _v(r.position) + _v(r.size)


static func _bytes_hash(data: PackedByteArray) -> String:
	if data.is_empty():
		return "empty"
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish().hex_encode()


static func _shape_info(shape: Shape2D) -> Array:
	if shape is CircleShape2D:
		return ["circle", snappedf((shape as CircleShape2D).radius, 0.01)]
	if shape is RectangleShape2D:
		return ["rect"] + _v((shape as RectangleShape2D).size)
	if shape is CapsuleShape2D:
		var cap := shape as CapsuleShape2D
		return ["capsule", snappedf(cap.radius, 0.01), snappedf(cap.height, 0.01)]
	if shape is ConvexPolygonShape2D:
		return ["convex", Array((shape as ConvexPolygonShape2D).points).map(func(p: Vector2) -> Array: return _v(p))]
	return [shape.get_class()]


static func _solids(level: Node) -> Array:
	var out: Array = []
	for node in level.find_children("*", "CollisionObject2D", true, false):
		var body := node as CollisionObject2D
		if body.collision_layer & SOLID_MASK == 0:
			continue
		for owner_id in body.get_shape_owners():
			var xf: Transform2D = body.global_transform * body.shape_owner_get_transform(owner_id)
			for i in body.shape_owner_get_shape_count(owner_id):
				var entry: Array = [body.collision_layer] + _v(xf.origin) + _shape_info(body.shape_owner_get_shape(owner_id, i))
				out.append(JSON.stringify(entry))
	out.sort()
	return out


static func _zones(level: Node) -> Dictionary:
	var out := {}
	for zone in level.get_node("Zones").get_children():
		var rects: Array = []
		for part in zone.get_children():
			var cs := part as CollisionShape2D
			if cs != null and cs.shape is RectangleShape2D:
				var size := (cs.shape as RectangleShape2D).size
				rects.append(_r(Rect2(cs.global_position - size / 2.0, size)))
			elif cs != null and cs.shape is CircleShape2D:
				rects.append(["circle"] + _v(cs.global_position) + [(cs.shape as CircleShape2D).radius])
		out[String(zone.name)] = rects
	return out


static func _points(parent: Node) -> Dictionary:
	var out := {}
	if parent == null:
		return out
	for child in parent.get_children():
		if child is Node2D:
			out[String(child.name)] = _v((child as Node2D).global_position)
	return out


static func _targets(level: Node) -> Dictionary:
	var out := {}
	for node in level.find_children("*", "Node2D", true, false):
		if node is UseTargetBase and not (node.get_parent() is Animal):
			var slots: Array = []
			for child in node.get_children():
				if child is Marker2D:
					slots.append(_v((child as Marker2D).global_position))
			out[String(level.get_path_to(node))] = {"kind": (node as UseTargetBase).target_kind,
					"position": _v((node as Node2D).global_position), "slots": slots}
	return out


## Positions and footprints of the props that exist on main (names Prop<n> and Boulder<n> directly below Actors).
static func _legacy_props(level: Node) -> Dictionary:
	var out := {}
	for child in level.get_node("Actors").get_children():
		var n := String(child.name)
		if n.begins_with("Prop") or n.begins_with("Boulder"):
			var radius := float(child.get("footprint_radius")) if child is SwayProp else -1.0
			out[n] = {"position": _v((child as Node2D).global_position), "footprint_radius": radius}
	return out


## Snapshot of a level that is inside the tree (after _ready).
static func collect(level: LevelBase) -> Dictionary:
	var id := level.level_json_path.get_file().get_basename()
	var tiles := {}
	for layer_name in TILE_LAYERS:
		tiles[layer_name] = _bytes_hash((level.get_node(layer_name) as TileMapLayer).tile_map_data)
	return {
		"level_json_sha256": FileAccess.get_sha256(level.level_json_path),
		"layout_sha256": FileAccess.get_sha256(LAYOUT_DIR + id + ".layout.txt"),
		"zones": _zones(level),
		"home_points": _points(level.get_node("HomePoints")),
		"markers": _points(level.get_node("Markers")),
		"event_anchors": _points(level.get_node_or_null("EventAnchors")),
		"targets": _targets(level),
		"tiles": tiles,
		"solids": _solids(level),
		"legacy_props": _legacy_props(level),
	}


## Lines naming every difference between two snapshots (empty = equal).
static func diff(actual: Dictionary, expected: Dictionary) -> Array:
	var out: Array = []
	for key in expected:
		var a: Variant = JSON.parse_string(JSON.stringify(actual.get(key)))
		var e: Variant = expected[key]
		if JSON.stringify(a) != JSON.stringify(e):
			out.append("%s differs" % key)
	for key in actual:
		if not expected.has(key):
			out.append("%s missing in the fixture" % key)
	return out
