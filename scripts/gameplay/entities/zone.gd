class_name Zone
extends Area2D
## A named level zone (cage, pond, beach). Containment is computed from the CollisionShape2D geometry (rectangle
## or circle with the global transform), so it is valid in the same frame without waiting for physics.
## contains = true marks a pen: an animal that entered it stays inside on its own (only carrying takes it out).

const GROUP := "level_zone"

@export var zone_id := ""
@export var contains := false


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = PhysicsLayers.ZONES
	collision_mask = 0
	monitoring = false


func contains_point(p: Vector2) -> bool:
	return area_contains(self, p)


## Returns p moved inside the zone shrunk by margin (p itself when it already is inside).
func clamp_inside(p: Vector2, margin: float) -> Vector2:
	var shape := _shape_node(self)
	if shape == null:
		return p
	var xf := shape.global_transform
	var local := xf.affine_inverse() * p
	if shape.shape is RectangleShape2D:
		var half: Vector2 = (shape.shape as RectangleShape2D).size / 2.0
		var inner := Vector2(maxf(0.0, half.x - margin), maxf(0.0, half.y - margin))
		local = Vector2(clampf(local.x, -inner.x, inner.x), clampf(local.y, -inner.y, inner.y))
	elif shape.shape is CircleShape2D:
		var r := maxf(0.0, (shape.shape as CircleShape2D).radius - margin)
		local = local.limit_length(r)
	return xf * local


## A seeded random point inside the zone shrunk by margin.
func random_point(rng: SeededRng, margin: float) -> Vector2:
	var shape := _shape_node(self)
	if shape == null:
		return global_position
	var local := Vector2.ZERO
	if shape.shape is RectangleShape2D:
		var half: Vector2 = (shape.shape as RectangleShape2D).size / 2.0
		local = Vector2(rng.randf_range(-1.0, 1.0) * maxf(0.0, half.x - margin),
				rng.randf_range(-1.0, 1.0) * maxf(0.0, half.y - margin))
	elif shape.shape is CircleShape2D:
		var r := maxf(0.0, (shape.shape as CircleShape2D).radius - margin)
		local = Vector2.from_angle(rng.randf() * TAU) * r * sqrt(rng.randf())
	return shape.global_transform * local


## True when p lies inside the zone by at least margin.
func contains_with_margin(p: Vector2, margin: float) -> bool:
	return contains_point(p) and clamp_inside(p, margin).is_equal_approx(p)


## Point containment for any Area2D with rectangle or circle shapes (also used for respawn areas).
static func area_contains(area: Node, p: Vector2) -> bool:
	if area == null or not is_instance_valid(area) or not area.is_inside_tree():
		return false
	for child in area.get_children():
		var shape := child as CollisionShape2D
		if shape == null or shape.disabled or shape.shape == null:
			continue
		var local := shape.global_transform.affine_inverse() * p
		if shape.shape is RectangleShape2D:
			var half: Vector2 = (shape.shape as RectangleShape2D).size / 2.0
			if absf(local.x) <= half.x and absf(local.y) <= half.y:
				return true
		elif shape.shape is CircleShape2D:
			if local.length() <= (shape.shape as CircleShape2D).radius:
				return true
	return false


static func _shape_node(area: Node) -> CollisionShape2D:
	for child in area.get_children():
		if child is CollisionShape2D and child.shape != null:
			return child
	return null
