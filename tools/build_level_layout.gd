extends SceneTree
## Offline layout builder: paints the Sand, Grass, Shore and Details TileMapLayers of a level scene from an ASCII
## layout and writes their tile_map_data into the .tscn (the committed scene is the result; nothing is generated
## at runtime).
## Usage: godot --headless --path . --script res://tools/build_level_layout.gd -- --layout=<txt> --scene=<tscn>
## Legend: "~" water, "." sand, "," grass on sand, "#" rock on sand (solid). Cells outside the text are water.
## Land cells next to water (4-neighbours) become shore edge or outer corner tiles and must be "."; a land cell
## with water only on a diagonal becomes an inner corner (sand with a small water collision square). A land cell
## with water on two opposite sides is not supported (no one-tile strips).

const TILESET := "res://scenes/levels/island_tileset.tres"
const LAYERS := ["Sand", "Grass", "Shore", "Details"]
const SOURCE := 0
const SAND_TILES := [Vector2i(3, 4), Vector2i(4, 4)]
const GRASS_TILES := [Vector2i(6, 1), Vector2i(7, 1), Vector2i(6, 2), Vector2i(7, 2)]
const ROCK_TILES := [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4)]
const INNER_CORNER_TILE := Vector2i(3, 4)
## Alternative ids of INNER_CORNER_TILE by water diagonal.
const INNER_ALT := {Vector2i(-1, -1): 1, Vector2i(1, -1): 2, Vector2i(-1, 1): 3, Vector2i(1, 1): 4}
## Shore tile by water sides "N", "S", "W", "E".
const SHORE := {"N": Vector2i(1, 0), "S": Vector2i(1, 2), "W": Vector2i(0, 1), "E": Vector2i(2, 1),
		"NW": Vector2i(0, 0), "NE": Vector2i(2, 0), "SW": Vector2i(0, 2), "SE": Vector2i(2, 2)}


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


## Paints the layers from the layout text: returns {data: {layer: PackedByteArray}, land: int, errors: Array}.
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
				return {"data": {}, "land": 0, "errors": ["unknown character '%s' at %d,%d" % [ch, x, y]]}
	var tileset: TileSet = load(TILESET)
	var layers := {}
	for layer_name in LAYERS:
		var layer := TileMapLayer.new()
		layer.tile_set = tileset
		layers[layer_name] = layer
	var errors: Array = []
	for cell: Vector2i in grid:
		var ch: String = grid[cell]
		var sides := ""
		for pair in [["N", Vector2i.UP], ["S", Vector2i.DOWN], ["W", Vector2i.LEFT], ["E", Vector2i.RIGHT]]:
			if not grid.has(cell + pair[1]):
				sides += pair[0]
		var pick := absi(cell.x * 7 + cell.y * 13)
		if sides != "":
			if not SHORE.has(sides):
				errors.append("cell %d,%d: water on sides %s is not supported" % [cell.x, cell.y, sides])
				continue
			if ch != ".":
				errors.append("cell %d,%d: shore cells must be sand '.'" % [cell.x, cell.y])
				continue
			layers["Shore"].set_cell(cell, SOURCE, SHORE[sides])
			continue
		var diagonals: Array = []
		for d in INNER_ALT:
			if not grid.has(cell + d):
				diagonals.append(d)
		if diagonals.size() > 1:
			errors.append("cell %d,%d: water on more than one diagonal is not supported" % [cell.x, cell.y])
			continue
		if diagonals.size() == 1:
			if ch != ".":
				errors.append("cell %d,%d: inner corner cells must be sand '.'" % [cell.x, cell.y])
				continue
			layers["Shore"].set_cell(cell, SOURCE, INNER_CORNER_TILE, INNER_ALT[diagonals[0]])
			continue
		layers["Sand"].set_cell(cell, SOURCE, SAND_TILES[pick % SAND_TILES.size()])
		if ch == ",":
			layers["Grass"].set_cell(cell, SOURCE, GRASS_TILES[pick % GRASS_TILES.size()])
		elif ch == "#":
			layers["Details"].set_cell(cell, SOURCE, ROCK_TILES[pick % ROCK_TILES.size()])
	var data := {}
	for layer_name in LAYERS:
		data[layer_name] = layers[layer_name].tile_map_data
		layers[layer_name].free()
	return {"data": data, "land": grid.size(), "errors": errors}


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
