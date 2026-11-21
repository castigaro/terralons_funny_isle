class_name LevelBase
extends Node2D
## Reusable level scene base: loads the level JSON into a LevelSession, owns the handcrafted TileMapLayers (painted
## offline by tools/build_level_layout.gd), the level bounds, spawn, home points, named zones and the camera, feeds
## the session a world snapshot every physics tick and runs the instant restart. The whole level is always visible:
## there is no map generation and no hidden or revealed area. See docs/levels.md for the contract.

signal level_ready(level_id: String)
signal level_load_failed(path: String, errors: Array)
signal restarted(level_id: String)
signal exit_requested()

const PLAYER := "player"
const ENTITY_GROUP := "level_entity"
const SURFACE_WATER := "water"
const SURFACE_KEY := "surface"
## Surface lookup order, top layer first.
const SURFACE_LAYERS := ["Details", "Shore", "Grass", "Sand"]
## Layers whose cells count as land.
const LAND_LAYERS := ["Sand", "Shore"]
const REQUIRED_CHILDREN := ["WaterBackdrop", "Sand", "Grass", "Shore", "Details", "Actors", "Markers/Spawn",
		"HomePoints", "Zones", "Bounds", "LevelCamera", "Overlay/LevelCue", "Overlay/LevelErrorPanel"]
const NEIGHBOURS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const RESTART_CUE_KEY := "level.restarted"

## Level file (res:// path), validated by LevelDef.
@export_file("*.json") var level_json_path := ""
## Catalogue folders whose texts the level keys may use (tests add their fixture catalogue).
@export var i18n_dirs: PackedStringArray = PackedStringArray(["res://i18n"])
@export var session_options: Dictionary = {"schedule_mode": "seeded"}
## Start the session right after loading; the level flow (intro) sets false and calls start_level() itself.
@export var autostart := true
## Handle the restart action here; a pause menu owner may switch this off.
@export var handle_restart_key := true
## Explicit level bounds; a zero size means the rectangle of all land cells.
@export var bounds_override := Rect2()
@export var castaway_path: NodePath = ^"Actors/Castaway"
## Report load errors with push_error (tests switch this off and read load_errors()).
@export var push_errors := true

var _failed := false
var _errors: Array = []
var _def: LevelDef
var _session: LevelSession
var _bounds := Rect2()
var _cfg := {}
var _castaway: Node2D
var _camera: LevelCamera


func _ready() -> void:
	add_to_group(Grabbable.SURFACE_PROVIDER_GROUP)
	_cfg = Balance.get_section("level")
	var problems: Array = []
	for path in REQUIRED_CHILDREN:
		if get_node_or_null(path) == null:
			problems.append("%s: missing child node %s" % [name, path])
	_castaway = get_node_or_null(castaway_path) as Node2D
	if _castaway == null:
		problems.append("%s: missing castaway at %s" % [name, castaway_path])
	if not problems.is_empty():
		_fail(problems)
		return
	_camera = $LevelCamera
	_bounds = bounds_override if bounds_override.has_area() else _land_rect()
	_build_bounds()
	_size_backdrop()
	var loaded := _load_def()
	if not loaded.is_empty():
		_fail(loaded)
		return
	var missing := _contract_problems()
	if not missing.is_empty():
		_fail(missing)
		return
	_session = LevelSession.new(_def, EventBus, Balance.get_section("rules"), session_options)
	_camera.setup(_castaway, _bounds)
	if _castaway.has_method("reset_to"):
		_castaway.call("reset_to", spawn_position(), spawn_facing())
	_camera.snap()
	level_ready.emit(_def.id)
	if autostart:
		start_level()


# --- Loading -------------------------------------------------------------------------------------------

