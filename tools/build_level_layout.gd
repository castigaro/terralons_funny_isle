extends SceneTree
## Offline layout builder: paints the Sand, Grass, Shore and Details TileMapLayers of a level scene from an ASCII
## layout and writes their tile_map_data into the .tscn (the committed scene is the result; nothing is generated
## at runtime).
## Usage: godot --headless --path . --script res://tools/build_level_layout.gd -- --layout=<txt> --scene=<tscn>
## Legend: "~" water, "." sand, "," grass on sand, "#" rock on sand (solid). Cells outside the text are water.
## Land cells next to water (4-neighbours) become shore edge or outer corner tiles and must be "."; a land cell
## with water only on a diagonal becomes a shore inner corner (derived tile with a water collision square). A land
## cell with water on two opposite sides is not supported (no one-tile strips).
## Grass cells next to sand or rock get a soft grass-to-sand edge, outer corner or inner corner tile from the
## derived atlas (source 1, tools/derive_grass_edges.gd) on the Grass layer, with plain sand below; full grass cells
## get one of the four textured fill variants (atlas row 4) so that no two 4-neighbours and no 2x2 block repeat the
## same tile. Grass patches must be at least 2 cells wide in both directions and must not touch the shore or water
## (8-neighbours).

const TILESET := "res://scenes/levels/island_tileset.tres"
const LAYERS := ["Sand", "Grass", "Shore", "Details"]
const SOURCE := 0
const DERIVED := 1
const SAND_TILES := [Vector2i(3, 4), Vector2i(4, 4)]
## Textured grass fill variants (source 1, row 4); even cells (x + y) use the first two, odd cells the last two.
const GRASS_FILL := [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]
const ROCK_TILES := [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4)]
const DIAGONALS := {"NW": Vector2i(-1, -1), "NE": Vector2i(1, -1), "SW": Vector2i(-1, 1), "SE": Vector2i(1, 1)}
const SIDES := {"N": Vector2i.UP, "S": Vector2i.DOWN, "W": Vector2i.LEFT, "E": Vector2i.RIGHT}
## Shore tile (source 0) by water sides.
const SHORE := {"N": Vector2i(1, 0), "S": Vector2i(1, 2), "W": Vector2i(0, 1), "E": Vector2i(2, 1),
		"NW": Vector2i(0, 0), "NE": Vector2i(2, 0), "SW": Vector2i(0, 2), "SE": Vector2i(2, 2)}
## Shore inner corner tile (source 1) by water diagonal.
const SHORE_INNER := {"NW": Vector2i(0, 3), "NE": Vector2i(1, 3), "SW": Vector2i(2, 3), "SE": Vector2i(3, 3)}
## Grass edge and outer corner tile (source 1) by sand sides.
const GRASS_EDGE := {"N": Vector2i(0, 0), "S": Vector2i(1, 0), "W": Vector2i(2, 0), "E": Vector2i(3, 0),
		"NW": Vector2i(0, 1), "NE": Vector2i(1, 1), "SW": Vector2i(2, 1), "SE": Vector2i(3, 1)}
## Grass inner corner tile (source 1) by sand diagonal.
const GRASS_INNER := {"NW": Vector2i(0, 2), "NE": Vector2i(1, 2), "SW": Vector2i(2, 2), "SE": Vector2i(3, 2)}


func _initialize() -> void:
	var layout_path := ""
	var scene_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--layout="):
			layout_path = arg.get_slice("=", 1)
		elif arg.begins_with("--scene="):
			scene_path = arg.get_slice("=", 1)
	if layout_path == "" or scene_path == "":
		printerr("usage: --layout=<txt> --scene=<tscn>")
		quit(2)
		return
	var result := build(FileAccess.get_file_as_string(layout_path))
	if not result["errors"].is_empty():
		for err in result["errors"]:
			printerr("layout: %s" % err)
		quit(1)
		return
	var err_text := write_scene(scene_path, result["data"])
	if err_text != "":
		printerr(err_text)
		quit(1)
		return
	print("LAYOUT OK %s cells=%d" % [scene_path, result["land"]])
	quit(0)


