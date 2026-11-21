class_name UseTargetBase
extends Node2D
## Shared base of the generic level use targets (UseTarget contract, docs/levels.md): joins the use_target group,
## finds its level and offers the helpers the targets need. Subclasses implement accepts(obj) and use(obj).

## Kind reported to the castaway, the HUD verb and delivered_to conditions; empty means the parent animal's kind.
@export var target_kind := ""
## Kinds of carried objects this target takes.
@export var accepted_kinds: PackedStringArray = PackedStringArray()


func _ready() -> void:
	add_to_group(UseTarget.GROUP)
	if target_kind == "" and get_parent() != null and "kind" in get_parent():
		target_kind = String(get_parent().get("kind"))


func level() -> LevelBase:
	var node := get_parent()
	while node != null and not node is LevelBase:
		node = node.get_parent()
	return node as LevelBase


func _kind_ok(obj: Object) -> bool:
	return obj != null and is_instance_valid(obj) and "kind" in obj and accepted_kinds.has(String(obj.get("kind")))


## False while the parent animal is carried or flying (the target rides along).
func _parent_free() -> bool:
	var p := get_parent()
	return p == null or not p.has_method("is_free") or bool(p.call("is_free"))


func accepts(obj: Object) -> bool:
	return _kind_ok(obj) and _parent_free()


func use(_obj: Object) -> void:
	pass
