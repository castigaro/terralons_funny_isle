extends "res://tests/support/level_case.gd"
## Shoreline, rocks, props and bounds block the castaway (also while dashing); surfaces come from the tiles.

const TILE := 128.0
const SOLID_MASK := PhysicsLayers.WORLD_SOLID | PhysicsLayers.WATER
const TICKS := 100

var _bad_overlap := 0
var _outside := 0


## Runs the castaway from start in direction dir for TICKS ticks, dashing every 25 ticks; checks every tick.
func _run(start: Vector2, dir: Vector2, dash: bool = true) -> Vector2:
	await place_castaway(start, dir.angle())
	move = dir.normalized()
	for i in TICKS:
		if dash and i % 25 == 5:
			press_dash()
		await physics_frames(1)
		var pos := castaway.global_position
		if _overlaps(pos, SOLID_MASK, castaway.cfg.body_radius - 1.0):
			_bad_overlap += 1
		if not level.get_bounds_rect().has_point(pos):
			_outside += 1
	move = Vector2.ZERO
	return castaway.global_position


func _overlaps(pos: Vector2, mask: int, radius: float = -1.0) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = radius if radius > 0.0 else castaway.cfg.body_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = mask
	query.exclude = [castaway.get_rid()]
	return not level.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func before_each() -> void:
	await open_level()
	_bad_overlap = 0
	_outside = 0


func test_shoreline_sides_block() -> void:
	var left := await _run(Vector2(400, 1000), Vector2.LEFT)
	check(left.x < TILE + 60.0, "reached the west shore: %s" % left)
	var top := await _run(Vector2(600, 400), Vector2.UP)
	check(top.y < TILE + 60.0, "reached the north shore: %s" % top)
	var bottom := await _run(Vector2(600, 1400), Vector2.DOWN)
	check(bottom.y > 13.0 * TILE - 60.0, "reached the south shore: %s" % bottom)
	var right := await _run(Vector2(2700, 1000), Vector2.RIGHT)
	check(right.x > 23.0 * TILE - 60.0, "reached the east shore: %s" % right)
	check_eq(_bad_overlap, 0, "ticks overlapping water or solids")
	check_eq(_outside, 0, "ticks outside the bounds")


func test_inner_and_outer_corners_block() -> void:
	# Outer corner: cell (1, 1); inner corner: cell (17, 4) with water on its north-east diagonal.
	var outer := await _run(Vector2(400, 400), Vector2(-1, -1))
	check(outer.distance_to(Vector2(TILE, TILE)) < 120.0, "pressed into the outer corner: %s" % outer)
	var corner := Vector2(18.0 * TILE, 4.0 * TILE)
	var up := await _run(corner + Vector2(12, 300), Vector2.UP)
	check(up.y > corner.y + 30.0 and up.y < corner.y + 70.0, "stopped below the notch: %s" % up)
	var east := await _run(corner + Vector2(-300, -12), Vector2.RIGHT)
	check(east.x < corner.x - 30.0 and east.x > corner.x - 70.0, "stopped left of the notch: %s" % east)
	await _run(corner + Vector2(-200, 200), Vector2(1, -1))
	check_eq(_bad_overlap, 0, "ticks overlapping water or solids")
	check_eq(_outside, 0, "ticks outside the bounds")


func test_rock_boulder_and_palm_block() -> void:
	var rock_centre := level.cell_center(Vector2i(14, 10))
	var at_rock := await _run(rock_centre + Vector2(0, 200), Vector2.UP)
	check(at_rock.y > rock_centre.y + 40.0, "rock tile blocks: %s" % at_rock)
	var boulder := (level.get_node("Actors/Boulder1") as Node2D).global_position
	var at_boulder := await _run(boulder + Vector2(0, 200), Vector2.UP)
	check(at_boulder.y > boulder.y + 44.0, "boulder blocks: %s" % at_boulder)
	var palm := (level.get_node("Actors/Palm2") as Node2D).global_position
	var at_palm := await _run(palm + Vector2(-220, 0), Vector2.RIGHT)
	check(at_palm.x < palm.x - 22.0, "palm trunk blocks: %s" % at_palm)
	check_eq(_bad_overlap, 0, "ticks overlapping water or solids")


func test_bounds_hold_with_dashes_in_all_directions() -> void:
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(1, 1), Vector2(-1, 1)]:
		await _run(Vector2(1300, 900), dir)
	check_eq(_outside, 0, "ticks outside the bounds")
	check_eq(_bad_overlap, 0, "ticks overlapping water or solids")


func test_surfaces() -> void:
	check_eq(level.get_surface_at(level.cell_center(Vector2i(2, 10))), "sand", "sand")
	check_eq(level.get_surface_at(level.cell_center(Vector2i(5, 7))), "grass", "grass")
	check_eq(level.get_surface_at(level.cell_center(Vector2i(4, 6))), "grass", "grass outer corner cell")
	check_eq(level.get_surface_at(level.cell_center(Vector2i(4, 6)) + Vector2(-60, -60)), "grass",
			"an edge tile reports grass for its whole cell")
	check_eq(level.get_surface_at(level.cell_center(Vector2i(17, 4))), "sand", "shore inner corner sand")
	check_eq(level.get_surface_at(level.cell_center(Vector2i(12, 3))), "stone", "stone")
	check_eq(level.get_surface_at(level.cell_center(Vector2i(1, 5))), "sand", "shore sand")
	check_eq(level.get_surface_at(level.cell_center(Vector2i(0, 0))), "water", "water")
	check_eq(level.get_surface_at(level.cell_center(Vector2i(20, 2))), "water", "notch water")
	check_eq(Grabbable.surface_at(tree(), level.cell_center(Vector2i(5, 7))), "grass", "via surface provider")
