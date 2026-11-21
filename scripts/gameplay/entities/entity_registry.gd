class_name EntityRegistry
extends Node
## Per-level hub of all animals and items (group level_entity): serves the per-tick perception, answers zone and
## reachability queries, spreads throw impacts, builds the rules snapshot and applies event effects (panic,
## relocate) and the level restart. Entities find it through the group entity_registry; nothing registers itself.

const GROUP := "entity_registry"
const ENTITY_GROUP := "level_entity"
const BOUNDS_GROUP := "level_bounds"
const RESPAWN_AREA_GROUP := "respawn_area"
const CASTAWAY_GROUP := "castaway"
const REASON_WATER := "water"
const REASON_BOUNDS := "bounds"
const REASON_STUCK := "stuck"

var castaway: Node2D = null
var cfg: EntityConfig
var _protect: Callable
var _confine: Callable
var _frame := -1
var _entities: Array = []
var _kind_counts := {}
var _rng := SeededRng.new(1)


func _ready() -> void:
	add_to_group(GROUP)
	if cfg == null:
		cfg = EntityConfig.from_balance()


func set_castaway(node: Node2D) -> void:
	castaway = node


## predicate(info) -> bool marks protected entities, confine(info) -> zone id keeps an animal in that zone;
## info = {kind, zones, worn_by}. See EntityProtection.
func set_protection(predicate: Callable, confine: Callable = Callable()) -> void:
	_protect = predicate
	_confine = confine


## Re-reads the entities of the tree and gives every entity without uid a stable "<kind>_<n>".
func refresh() -> void:
	_entities = []
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(ENTITY_GROUP):
		if node is Node2D and is_instance_valid(node):
			_entities.append(node)
			if String(node.get("uid")) == "":
				var n: int = _kind_counts.get(node.get("kind"), 0) + 1
				_kind_counts[node.get("kind")] = n
				node.set("uid", "%s_%d" % [node.get("kind"), n])
	_frame = Engine.get_physics_frames()


## Adds an entity created at runtime.
func track(entity: Node2D) -> void:
	if not entity.is_in_group(ENTITY_GROUP):
		entity.add_to_group(ENTITY_GROUP)
	refresh()


func entities() -> Array:
	if _frame != Engine.get_physics_frames():
		refresh()
	return _entities.filter(func(e: Variant) -> bool: return is_instance_valid(e) and e.is_inside_tree())


func animals() -> Array:
	return entities().filter(func(e: Node) -> bool: return e.call("is_animal"))


func items() -> Array:
	return entities().filter(func(e: Node) -> bool: return not e.call("is_animal"))


func get_castaway() -> Node2D:
	if castaway != null and is_instance_valid(castaway) and castaway.is_inside_tree():
		return castaway
	return get_tree().get_first_node_in_group(CASTAWAY_GROUP) as Node2D if is_inside_tree() else null


# --- Perception -----------------------------------------------------------------------------

## The perception dictionary of AnimalBrain.tick for animal.
func perception_for(animal: Node2D) -> Dictionary:
	var pos := animal.global_position
	var lure := String(animal.get("def").get("lure_item", ""))
	var p := {"pos": pos, "castaway_pos": null, "castaway_vel": Vector2.ZERO, "castaway_dashing": false,
			"castaway_lure_carried": false, "lure_positions": [], "confine": confine_for(animal), "neighbors": []}
	var c := get_castaway()
	if c != null:
		p["castaway_pos"] = c.global_position
		p["castaway_vel"] = c.get("velocity") if c.get("velocity") is Vector2 else Vector2.ZERO
		if c.has_method("get_logic"):
			p["castaway_dashing"] = c.call("get_logic").is_dashing()
		var held: Variant = c.call("get_carried") if c.has_method("get_carried") else null
		p["castaway_lure_carried"] = lure != "" and held is Node and is_instance_valid(held) \
				and String(held.get("kind")) == lure
	var lures: Array = []
	var neighbors: Array = []
	for e in entities():
		if e == animal or not e.call("is_free"):
			continue
		if e.call("is_animal"):
			if e.global_position.distance_to(pos) < cfg.separation_radius:
				neighbors.append(e.global_position)
		elif lure != "" and String(e.get("kind")) == lure:
			lures.append(e.global_position)
	p["lure_positions"] = lures
	p["neighbors"] = neighbors
	return p


## The zone an animal is kept in: the zone of a done task it counts for, or a pen (contains = true) it entered.
func confine_for(entity: Node2D) -> Zone:
	var pos := entity.global_position
	var zones := _zone_nodes()
	if _confine.is_valid():
		var zone_id := String(_confine.call(_info(entity)))
		if zone_id != "":
			for zone: Zone in zones:
				if zone.zone_id == zone_id and zone.contains_point(pos):
					return zone
	for zone: Zone in zones:
		if zone.contains and zone.contains_with_margin(pos, cfg.settle_margin):
			return zone
	return null


