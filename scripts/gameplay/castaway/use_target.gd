class_name UseTarget
extends RefCounted
## Contract for things the castaway can use a carried object on (cage, goat, delivery zone), duck-typed.
## A use target is a Node2D in group GROUP (or THROW_GROUP for aim-snap-only targets) with:
##   var target_kind: String    – for example "cage", "goat" or "delivery_zone"
##   func accepts(obj) -> bool  – whether the carried object can be used here
##   func use(obj) -> void      – takes the object (its on_released() was already called)

const GROUP := "use_target"
const THROW_GROUP := "throw_target"
const REQUIRED_METHODS := ["accepts", "use"]


static func is_valid(obj: Object) -> bool:
	if obj == null or not is_instance_valid(obj) or not "target_kind" in obj or not "global_position" in obj:
		return false
	for method in REQUIRED_METHODS:
		if not obj.has_method(method):
			return false
	return true