func _load_def() -> Array:
	var messages := {}
	for dir in i18n_dirs:
		messages.merge(I18n.parse_dir(dir)["messages"])
	var types := LevelDef.load_event_types()
	if not types["errors"].is_empty():
		return types["errors"]
	var ctx := LevelDef.make_context(Balance.get_section("rules"), types["types"], messages)
	var res := LevelDef.load_file(level_json_path, ctx)
	if not res["ok"]:
		return res["errors"] if not res["errors"].is_empty() else ["%s: invalid level" % level_json_path]
	_def = res["def"]
	return []


func _contract_problems() -> Array:
	var problems: Array = []
	for zone_id in required_zone_ids(_def):
		if zone(zone_id) == null:
			problems.append("%s: zone %s used by a task is missing under Zones" % [level_json_path.get_file(), zone_id])
	return problems


## Returns the sorted zone ids that the tasks of a level reference in conditions and modifiers.
static func required_zone_ids(def: LevelDef) -> Array:
	var found := {}
	if def == null:
		return []
	for task in def.tasks:
		for cond in task["conditions"] + task["modifiers"]:
			if cond.has("zone"):
				found[String(cond["zone"])] = true
	var ids := found.keys()
	ids.sort()
	return ids


func _fail(errors: Array) -> void:
	_failed = true
	_errors = errors.duplicate()
	if push_errors:
		for line in _errors:
			push_error("Level: %s" % line)
	var castaway_node := get_node_or_null(castaway_path)
	if castaway_node != null:
		castaway_node.process_mode = Node.PROCESS_MODE_DISABLED
	var panel := get_node_or_null("Overlay/LevelErrorPanel")
	if panel != null:
		if not panel.is_connected("back_pressed", _on_back_pressed):
			panel.connect("back_pressed", _on_back_pressed)
		panel.call("show_error", level_json_path)
	level_load_failed.emit(level_json_path, _errors.duplicate())


func _on_back_pressed() -> void:
	if exit_requested.get_connections().is_empty():
		get_tree().change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	else:
		exit_requested.emit()


func is_failed() -> bool:
	return _failed


func load_errors() -> Array:
	return _errors.duplicate()


# --- Session lifecycle ----------------------------------------------------------------------------------

func level_session() -> LevelSession:
	return _session


func level_def() -> LevelDef:
	return _def


func castaway() -> Node2D:
	return _castaway


func camera() -> LevelCamera:
	return _camera


func start_level() -> void:
	if _failed or _session == null:
		return
	if _session.get_state() == LevelSession.State.READY:
		_session.start()


## Instant restart: fresh session, castaway and entities back home and the camera snapped, all in one frame.
func restart_level() -> void:
	if _failed or _session == null:
		return
	_session.restart()
	_session.start()
	if _castaway.has_method("reset_to"):
		_castaway.call("reset_to", spawn_position(), spawn_facing())
	for node in _entities():
		if node.has_method("reset_to_home"):
			node.call("reset_to_home")
	_camera.snap()
	var cue := get_node_or_null("Overlay/LevelCue")
	if cue != null:
		cue.call("show_key", RESTART_CUE_KEY, float(_cfg.get("restart_cue_seconds", 1.0)))
	restarted.emit(_def.id)
	EventBus.level_restarted.emit(_def.id)


func _physics_process(delta: float) -> void:
	if _failed or _session == null:
		return
	var state := _session.get_state()
	if state == LevelSession.State.RUNNING or state == LevelSession.State.REQUIRED_DONE:
		_session.tick(delta, build_snapshot())


func _unhandled_input(event: InputEvent) -> void:
	if handle_restart_key and event.is_action_pressed("restart") and not event.is_echo():
		restart_level()
		get_viewport().set_input_as_handled()


# --- Snapshot -------------------------------------------------------------------------------------------

