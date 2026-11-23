class_name MenuIsland
extends CanvasLayer
## Live island behind the menus: animated water, a sand beach with grass patches, decorative palms and a few
## wandering critters. Layer and scale come from Balance flow (backdrop_layer, backdrop_scale); the GameFlow root
## (scripts/main.gd) owns it, hides it while a level exists and never frees it. See docs/flow.md "Menu backdrop".

const LAYERS := ["Sand", "Grass", "Shore", "Details"]

@onready var _water: Sprite2D = $WaterBackdrop


func _ready() -> void:
	layer = Balance.get_int("flow", "backdrop_layer")
	var s := Balance.get_float("flow", "backdrop_scale")
	scale = Vector2(s, s)
	_size_water()


## Covers the whole viewport with the water region (local units, rounded up to whole water tiles).
func _size_water() -> void:
	var view := Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width")),
			float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	var local := view / scale
	var tile := _water.texture.get_size() if _water.texture != null else Vector2.ONE
	var size := Vector2(ceilf(local.x / tile.x) * tile.x, ceilf(local.y / tile.y) * tile.y)
	_water.centered = false
	_water.position = Vector2.ZERO
	_water.region_enabled = true
	_water.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_water.region_rect = Rect2(Vector2.ZERO, size)
	ArtPalette.apply_to(_water.material)


# --- Queries (also used by tests) ------------------------------------------------------------------------

func water() -> Sprite2D:
	return _water


func critters() -> Array:
	return $Critters.get_children().filter(func(n: Node) -> bool: return n is BackdropCritter)


func palms() -> Array:
	return $Props.get_children().filter(func(n: Node) -> bool: return n is PalmProp)


func tile_layers() -> Array:
	var out: Array = []
	for layer_name in LAYERS:
		out.append(get_node(layer_name))
	return out


## A rectangle in local scene units as screen pixels (1920x1080 reference).
func screen_rect_of(local_rect: Rect2) -> Rect2:
	return Rect2(local_rect.position * scale, local_rect.size * scale)