## Paints the layers from the layout text: returns {data: {layer: PackedByteArray}, land: int, errors: Array,
## cells: {layer: {cell: [source, atlas coords]}}}.
static func build(text: String) -> Dictionary:
	var rows := text.replace("\r", "").split("\n")
	while rows.size() > 0 and rows[rows.size() - 1].strip_edges() == "":
		rows.remove_at(rows.size() - 1)
	var grid := {}
	for y in rows.size():
		for x in rows[y].length():
			var ch := rows[y][x]
			if ch in [".", ",", "#"]:
				grid[Vector2i(x, y)] = ch
			elif ch != "~" and ch != " ":
				return {"data": {}, "land": 0, "cells": {},
						"errors": ["unknown character '%s' at %d,%d" % [ch, x, y]]}
	var tileset: TileSet = load(TILESET)
	var layers := {}
	var cells := {}
	for layer_name in LAYERS:
		var layer := TileMapLayer.new()
		layer.tile_set = tileset
		layers[layer_name] = layer
		cells[layer_name] = {}
	var paint := func(layer_name: String, cell: Vector2i, source: int, coords: Vector2i) -> void:
		layers[layer_name].set_cell(cell, source, coords)
		cells[layer_name][cell] = [source, coords]
	var errors: Array = []
	var coast := {}
	for cell: Vector2i in grid:
		if _open_sides(cell, func(c: Vector2i) -> bool: return grid.has(c)) != "" \
				or not _open_diagonals(cell, func(c: Vector2i) -> bool: return grid.has(c)).is_empty():
			coast[cell] = true
	var keys := grid.keys()
	keys.sort()
	for cell: Vector2i in keys:
		var ch: String = grid[cell]
		var pick := absi(cell.x * 7 + cell.y * 13)
		var is_land := func(c: Vector2i) -> bool: return grid.has(c)
		var sides := _open_sides(cell, is_land)
		if sides != "":
			if not SHORE.has(sides):
				errors.append("cell %d,%d: water on sides %s is not supported" % [cell.x, cell.y, sides])
				continue
			if ch != ".":
				errors.append("cell %d,%d: shore cells must be sand '.'" % [cell.x, cell.y])
				continue
			paint.call("Shore", cell, SOURCE, SHORE[sides])
			continue
		var diagonals := _open_diagonals(cell, is_land)
		if diagonals.size() > 1:
			errors.append("cell %d,%d: water on more than one diagonal is not supported" % [cell.x, cell.y])
			continue
		if diagonals.size() == 1:
			if ch != ".":
				errors.append("cell %d,%d: inner corner cells must be sand '.'" % [cell.x, cell.y])
				continue
			paint.call("Shore", cell, DERIVED, SHORE_INNER[diagonals[0]])
			continue
		paint.call("Sand", cell, SOURCE, SAND_TILES[pick % SAND_TILES.size()])
		if ch == ",":
			var tile := _grass_tile(cell, grid, coast, errors)
			if tile.size() == 2:
				paint.call("Grass", cell, tile[0], tile[1])
		elif ch == "#":
			paint.call("Details", cell, SOURCE, ROCK_TILES[pick % ROCK_TILES.size()])
	var data := {}
	for layer_name in LAYERS:
		data[layer_name] = layers[layer_name].tile_map_data
		layers[layer_name].free()
	return {"data": data, "land": grid.size(), "errors": errors, "cells": cells}


## Water sides ("N", "S", "W", "E" in that order) of a cell; is_inside(c) tells whether a neighbour is inside.
static func _open_sides(cell: Vector2i, is_inside: Callable) -> String:
	var out := ""
	for side in SIDES:
		if not is_inside.call(cell + SIDES[side]):
			out += side
	return out


static func _open_diagonals(cell: Vector2i, is_inside: Callable) -> Array:
	var out: Array = []
	for d in DIAGONALS:
		if not is_inside.call(cell + DIAGONALS[d]):
			out.append(d)
	return out


## [source, coords] of the grass tile of a grass cell ([] after an error); full grass returns a fill variant.
static func _grass_tile(cell: Vector2i, grid: Dictionary, coast: Dictionary, errors: Array) -> Array:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var n: Vector2i = cell + Vector2i(dx, dy)
			if n != cell and (not grid.has(n) or coast.has(n)):
				errors.append("cell %d,%d: grass touches the shore or water" % [cell.x, cell.y])
				return []
	var is_grass := func(c: Vector2i) -> bool: return grid.get(c, "") == ","
	if (not is_grass.call(cell + Vector2i.LEFT) and not is_grass.call(cell + Vector2i.RIGHT)) \
			or (not is_grass.call(cell + Vector2i.UP) and not is_grass.call(cell + Vector2i.DOWN)):
		errors.append("cell %d,%d: grass patch thinner than 2 cells" % [cell.x, cell.y])
		return []
	var sides := _open_sides(cell, is_grass)
	var diagonals := _open_diagonals(cell, is_grass)
	if sides == "":
		if diagonals.is_empty():
			return [DERIVED, fill_variant(cell)]
		if diagonals.size() == 1:
			return [DERIVED, GRASS_INNER[diagonals[0]]]
	elif GRASS_EDGE.has(sides):
		var uncovered := diagonals.filter(func(d: String) -> bool: return not (d[0] in sides or d[1] in sides))
		if uncovered.is_empty():
			return [DERIVED, GRASS_EDGE[sides]]
	errors.append("cell %d,%d: grass shape with sand on %s and diagonals %s is not supported"
			% [cell.x, cell.y, sides, ",".join(diagonals)])
	return []


## Fill variant of a full grass cell: the cell parity picks the pair, a deterministic cell hash the tile in it.
static func fill_variant(cell: Vector2i) -> Vector2i:
	var pair := 2 * posmod(cell.x + cell.y, 2)
	var h := (cell.x * 73856093) ^ (cell.y * 19349663)
	return GRASS_FILL[pair + ((absi(h) >> 4) & 1)]


## Replaces the tile_map_data line of the four layer override sections in a level .tscn; returns "" or an error.
static func write_scene(scene_path: String, data: Dictionary) -> String:
	var text := FileAccess.get_file_as_string(scene_path)
	if text == "":
		return "cannot read %s" % scene_path
	var lines := text.split("\n")
	for layer_name in LAYERS:
		var header := '[node name="%s" parent="."' % layer_name
		var start := -1
		for i in lines.size():
			if lines[i].begins_with(header):
				start = i
				break
		if start < 0:
			return "%s: missing section %s]" % [scene_path, header]
		var end := start + 1
		while end < lines.size() and not lines[end].begins_with("["):
			end += 1
		for i in range(end - 1, start, -1):
			if lines[i].begins_with("tile_map_data = "):
				lines.remove_at(i)
		lines.insert(start + 1, "tile_map_data = " + var_to_str(data[layer_name]))
	var out := FileAccess.open(scene_path, FileAccess.WRITE)
	if out == null:
		return "cannot write %s" % scene_path
	out.store_string("\n".join(lines))
	out.close()
	return ""