## World snapshot for LevelSession.tick (format in docs/rules.md).
func build_snapshot() -> Dictionary:
	var player := {"zones": [], "held": "", "worn": "", "stunned": false}
	if _castaway != null:
		player["zones"] = zones_at(_castaway.global_position)
		var carried: Variant = _castaway.call("get_carried") if _castaway.has_method("get_carried") else null
		player["held"] = _kind_of(carried)
		if _castaway.has_method("get_worn_kind"):
			player["worn"] = String(_castaway.call("get_worn_kind"))
		if _castaway.has_method("is_dizzy"):
			player["stunned"] = bool(_castaway.call("is_dizzy"))
	var entities: Array = []
	for node in _entities():
		var held_by: Variant = node.get("held_by")
		var worn_by: Variant = node.get("worn_by")
		var held := ""
		if held_by is Object and held_by != null and held_by == _castaway:
			held = PLAYER
		elif held_by is String or held_by is StringName:
			held = String(held_by)
		entities.append({
			"uid": String(node.get("uid")),
			"kind": _kind_of(node),
			"zones": zones_at(node.global_position),
			"held_by": held,
			"worn_by": String(worn_by) if worn_by is String or worn_by is StringName else "",
		})
	return {"player": player, "entities": entities}


func _entities() -> Array:
	var found: Array = []
	for node in get_tree().get_nodes_in_group(ENTITY_GROUP):
		if node is Node2D and is_ancestor_of(node):
			found.append(node)
	found.sort_custom(func(a: Node, b: Node) -> bool: return String(a.get("uid")) < String(b.get("uid")))
	return found


func _kind_of(obj: Variant) -> String:
	if obj is Object and obj != null and is_instance_valid(obj) and "kind" in obj:
		return String(obj.get("kind"))
	return ""


# --- Zones, markers and bounds ----------------------------------------------------------------------------

func zone(zone_id: String) -> LevelZone:
	return get_node_or_null("Zones/" + zone_id) as LevelZone


func zone_ids() -> Array:
	var ids: Array = []
	for child in $Zones.get_children():
		if child is LevelZone:
			ids.append(String(child.name))
	ids.sort()
	return ids


## Sorted ids of the zones containing a global point (physics point query on the zones layer).
func zones_at(pos: Vector2) -> Array:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = PhysicsLayers.ZONES
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var ids := {}
	for hit in get_world_2d().direct_space_state.intersect_point(query, int(_cfg.get("max_zone_hits", 1))):
		var area: Object = hit.get("collider")
		if area is LevelZone and is_ancestor_of(area):
			ids[(area as LevelZone).zone_id()] = true
	var out := ids.keys()
	out.sort()
	return out


func get_bounds() -> Rect2:
	return _bounds


func spawn_position() -> Vector2:
	return ($Markers/Spawn as Node2D).global_position


func spawn_facing() -> float:
	return ($Markers/Spawn as Node2D).global_rotation


func has_home_point(uid: String) -> bool:
	return get_node_or_null("HomePoints/" + uid) is Node2D


## Global position of the home point of an entity uid (spawn position when missing).
func home_point(uid: String) -> Vector2:
	var marker := get_node_or_null("HomePoints/" + uid) as Node2D
	return marker.global_position if marker != null else spawn_position()


func backdrop_rect() -> Rect2:
	var backdrop := $WaterBackdrop as Sprite2D
	return Rect2(backdrop.global_position, backdrop.region_rect.size * backdrop.global_scale)


func _land_rect() -> Rect2:
	var used := Rect2i()
	for layer_name in LAND_LAYERS:
		var rect := (get_node(layer_name) as TileMapLayer).get_used_rect()
		if rect.has_area():
			used = rect if not used.has_area() else used.merge(rect)
	var sand := $Sand as TileMapLayer
	if not used.has_area() or sand.tile_set == null:
		return Rect2(global_position, Vector2.ZERO)
	var tile := Vector2(sand.tile_set.tile_size)
	var top_left := sand.to_global(sand.map_to_local(used.position) - tile / 2.0)
	return Rect2(top_left, Vector2(used.size) * tile)


