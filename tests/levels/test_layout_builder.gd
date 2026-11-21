extends TestCase
## tools/build_level_layout.gd: grass edge, corner and inner-corner tiles, shore inner corners and layout errors.

const Builder := preload("res://tools/build_level_layout.gd")
const DERIVED := 1


func _grass(result: Dictionary, cell: Vector2i) -> Array:
	return result["cells"]["Grass"].get(cell, [])


func test_3x3_grass_patch_gets_edges_and_corners() -> void:
	var text := "~~~~~~~~~\n~.......~\n~.......~\n~..,,,..~\n~..,,,..~\n~..,,,..~\n~.......~\n~.......~\n~~~~~~~~~\n"
	var res := Builder.build(text)
	check_eq(res["errors"], [], "no errors")
	var expected := {
		Vector2i(3, 3): Builder.GRASS_EDGE["NW"], Vector2i(4, 3): Builder.GRASS_EDGE["N"],
		Vector2i(5, 3): Builder.GRASS_EDGE["NE"], Vector2i(3, 4): Builder.GRASS_EDGE["W"],
		Vector2i(5, 4): Builder.GRASS_EDGE["E"], Vector2i(3, 5): Builder.GRASS_EDGE["SW"],
		Vector2i(4, 5): Builder.GRASS_EDGE["S"], Vector2i(5, 5): Builder.GRASS_EDGE["SE"],
	}
	for cell in expected:
		check_eq(_grass(res, cell), [DERIVED, expected[cell]], "grass tile at %s" % cell)
	var centre := _grass(res, Vector2i(4, 4))
	check(centre.size() == 2 and centre[0] == 0 and Builder.GRASS_TILES.has(centre[1]), "full grass in the middle")
	for cell in expected.keys() + [Vector2i(4, 4)]:
		check(res["cells"]["Sand"].has(cell), "sand below grass at %s" % cell)


func test_l_shaped_grass_gets_an_inner_corner() -> void:
	var text := "~~~~~~~~~~\n~........~\n~........~\n~..,,....~\n~..,,....~\n~..,,,,..~\n~..,,,,..~\n~........~\n~........~\n~~~~~~~~~~\n"
	var res := Builder.build(text)
	check_eq(res["errors"], [], "no errors")
	check_eq(_grass(res, Vector2i(4, 5)), [DERIVED, Builder.GRASS_INNER["NE"]], "inner corner with sand to the north-east")
	check_eq(_grass(res, Vector2i(4, 4)), [DERIVED, Builder.GRASS_EDGE["E"]], "east edge above the corner")
	check_eq(_grass(res, Vector2i(5, 5)), [DERIVED, Builder.GRASS_EDGE["N"]], "north edge right of the corner")


func test_thin_grass_and_grass_at_the_shore_are_errors() -> void:
	var thin := Builder.build("~~~~~~~~\n~......~\n~......~\n~.,,,,.~\n~......~\n~......~\n~~~~~~~~\n")
	check(str(thin["errors"]).contains("thinner than 2 cells"), "one-cell strip: %s" % str(thin["errors"]))
	var shore := Builder.build("~~~~~~~\n~.,,..~\n~.,,..~\n~.....~\n~.....~\n~~~~~~~\n")
	check(str(shore["errors"]).contains("touches the shore"), "grass at the shore: %s" % str(shore["errors"]))


func test_water_notch_gets_the_shore_inner_corner_with_collision() -> void:
	var text := "~~~~~~~~\n~....~~~\n~....~~~\n~......~\n~......~\n~~~~~~~~\n"
	var res := Builder.build(text)
	check_eq(res["errors"], [], "no errors")
	var cell := Vector2i(4, 3)
	check_eq(res["cells"]["Shore"].get(cell, []), [DERIVED, Builder.SHORE_INNER["NE"]], "shore inner corner NE")
	var tileset: TileSet = load(Builder.TILESET)
	var source := tileset.get_source(DERIVED) as TileSetAtlasSource
	var data := source.get_tile_data(Builder.SHORE_INNER["NE"], 0)
	check_eq(data.get_collision_polygons_count(1), 1, "water collision polygon")
	var points := data.get_collision_polygon_points(1, 0)
	var centre := Vector2.ZERO
	for p in points:
		centre += p / float(points.size())
	check(centre.x > 32.0 and centre.y < -32.0, "polygon in the north-east corner: %s" % centre)
	check_eq(String(data.get_custom_data("surface")), "sand", "sand surface")
