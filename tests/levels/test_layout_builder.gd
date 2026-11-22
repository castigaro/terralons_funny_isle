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
	check_eq(centre, [DERIVED, Builder.fill_variant(Vector2i(4, 4))], "full grass in the middle")
	check(Builder.GRASS_FILL.has(centre[1]), "middle uses a fill variant")
	for cell in expected.keys() + [Vector2i(4, 4)]:
		check(res["cells"]["Sand"].has(cell), "sand below grass at %s" % cell)


func test_full_grass_uses_fill_variants() -> void:
	var text := "~~~~~~~~~~\n~........~\n~........~\n~..,,,,..~\n~..,,,,..~\n~..,,,,..~\n~..,,,,..~\n~........~\n~........~\n~~~~~~~~~~\n"
	var res := Builder.build(text)
	check_eq(res["errors"], [], "no errors")
	for cell in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)]:
		var tile := _grass(res, cell)
		check(tile.size() == 2 and tile[0] == DERIVED and tile[1].y == 4, "inner cell %s uses fill row 4: %s" % [cell, tile])
		check_eq(tile[1], Builder.fill_variant(cell), "inner cell %s variant" % cell)
	check_ne(_grass(res, Vector2i(4, 4)), _grass(res, Vector2i(5, 4)), "neighbours differ")
	check_eq(_grass(res, Vector2i(3, 3)), [DERIVED, Builder.GRASS_EDGE["NW"]], "corner unchanged")
	check_eq(_grass(res, Vector2i(4, 3)), [DERIVED, Builder.GRASS_EDGE["N"]], "edge unchanged")
	check_eq(_grass(res, Vector2i(6, 5)), [DERIVED, Builder.GRASS_EDGE["E"]], "east edge unchanged")


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


## A scratch copy below the redirected test data folder (TFI_DATA_DIR, set by run_tests.py).
func _scratch(name: String, text: String) -> String:
	var base := OS.get_environment("TFI_DATA_DIR")
	check_ne(base, "", "run_tests sets TFI_DATA_DIR")
	var dir := base.path_join("layout_builder")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	return path


func test_write_scene_handles_typed_layer_nodes() -> void:
	var text := "[gd_scene format=3]\n\n[node name=\"Root\" type=\"CanvasLayer\"]\n\n"
	for layer_name in Builder.LAYERS:
		text += "[node name=\"%s\" type=\"TileMapLayer\" parent=\".\"]\ntile_map_data = PackedByteArray()\n\n" \
				% layer_name
	var path := _scratch("typed_layers.tscn", text)
	var res := Builder.build("~~~~~~~\n" + "~.....~\n".repeat(5) + "~~~~~~~\n")
	check_eq(Builder.write_scene(path, res["data"]), "", "typed TileMapLayer sections found")
	var written := FileAccess.get_file_as_string(path)
	check_eq(written.count("tile_map_data = "), Builder.LAYERS.size(), "one tile_map_data per layer")
	check_eq(written.count("tile_map_data = PackedByteArray()\n"), 2, "Grass and Details empty, Sand and Shore painted")


func test_menu_island_matches_its_layout() -> void:
	var scene := "res://scenes/ui/backdrop/menu_island.tscn"
	var res := Builder.build(FileAccess.get_file_as_string("res://scenes/ui/backdrop/menu_island.layout.txt"))
	check_eq(res["errors"], [], "menu island layout valid")
	var path := _scratch("menu_island.tscn", FileAccess.get_file_as_string(scene))
	check_eq(Builder.write_scene(path, res["data"]), "", "rebuild")
	check_eq(FileAccess.get_file_as_string(path), FileAccess.get_file_as_string(scene),
			"committed menu_island.tscn equals a rebuild from its layout")
