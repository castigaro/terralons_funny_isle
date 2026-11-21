extends RefCounted
## Finds throw spots for the failure injection: a reachable cell plus a direction from which a throw of the carried
## entity lands on open water (inside the bounds, outside the kind's own target zones) and no use or throw target can
## capture it.
## Read-only: it only runs ray queries with the carried entity as the probe. Picks the spot nearest to the castaway
## in BFS order, so the choice is deterministic.

const DIRECTIONS := 16
## Candidate cells keep this distance beyond use_radius from every use and throw target.
const SPOT_MARGIN_PX := 64.0
## Directions that point at a target closer than the throw reach within the aim tolerance plus this are skipped.
const AIM_EXTRA_DEG := 10.0
## How far the castaway may walk on along the throw direction from a candidate cell centre.
const SHORE_SCAN_PX := 128.0

var driver: RefCounted
var _rejected := {}


func _init(level_driver: RefCounted) -> void:
	driver = level_driver


## Marks a spot as unusable (for example when the castaway could not throw from it in time).
func reject(spot: Dictionary) -> void:
	_rejected[_key(spot)] = true


## The nearest valid spot {cell: Vector2i, dir: Vector2} for the carried entity whose landing avoids avoid_zones,
## or {} when there is none.
func find(avoid_zones: Array = []) -> Dictionary:
	var castaway: Castaway = driver.castaway
	var level: LevelBase = driver.level
	var probe := castaway.get_carried()
	if probe == null:
		return {}
	var reach: float = castaway.get_logic().throw_reach()
	var targets := _targets(level)
	var keep_out: float = castaway.cfg.use_radius + SPOT_MARGIN_PX
	var aim_limit := deg_to_rad(castaway.cfg.throw_aim_tolerance_degrees + AIM_EXTRA_DEG)
	for cell in driver.cells_by_distance(level.cell_of(castaway.global_position)):
		var center := level.cell_center(cell)
		if not _cell_ok(level, center, targets, keep_out):
			continue
		for i in DIRECTIONS:
			var dir := Vector2.from_angle(TAU * float(i) / float(DIRECTIONS))
			var spot := {"cell": cell, "dir": dir}
			if _rejected.has(_key(spot)) or _aims_at_target(center, dir, reach, targets, aim_limit):
				continue
			var origin := _shore_point(level, center, dir, castaway)
			var landing := ThrowFlight.landing_point(probe, origin, origin + dir * reach, castaway.cfg.throw_wall_pad)
			if driver.is_open_water(landing, dir, avoid_zones):
				spot["origin"] = origin
				spot["landing"] = landing
				return spot
	return {}


## Where the castaway ends up when it walks from center along dir until something blocks it (at most
## SHORE_SCAN_PX): a motion cast of its own collision shape on its own mask. The driver walks on along dir until its
## predicted landing is valid, so heavy loads with a short reach are thrown from the shore line.
func _shore_point(level: LevelBase, center: Vector2, dir: Vector2, castaway: Castaway) -> Vector2:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = castaway.collision.shape
	query.transform = Transform2D(0.0, center)
	query.motion = dir * SHORE_SCAN_PX
	query.collision_mask = castaway.collision_mask
	query.exclude = [castaway.get_rid()]
	var fractions := level.get_world_2d().direct_space_state.cast_motion(query)
	var safe: float = fractions[0] if fractions.size() > 0 else 0.0
	return center + dir * SHORE_SCAN_PX * safe


func _targets(level: LevelBase) -> Array:
	var out: Array = []
	for group in [UseTarget.GROUP, UseTarget.THROW_GROUP]:
		for node in level.get_tree().get_nodes_in_group(group):
			if node is Node2D and level.is_ancestor_of(node) and not out.has(node):
				out.append(node)
	return out


func _cell_ok(level: LevelBase, center: Vector2, targets: Array, keep_out: float) -> bool:
	if not level.zones_at(center).is_empty():
		return false
	for area in level.get_tree().get_nodes_in_group(EntityRegistry.RESPAWN_AREA_GROUP):
		if Zone.area_contains(area, center):
			return false
	for target in targets:
		if (target as Node2D).global_position.distance_to(center) <= keep_out:
			return false
	return true


func _aims_at_target(center: Vector2, dir: Vector2, reach: float, targets: Array, limit: float) -> bool:
	for target in targets:
		var offset: Vector2 = (target as Node2D).global_position - center
		if offset.length() <= reach and absf(dir.angle_to(offset)) <= limit:
			return true
	return false


func _key(spot: Dictionary) -> String:
	return "%s|%s" % [str(spot["cell"]), str((spot["dir"] as Vector2).snapped(Vector2(0.001, 0.001)))]


## True when the level has any water inside its bounds outside avoid_zones (checked on cell centres).
func level_has_water(avoid_zones: Array = []) -> bool:
	var level: LevelBase = driver.level
	var b := level.get_bounds_rect()
	var first := level.cell_of(b.position)
	var last := level.cell_of(b.end)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var p := level.cell_center(Vector2i(x, y))
			if not b.has_point(p) or level.get_surface_at(p) != LevelBase.SURFACE_WATER:
				continue
			if not level.zones_at(p).any(func(z: String) -> bool: return avoid_zones.has(z)):
				return true
	return false
