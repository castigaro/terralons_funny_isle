extends TestCase
## BI-18 menu island scene: layer and scale from Balance, painted tile layers with textured grass and shore edges,
## the water shader covering the whole screen, decorative palms, at least three different land critters, the
## centred menu band kept free of grass, palms and critters, and no flat placeholder node.

const SCENE := "res://scenes/ui/backdrop/menu_island.tscn"
const WATER_SHADER := "res://scenes/levels/art/water.gdshader"
const TILESET := "res://scenes/levels/island_tileset.tres"
const VIEW := Vector2(1920, 1080)
## Screen band of the menu panels (widest panel: the level select tiles); nothing but water and sand below it.
const BAND_FROM := 420.0
const BAND_TO := 1500.0
const SOURCE := 0
const DERIVED := 1


func _island() -> MenuIsland:
	var island := (load(SCENE) as PackedScene).instantiate() as MenuIsland
	add_node(island)
	return island


func _outside_band(screen_rect: Rect2) -> bool:
	return screen_rect.end.x <= BAND_FROM or screen_rect.position.x >= BAND_TO


func test_layer_scale_and_water() -> void:
	var island := _island()
	check_eq(island.layer, Balance.get_int("flow", "backdrop_layer"), "layer from Balance")
	var s := Balance.get_float("flow", "backdrop_scale")
	check_eq(island.scale, Vector2(s, s), "scale from Balance")
	var water := island.water()
	var mat := water.material as ShaderMaterial
	check(mat != null and mat.shader != null and mat.shader.resource_path == WATER_SHADER, "water shader")
	check_eq(water.texture_repeat, CanvasItem.TEXTURE_REPEAT_ENABLED, "water repeats")
	var covered := island.screen_rect_of(Rect2(water.position, water.region_rect.size))
	check(covered.encloses(Rect2(Vector2.ZERO, VIEW)), "water covers 1920x1080 (got %s)" % covered)


func test_tile_layers_are_painted() -> void:
	var island := _island()
	var layers := island.tile_layers()
	check_eq(layers.size(), 4, "four tile layers")
	for layer: TileMapLayer in layers:
		check_eq(layer.tile_set.resource_path, TILESET, "%s uses the island tileset" % layer.name)
	var sand := layers[0] as TileMapLayer
	var grass := layers[1] as TileMapLayer
	var shore := layers[2] as TileMapLayer
	check(sand.get_used_cells().size() > 100, "sand painted")
	check(grass.get_used_cells().size() >= 9, "grass painted")
	var grass_sources := grass.get_used_cells().map(func(c: Vector2i) -> int: return grass.get_cell_source_id(c))
	check_true(grass_sources.has(DERIVED), "textured grass fill and edge tiles (source 1)")
	var shore_sources := shore.get_used_cells().map(func(c: Vector2i) -> int: return shore.get_cell_source_id(c))
	check_true(shore_sources.has(SOURCE), "shore edge tiles (source 0)")
	var cell_px := float(sand.tile_set.tile_size.x)
	for cell in grass.get_used_cells():
		var r := island.screen_rect_of(Rect2(Vector2(cell) * cell_px, Vector2.ONE * cell_px))
		check(_outside_band(r), "grass cell %s outside the menu band (screen %s)" % [cell, r])


func test_palms_are_decorative() -> void:
	var island := _island()
	var palms := island.palms()
	check(palms.size() >= 3, "at least three palms")
	for palm: PalmProp in palms:
		check_true(palm.decorative, "%s decorative" % palm.name)
		check_false(palm.is_in_group(SwayProp.GROUP), "%s not in the prop group" % palm.name)
		check_eq(palm.find_children("*", "StaticBody2D", true, false).size(), 0, "%s has no body" % palm.name)
		var half := palm.crown_width() / 2.0
		var r := island.screen_rect_of(Rect2(palm.position - Vector2(half, 0.0), Vector2(half * 2.0, 1.0)))
		check(_outside_band(r), "%s crown outside the menu band (screen %s)" % [palm.name, r])


func test_critters_are_different_land_animals() -> void:
	var island := _island()
	var critters := island.critters()
	check(critters.size() >= 3, "at least three critters")
	var kinds := {}
	for c: BackdropCritter in critters:
		kinds[c.kind] = true
		var def := EntityDefs.get_animal(c.kind)
		check_false(def.is_empty(), "%s is an existing kind" % c.kind)
		check_false(bool(def.get("swims", true)), "%s does not swim" % c.kind)
		check_eq(c.error, "", "%s has no error" % c.name)
		check(c.sprite != null and c.sprite.texture != null, "%s texture loaded" % c.name)
		check(c.land.has_area(), "%s has a land rect" % c.name)
		var r := island.screen_rect_of(c.land)
		check(_outside_band(r), "%s land outside the menu band (screen %s)" % [c.name, r])
		check(c.land.has_point(c.position), "%s starts on its land" % c.name)
	check(kinds.size() >= 3, "at least three different kinds")


func test_no_flat_placeholder_nodes() -> void:
	var island := _island()
	for type in ["ColorRect", "Polygon2D", "Line2D", "Control"]:
		check_eq(island.find_children("*", type, true, false).size(), 0, "no %s in the backdrop" % type)
