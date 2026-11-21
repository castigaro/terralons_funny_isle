class_name Grabbable
extends RefCounted
## Contract for things the castaway can grab (duck-typed, because animals and items use different base classes).
## A grabbable is a Node2D in group GROUP with:
##   var kind: String                  – for example "coconut" or "chicken"
##   func can_grab() -> bool           – false while held, in flight or otherwise unavailable
##   func on_grabbed(carrier: Node2D)  – disable own collision and behaviour; the carrier moves it each tick
##   func on_released() -> void        – called after a drop, after a throw landing and before a use
##   func get_throw_visual() -> Node2D – optional: the child that is lifted during a throw arc
## Surfaces are reported by a node in group SURFACE_PROVIDER_GROUP with get_surface_at(global_pos) -> String.

const GROUP := "grabbable"
const SURFACE_PROVIDER_GROUP := "surface_provider"
const SURFACE_SAND := "sand"
const SURFACE_GRASS := "grass"
const SURFACE_WATER := "water"
const REQUIRED_METHODS := ["can_grab", "on_grabbed", "on_released"]


static func is_valid(obj: Object) -> bool:
	if obj == null or not is_instance_valid(obj) or not "kind" in obj or not "global_position" in obj:
		return false
	for method in REQUIRED_METHODS:
		if not obj.has_method(method):
			return false
	return true


## Returns the surface at pos from the first surface provider of the tree, "sand" without a provider.
static func surface_at(tree: SceneTree, pos: Vector2) -> String:
	if tree == null:
		return SURFACE_SAND
	var provider := tree.get_first_node_in_group(SURFACE_PROVIDER_GROUP)
	if provider == null or not provider.has_method("get_surface_at"):
		return SURFACE_SAND
	return String(provider.call("get_surface_at", pos))