func _build_bounds() -> void:
	var body := $Bounds as StaticBody2D
	body.collision_layer = PhysicsLayers.BOUNDS
	body.collision_mask = 0
	for child in body.get_children():
		body.remove_child(child)
		child.free()
	var t := float(_cfg.get("bounds_thickness", 1.0))
	var b := _bounds
	var rects := [
		Rect2(b.position.x - t, b.position.y - t, b.size.x + t * 2.0, t),
		Rect2(b.position.x - t, b.end.y, b.size.x + t * 2.0, t),
		Rect2(b.position.x - t, b.position.y, t, b.size.y),
		Rect2(b.end.x, b.position.y, t, b.size.y),
	]
	for i in rects.size():
		var rect: Rect2 = rects[i]
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var cs := CollisionShape2D.new()
		cs.name = "Side%d" % i
		cs.shape = shape
		body.add_child(cs)
		cs.global_position = rect.get_center()


func _size_backdrop() -> void:
	var backdrop := $WaterBackdrop as Sprite2D
	var view := Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width")),
			float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	var margin := view * float(_cfg.get("backdrop_margin_viewports", 1.0))
	var rect := _bounds.grow_individual(margin.x, margin.y, margin.x, margin.y)
	backdrop.centered = false
	backdrop.region_enabled = true
	backdrop.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	backdrop.global_position = rect.position
	backdrop.region_rect = Rect2(Vector2.ZERO, rect.size)
	ArtPalette.apply_to(backdrop.material)


# --- Surfaces and walkable cells ----------------------------------------------------------------------

## Surface under a global point: stone, grass or sand from the top-most tile with surface data, else water.
func get_surface_at(pos: Vector2) -> String:
	for layer_name in SURFACE_LAYERS:
		var layer := get_node_or_null(layer_name) as TileMapLayer
		if layer == null:
			continue
		var data := layer.get_cell_tile_data(layer.local_to_map(layer.to_local(pos)))
		if data != null:
			var surface := String(data.get_custom_data(SURFACE_KEY))
			if surface != "":
				return surface
	return SURFACE_WATER


func cell_of(pos: Vector2) -> Vector2i:
	var sand := $Sand as TileMapLayer
	return sand.local_to_map(sand.to_local(pos))


func cell_center(cell: Vector2i) -> Vector2:
	var sand := $Sand as TileMapLayer
	return sand.to_global(sand.map_to_local(cell))


func is_land_cell(cell: Vector2i) -> bool:
	for layer_name in LAND_LAYERS:
		if (get_node(layer_name) as TileMapLayer).get_cell_source_id(cell) != -1:
			return true
	return false


## True for a land cell whose centre has room for a body (no water strip, rock, prop footprint or bound there).
## Needs at least one physics frame after _ready so that tile and prop collision exists.
func is_walkable_cell(cell: Vector2i) -> bool:
	if not is_land_cell(cell):
		return false
	var circle := CircleShape2D.new()
	circle.radius = float(_cfg.get("walkable_probe_radius", 1.0))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, cell_center(cell))
	query.collision_mask = PhysicsLayers.WORLD_SOLID | PhysicsLayers.WATER | PhysicsLayers.BOUNDS
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func walkable_cells() -> Array:
	var cells := {}
	for layer_name in LAND_LAYERS:
		for cell in (get_node(layer_name) as TileMapLayer).get_used_cells():
			cells[cell] = true
	var out: Array = []
	for cell in cells:
		if is_walkable_cell(cell):
			out.append(cell)
	out.sort()
	return out


## 4-neighbour flood fill over the walkable cells: returns {cell: true} of every cell reachable from start.
func reachable_from(start: Vector2i) -> Dictionary:
	var walkable := {}
	for cell in walkable_cells():
		walkable[cell] = true
	var seen := {}
	if not walkable.has(start):
		return seen
	seen[start] = true
	var queue: Array = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for step in NEIGHBOURS:
			var n: Vector2i = c + step
			if walkable.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen
