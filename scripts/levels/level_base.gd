class_name LevelBase
extends Node2D
## Reusable level scene base: loads the level JSON into a LevelSession, owns the handcrafted TileMapLayers (painted
## offline by tools/build_level_layout.gd), the level bounds, spawn, home points, named zones and the camera, feeds
## the session a world snapshot every physics tick and runs the instant restart. Its EntityRegistry child owns the
## animals and items (snapshot entities, protection, respawn, restart reset). The whole level is always visible:
## there is no map generation and no hidden or revealed area. See docs/levels.md for the contract.

signal level_ready(level_id: String)
signal level_load_failed(path: String, errors: Array)
signal restarted(level_id: String)
signal exit_requested()

const SURFACE_WATER := "water"
const SURFACE_KEY := "surface"
## Surface lookup order, top layer first.
const SURFACE_LAYERS := ["Details", "Shore", "Grass", "Sand"]
## Layers whose cells count as land.
const LAND_LAYERS := ["Sand", "Shore"]
const REQUIRED_CHILDREN := ["WaterBackdrop", "Sand", "Grass", "Shore", "Details", "Actors", "Markers/Spawn",
		"HomePoints", "Zones", "Bounds", "EntityRegistry", "LevelCamera", "Overlay/LevelCue", "Overlay/LevelErrorPanel", "Overlay/Hud", "Prompts"]
const NEIGHBOURS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const RESTART_CUE_KEY := "level.restarted"
const PROMPT_SCENE := preload("res://scenes/ui/context_prompt.tscn")
const ANCHOR_PLAYER := "player"
const ANCHOR_ZONE := "zone:"
const ANCHOR_ENTITY := "entity:"
const ANCHOR_TARGET := "target:"

## Level file (res:// path), validated by LevelDef.
@export_file("*.json") var level_json_path := ""
## Catalogue folders whose texts the level keys may use (tests add their fixture catalogue).
@export var i18n_dirs: PackedStringArray = PackedStringArray(["res://i18n"])
@export var session_options: Dictionary = {"schedule_mode": "seeded"}
## Start the session right after loading; the level flow (intro) sets false and calls start_level() itself.
@export var autostart := true
## Handle the restart action here; a pause menu owner may switch this off.
@export var handle_restart_key := true
## Handle the finish action here (ends the level once the required tasks are done, D-3).
@export var handle_finish_key := true
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
const RESULT_RESTORED_PATHS := ["Overlay/Hud", "Prompts"]
const RESULT_CUE_PATH := "Overlay/LevelCue"

var _registry: EntityRegistry
var _protection: EntityProtection
var _messages := {}
var _prompt_problems: Array = []
## Event surface overrides: key -> {zone: Zone, surface: String}, checked before the tiles.
var _surface_overrides := {}
## Visibility of the HUD, cue and prompt layers before the result screen hid them (node path -> visible).
var _result_hidden := {}
var _result_on := false


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
	_registry = $EntityRegistry as EntityRegistry
	for child in $Zones.get_children():
		if child is Zone and (child as Zone).zone_id == "":
			(child as Zone).zone_id = String(child.name)
	_bounds = bounds_override if bounds_override.has_area() else _land_rect()
	add_to_group(EntityRegistry.BOUNDS_GROUP)
	_build_bounds()
	_size_backdrop()
	var loaded := _load_def()
	if not loaded.is_empty():
		_fail(loaded)
		return
	_registry.set_castaway(_castaway)
	_registry.refresh()
	var missing := _contract_problems()
	if not missing.is_empty():
		_fail(missing)
		return
	_session = LevelSession.new(_def, EventBus, Balance.get_section("rules"), session_options)
	_protection = EntityProtection.new(_session, _def)
	_registry.set_protection(_protection.is_protected, _protection.confine_zone)
	_camera.setup(_castaway, _bounds)
	if _castaway.has_method("reset_to"):
		_castaway.call("reset_to", spawn_position(), spawn_facing())
	_camera.snap()
	($Prompts as Node2D).z_index = int(Balance.get_section("hud").get("prompt_z", 0))
	(get_node("Overlay/Hud") as Hud).bind_level(self)
	_spawn_prompts()
	level_ready.emit(_def.id)
	if autostart:
		start_level()


# --- Loading -------------------------------------------------------------------------------------------

func _load_def() -> Array:
	var messages := {}
	for dir in i18n_dirs:
		messages.merge(I18n.parse_dir(dir)["messages"])
	_messages = messages
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
	var file := level_json_path.get_file()
	for zone_id in required_zone_ids(_def):
		if zone(zone_id) == null:
			problems.append("%s: zone %s used by a task is missing under Zones" % [file, zone_id])
	problems.append_array(zone_problems())
	return problems


## Zone contract: every child of Zones is a Zone whose node name equals its zone_id and whose shapes are
## rectangles or circles in CollisionShape2D nodes (the only shapes Zone.area_contains supports).
func zone_problems() -> Array:
	var problems: Array = []
	for child in $Zones.get_children():
		if not child is Zone:
			problems.append("%s: Zones/%s is not a Zone" % [name, child.name])
			continue
		var z := child as Zone
		if z.zone_id != String(z.name):
			problems.append("%s: zone node %s has zone_id %s (must match)" % [name, z.name, z.zone_id])
		var shapes := 0
		for part in z.get_children():
			var cs := part as CollisionShape2D
			if cs != null and (cs.shape is RectangleShape2D or cs.shape is CircleShape2D):
				shapes += 1
			elif part is CollisionShape2D or part is CollisionPolygon2D:
				problems.append("%s: zone %s uses an unsupported shape %s (rectangle or circle only)"
						% [name, z.name, part.name])
		if shapes == 0:
			problems.append("%s: zone %s has no rectangle or circle shape" % [name, z.name])
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


func hud() -> Hud:
	return get_node_or_null("Overlay/Hud") as Hud


## Translated text of a key: the game catalogue first, then the level's extra catalogues (i18n_dirs).
func text(key: String) -> String:
	if I18n.has_key(key) or not _messages.has(key):
		return I18n.t(key)
	return text_in(key, I18n.get_locale())


## Text of a key in a locale from the game or level catalogue ("" when missing).
func text_in(key: String, locale: String) -> String:
	if I18n.has_key(key):
		return I18n.text_in(key, locale)
	var entry: Dictionary = _messages.get(key, {})
	return String(entry.get(locale, entry.get("en", "")))


# --- Contextual prompts -----------------------------------------------------------------------------------

## The node a prompt anchor names: player -> castaway, zone:<id> -> Zone, entity:<uid> -> animal or item,
## target:<kind> -> the first use target of the level with that target_kind (tree order).
func resolve_anchor(anchor: String) -> Node2D:
	if anchor == ANCHOR_PLAYER:
		return _castaway
	if anchor.begins_with(ANCHOR_ZONE):
		return zone(anchor.trim_prefix(ANCHOR_ZONE))
	if anchor.begins_with(ANCHOR_ENTITY) and _registry != null:
		return _registry.find_uid(anchor.trim_prefix(ANCHOR_ENTITY))
	if anchor.begins_with(ANCHOR_TARGET) and is_inside_tree():
		var kind := anchor.trim_prefix(ANCHOR_TARGET)
		for node in get_tree().get_nodes_in_group(UseTarget.GROUP):
			if node is Node2D and is_ancestor_of(node) and String(node.get("target_kind")) == kind:
				return node as Node2D
	return null


## Instances a ContextPrompt for every level prompt whose action the player has not used yet.
func _spawn_prompts() -> void:
	var holder := $Prompts
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	for prompt in _def.prompts:
		if PromptMemory.is_used(String(prompt["action"])):
			continue
		var anchor := resolve_anchor(String(prompt["anchor"]))
		if anchor == null:
			_report_prompt_problem("%s: prompt %s: anchor %s not found in the level"
					% [level_json_path.get_file(), prompt["id"], prompt["anchor"]])
			continue
		var node := PROMPT_SCENE.instantiate() as ContextPrompt
		node.setup(prompt, anchor, self)
		holder.add_child(node)


## Records a prompt that cannot be placed once; the prompt is skipped and the level keeps running.
func _report_prompt_problem(message: String) -> void:
	if _prompt_problems.has(message):
		return
	_prompt_problems.append(message)
	print("LevelBase: %s (prompt skipped)" % message)


## Prompts of the level data that could not be placed (unresolved anchors); never shown to the player.
func prompt_problems() -> Array:
	return _prompt_problems.duplicate()


## Live prompt nodes (freed ones excluded).
func prompts() -> Array:
	return $Prompts.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())


func camera() -> LevelCamera:
	return _camera


## The EventEffects child that applies the event effects to the world (null in levels without one).
func event_effects() -> EventEffects:
	return get_node_or_null("EventEffects") as EventEffects


## The FeedbackDirector child (null in levels without one).
func feedback_director() -> FeedbackDirector:
	return get_node_or_null("FeedbackDirector") as FeedbackDirector


