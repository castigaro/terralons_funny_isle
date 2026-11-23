extends TestCase
## SwayProp.decorative (BI-18): a level palm joins the prop group and has a solid trunk; a decorative palm (menu
## backdrop) joins no group and has no body, although palm.tscn declares the group statically.

const PALM := "res://scenes/levels/props/palm.tscn"


func _palm(decorative: bool) -> PalmProp:
	var palm := (load(PALM) as PackedScene).instantiate() as PalmProp
	palm.decorative = decorative
	add_node(palm)
	return palm


func test_level_palm_is_a_solid_prop() -> void:
	var palm := _palm(false)
	check_true(palm.is_in_group(SwayProp.GROUP), "in the prop group")
	check(palm.get_node_or_null("Footprint") is StaticBody2D, "solid footprint")


func test_decorative_palm_has_no_group_and_no_body() -> void:
	var palm := _palm(true)
	check_false(palm.is_in_group(SwayProp.GROUP), "not in the prop group")
	check_eq(palm.find_children("*", "StaticBody2D", true, false).size(), 0, "no body")
	check(palm.sprite.texture != null, "crown still drawn")
