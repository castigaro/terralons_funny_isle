extends RefCounted
## Plain stand-in for pure logic tests: a grabbable (kind) and/or a use target (target_kind) with a position.

var kind := ""
var target_kind := ""
var global_position := Vector2.ZERO
var grabbable := true
var accepted_kinds: Array = []
var used: Array = []
var grab_calls := 0
var release_calls := 0


static func item(item_kind: String, pos: Vector2) -> RefCounted:
	var thing: RefCounted = (load("res://tests/support/stub_thing.gd") as GDScript).new()
	thing.kind = item_kind
	thing.global_position = pos
	return thing


static func target(kind_name: String, pos: Vector2, accepts_kinds: Array) -> RefCounted:
	var thing: RefCounted = (load("res://tests/support/stub_thing.gd") as GDScript).new()
	thing.target_kind = kind_name
	thing.global_position = pos
	thing.grabbable = false
	thing.accepted_kinds = accepts_kinds
	return thing


func can_grab() -> bool:
	return grabbable and kind != ""


func on_grabbed(_carrier: Variant) -> void:
	grab_calls += 1


func on_released() -> void:
	release_calls += 1


func accepts(obj: Variant) -> bool:
	return obj != null and accepted_kinds.has(obj.get("kind"))


func use(obj: Variant) -> void:
	used.append(obj)
