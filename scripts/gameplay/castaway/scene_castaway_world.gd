class_name SceneCastawayWorld
extends CastawayWorld
## CastawayWorld over the scene tree: groups grabbable, use_target, throw_target and surface_provider.

var _node: Node


func _init(owner_node: Node) -> void:
	_node = owner_node


func grabbables(pos: Vector2, radius: float) -> Array:
	return _in_range(Grabbable.GROUP, pos, radius)


func use_targets(pos: Vector2, radius: float) -> Array:
	return _in_range(UseTarget.GROUP, pos, radius)


func throw_targets(pos: Vector2, radius: float) -> Array:
	var found := _in_range(UseTarget.GROUP, pos, radius)
	for target in _in_range(UseTarget.THROW_GROUP, pos, radius):
		if not found.has(target):
			found.append(target)
	return found


func surface_at(pos: Vector2) -> String:
	return Grabbable.surface_at(_tree(), pos)


func _tree() -> SceneTree:
	if _node == null or not is_instance_valid(_node) or not _node.is_inside_tree():
		return null
	return _node.get_tree()


func _in_range(group: String, pos: Vector2, radius: float) -> Array:
	var tree := _tree()
	var found := []
	if tree == null:
		return found
	for node in tree.get_nodes_in_group(group):
		if node is Node2D and node.is_inside_tree() and node.global_position.distance_to(pos) <= radius:
			found.append(node)
	return found
