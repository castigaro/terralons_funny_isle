class_name WearTarget
extends UseTargetBase
## Use target on an animal that can wear an item (a hat on the goat): placed as a child of the animal, it puts a
## carried wearable item of an accepted kind on its parent (worn conditions) while the animal wears nothing yet.


func accepts(obj: Object) -> bool:
	if not super.accepts(obj) or not obj.has_method("is_wearable") or not obj.call("is_wearable"):
		return false
	return worn_item() == null


## The item the parent animal wears, or null.
func worn_item() -> Node2D:
	var lvl := level()
	var reg := lvl.entity_registry() if lvl != null else null
	if reg == null:
		return null
	for item in reg.items():
		if item.get("wearer") == get_parent():
			return item
	return null


func use(obj: Object) -> void:
	obj.call("wear_on", get_parent(), target_kind)