func _zone_nodes() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	for node in get_tree().get_nodes_in_group(Zone.GROUP):
		if node is Zone and node.is_inside_tree():
			out.append(node)
	return out


## Ids of the zones containing the entity (computed from the shapes, valid without a physics frame).
func zones_of(entity: Node2D) -> Array:
	var out: Array = []
	for zone: Zone in _zone_nodes():
		if zone.zone_id != "" and zone.contains_point(entity.global_position) and not out.has(zone.zone_id):
			out.append(zone.zone_id)
	return out


## Why the entity cannot be reached: "bounds", "stuck", "water" (non-swimmers only) or "" when it is fine.
func unreachable_reason(entity: Node2D) -> String:
	var pos := entity.global_position
	for node in get_tree().get_nodes_in_group(BOUNDS_GROUP):
		if node.has_method("get_bounds_rect") and not (node.call("get_bounds_rect") as Rect2).has_point(pos):
			return REASON_BOUNDS
	if _overlaps(entity, pos, PhysicsLayers.BOUNDS):
		return REASON_BOUNDS
	if _overlaps(entity, pos, PhysicsLayers.WORLD_SOLID):
		return REASON_STUCK
	for area in get_tree().get_nodes_in_group(RESPAWN_AREA_GROUP):
		if Zone.area_contains(area, pos):
			return REASON_STUCK
	if not entity.call("is_swimmer"):
		if Grabbable.surface_at(get_tree(), pos) == Grabbable.SURFACE_WATER \
				or _overlaps(entity, pos, PhysicsLayers.WATER):
			return REASON_WATER
	return ""


func _overlaps(entity: Node2D, pos: Vector2, mask: int) -> bool:
	if not entity.is_inside_tree():
		return false
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if entity is CollisionObject2D:
		query.exclude = [entity.get_rid()]
	return not entity.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func is_protected(entity: Node2D) -> bool:
	if not _protect.is_valid():
		return false
	return bool(_protect.call(_info(entity)))


func _info(entity: Node2D) -> Dictionary:
	return {"kind": String(entity.get("kind")), "zones": zones_of(entity), "worn_by": String(entity.get("worn_by"))}


# --- Impacts ----------------------------------------------------------------------------------

## A thrown entity hit the ground at ground_pos (skim or landing): free animals within bonk_radius are bonked away,
## free items hop away. hits (instance id -> true) makes every entity react once per flight. Returns the count.
func impact(source: Node2D, ground_pos: Vector2, cause: String, hits: Dictionary) -> int:
	var count := 0
	for e in entities():
		if e == source or hits.has(e.get_instance_id()) or not e.call("is_free"):
			continue
		var offset: Vector2 = e.global_position - ground_pos
		if offset.length() > cfg.bonk_radius:
			continue
		hits[e.get_instance_id()] = true
		var dir := offset.normalized() if offset != Vector2.ZERO else Vector2.from_angle(_rng.randf() * TAU)
		if e.call("is_animal"):
			if e.call("bonk", dir, cause):
				count += 1
		else:
			e.call("nudge", dir)
			count += 1
	return count


# --- Snapshot and event effects -----------------------------------------------------------

## Entities for LevelSession.tick: [{uid, kind, zones, held_by, worn_by}] in tree order.
func snapshot_entities() -> Array:
	var out: Array = []
	for e in entities():
		out.append({"uid": String(e.get("uid")), "kind": String(e.get("kind")), "zones": zones_of(e),
				"held_by": String(e.call("held_by")), "worn_by": String(e.get("worn_by"))})
	return out


## Makes every free animal of kind panic; returns how many reacted.
func panic_kind(kind: String, seconds: float) -> int:
	var count := 0
	for e in animals():
		if String(e.get("kind")) == kind and _panic(e, seconds):
			count += 1
	return count


func panic_all(seconds: float) -> int:
	var count := 0
	for e in animals():
		if _panic(e, seconds):
			count += 1
	return count


func _panic(e: Node, seconds: float) -> bool:
	if not e.call("is_free") or e.get("brain").unreachable:
		return false
	e.call("panic", seconds)
	return true


## Moves every entity with this kind or uid to position, except carried, flying, worn and protected ones.
func relocate(kind_or_uid: String, position: Vector2) -> int:
	var count := 0
	for e in entities():
		if String(e.get("kind")) != kind_or_uid and String(e.get("uid")) != kind_or_uid:
			continue
		if not e.call("is_free") or is_protected(e):
			continue
		e.call("relocate_to", position)
		count += 1
	return count


## Level restart (A8): every entity back home with all states cleared.
func reset_all() -> void:
	for e in entities():
		e.call("reset_to_home")


## Finds an entity by uid, or null.
func find_uid(entity_uid: String) -> Node2D:
	for e in entities():
		if String(e.get("uid")) == entity_uid:
			return e
	return null