## Result mode hides the HUD, the level cue and the world prompts and suppresses popup words, so the result screen
## shows the only headline. Off restores the remembered HUD and prompt visibility; the cue manages its own visibility
## and comes back with its next show_key (for example "Restarted!"). Calling on twice keeps the first memory.
func set_result_mode(on: bool) -> void:
	if on:
		if _result_hidden.is_empty():
			for path in RESULT_RESTORED_PATHS:
				var node := get_node_or_null(path)
				if node != null:
					_result_hidden[path] = bool(node.get("visible"))
		for path in _result_hidden:
			get_node(String(path)).set("visible", false)
		var cue := get_node_or_null(RESULT_CUE_PATH)
		if cue != null:
			cue.set("visible", false)
	else:
		for path in _result_hidden:
			var node := get_node_or_null(String(path))
			if node != null:
				node.set("visible", bool(_result_hidden[path]))
		_result_hidden.clear()
	_result_on = on
	var director := feedback_director()
	if director != null:
		director.set_text_suppressed(on)


func result_mode() -> bool:
	return _result_on


## Forwards a delivery by a use target to the session (delivered_to conditions); ignored while failed.
func report_delivery(entity: String, target: String) -> void:
	if _failed or _session == null:
		return
	_session.report_delivery(entity, target)


func entity_registry() -> EntityRegistry:
	return _registry


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
	clear_surface_overrides()
	if _castaway.has_method("reset_to"):
		_castaway.call("reset_to", spawn_position(), spawn_facing())
	_registry.reset_all()
	_camera.snap()
	_spawn_prompts()
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
	elif handle_finish_key and event.is_action_pressed("finish") and not event.is_echo():
		if finish_level():
			get_viewport().set_input_as_handled()


## Ends the level as won when the required tasks are done; false otherwise (no side effects).
func finish_level() -> bool:
	if _failed or _session == null:
		return false
	return _session.finish()


# --- Snapshot -------------------------------------------------------------------------------------------

## World snapshot for LevelSession.tick (format in docs/rules.md); the entities come from the EntityRegistry.
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
	var entities: Array = _registry.snapshot_entities() if _registry != null else []
	return {"player": player, "entities": entities}


func _kind_of(obj: Variant) -> String:
	if obj is Object and obj != null and is_instance_valid(obj) and "kind" in obj:
		return String(obj.get("kind"))
	return ""


# --- Zones, markers and bounds ----------------------------------------------------------------------------

## The Zone below Zones whose zone_id is zone_id, or null.
func zone(zone_id: String) -> Zone:
	for child in $Zones.get_children():
		if child is Zone and (child as Zone).zone_id == zone_id:
			return child
	return null


func zone_ids() -> Array:
	var ids: Array = []
	for child in $Zones.get_children():
		if child is Zone:
			ids.append((child as Zone).zone_id)
	ids.sort()
	return ids


## Sorted ids of the level zones containing a global point, computed from the zone shapes (same rule as
## EntityRegistry.zones_of, valid in the same frame without a physics query).
func zones_at(pos: Vector2) -> Array:
	var ids := {}
	for child in $Zones.get_children():
		if child is Zone and (child as Zone).zone_id != "" and (child as Zone).contains_point(pos):
			ids[(child as Zone).zone_id] = true
	var out := ids.keys()
	out.sort()
	return out


## Level bounds in world coordinates (group level_bounds contract of the EntityRegistry).
func get_bounds_rect() -> Rect2:
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
	var keys := _surface_overrides.keys()
	keys.sort()
	for key in keys:
		var entry: Dictionary = _surface_overrides[key]
		var z := entry["zone"] as Zone
		if z != null and is_instance_valid(z) and z.contains_point(pos):
			return String(entry["surface"])
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


## Makes every point inside zone report surface until the override with this key is cleared (events).
func set_surface_override(key: String, area: Zone, surface: String) -> void:
	if area == null:
		return
	_surface_overrides[key] = {"zone": area, "surface": surface}


func clear_surface_override(key: String) -> void:
	_surface_overrides.erase(key)


func clear_surface_overrides() -> void:
	_surface_overrides.clear()


func surface_override_keys() -> Array:
	var keys := _surface_overrides.keys()
	keys.sort()
	return keys


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


## Walkable land cells, except cells whose centre lies in a respawn_area (closed pockets, see docs/levels.md).
func walkable_cells() -> Array:
	var cells := {}
	for layer_name in LAND_LAYERS:
		for cell in (get_node(layer_name) as TileMapLayer).get_used_cells():
			cells[cell] = true
	var pockets: Array = []
	for area in get_tree().get_nodes_in_group(EntityRegistry.RESPAWN_AREA_GROUP):
		if is_ancestor_of(area):
			pockets.append(area)
	var out: Array = []
	for cell in cells:
		if pockets.any(func(area: Node) -> bool: return Zone.area_contains(area, cell_center(cell))):
			continue
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
