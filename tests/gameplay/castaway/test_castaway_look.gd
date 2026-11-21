extends TestCase
## Castaway look: stand/hold textures, size at 1080 and 720, radial unrotated drop shadow, additive stars and dust,
## no placeholder shapes and no health-like state.

const CASTAWAY_SCENE := preload("res://scenes/castaway/castaway.tscn")
const StubGrabbable := preload("res://tests/support/stub_grabbable.gd")
const BASE_HEIGHT := 1080.0
const SMALL_HEIGHT := 720.0

var castaway: Castaway


func before_each() -> void:
	castaway = add_node(CASTAWAY_SCENE.instantiate())
	castaway.position = Vector2(500, 500)
	castaway.set_input_source(func() -> CastawayInput: return CastawayInput.make())
	await physics_frames(1)


func test_pose_textures() -> void:
	var body: Sprite2D = castaway.visual.body
	check_eq(body.texture, CastawayVisual.TEX_STAND, "stand with empty hands")
	var thing: Node2D = add_node(StubGrabbable.new())
	castaway.get_logic().carried = thing
	await physics_frames(1)
	check_eq(body.texture, CastawayVisual.TEX_HOLD, "hold while carrying")
	check_eq(castaway.get_pose(), CastawayLogic.POSE_CARRY, "carry pose")


func test_size_at_1080_and_720() -> void:
	var body: Sprite2D = castaway.visual.body
	var height := body.texture.get_height() * absf(body.scale.y)
	check(int(ProjectSettings.get_setting("display/window/size/viewport_height")) == int(BASE_HEIGHT), "base height")
	check(height >= 96.0, "height %f at 1080" % height)
	check(height * SMALL_HEIGHT / BASE_HEIGHT >= 64.0, "height %f at 720" % (height * SMALL_HEIGHT / BASE_HEIGHT))
	check(is_equal_approx(body.scale.x, castaway.cfg.sprite_scale), "sprite scale from balance")


func test_shadow_is_radial_and_never_rotates() -> void:
	var shadow: Sprite2D = castaway.shadow
	check(shadow.texture is GradientTexture2D, "gradient texture")
	if shadow.texture is GradientTexture2D:
		check_eq((shadow.texture as GradientTexture2D).fill, GradientTexture2D.FILL_RADIAL, "radial")
	check(shadow.get_parent() == castaway, "shadow outside the rotating visual")
	castaway.get_logic().facing_angle = 1.3
	await physics_frames(1)
	check(is_equal_approx(castaway.visual.rotation, 1.3), "visual faces")
	check_eq(shadow.global_rotation, 0.0, "shadow unrotated")


func test_stars_and_dust_are_additive() -> void:
	var stars: Node2D = castaway.stars
	check_eq(stars.get_child_count(), int(castaway.cfg.star_count), "star count")
	for star in stars.get_children():
		var mat := (star as CanvasItem).material as CanvasItemMaterial
		check(mat != null and mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "star additive")
		check(is_equal_approx((star as Node2D).scale.x, castaway.cfg.star_scale), "star scale")
	var dust_mat := castaway.dust.material as CanvasItemMaterial
	check(dust_mat != null and dust_mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "dust additive")
	check(castaway.dust.texture != null, "dust texture")
	check_eq(castaway.dust.amount, int(castaway.cfg.dust_amount), "dust amount capped by balance")


func test_dizzy_shows_orbiting_stars() -> void:
	castaway.bonk("coconut", Vector2.LEFT)
	await physics_frames(1)
	var first := (castaway.stars.get_child(0) as Node2D).position
	await physics_frames(3)
	check(castaway.stars.visible, "stars visible")
	check((castaway.stars.get_child(0) as Node2D).position != first, "stars orbit")


func test_no_placeholder_shapes_or_harm_state() -> void:
	var stack: Array = [castaway]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		check_false(node is ColorRect or node is Polygon2D, "placeholder node %s" % node.name)
		stack.append_array(node.get_children())
	var forbidden := ["health", "lives", "damage"]
	var names := []
	for prop in castaway.get_property_list():
		names.append(String(prop["name"]))
	for prop in castaway.get_logic().get_property_list():
		names.append(String(prop["name"]))
	for method in castaway.get_script().get_script_method_list():
		names.append(String(method["name"]))
	for pname in names:
		for word in forbidden:
			check_false(word in pname.to_lower().split("_"), "health-like member %s" % pname)
