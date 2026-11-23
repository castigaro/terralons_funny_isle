extends "res://tests/support/level_case.gd"
## Volcano Cliffs set dressing (BI-23): the play fingerprint and the surfaces stay as recorded before the dressing,
## lava decor sits only on solid rock away from zones and points and adds no physics, every coast cell has exactly
## its cliff face piece, which never covers walkable ground and owns the whole water collision strip; no coast cell
## shows the water (ground patches close the pockets of the rounded outer shore corners and look like the ground),
## inner corner lips join the rim of their neighbours, the wrap face fades out and straight pieces join without a
## seam; the L5 foliage tints from the palette, the glow pulses slowly and holds still under "reduce screen shake and
## flashes", the particle budget stays small and the shared ground material copies the palette.

const Fingerprint := preload("res://tests/support/play_fingerprint.gd")
const VolcanoArt := preload("res://tools/derive_volcano_art.gd")
const LEVEL_ID := "l5_volcano_cliffs"
const LEVEL_DIR := "res://scenes/levels/"
const LEVEL := "res://scenes/levels/l5_volcano_cliffs.tscn"
const LAYOUT := "res://scenes/levels/layouts/l5_volcano_cliffs.layout.txt"
const SURFACES := "res://tests/fixtures/levels/l5_surfaces.json"
const DECOR_SCENE := "res://scenes/levels/decor/l5_volcano_decor.tscn"
const SHADER := "res://scenes/levels/art/volcanic_ground.gdshader"
const DETAIL := "res://assets/graphics/volcano-derived/volcanic_detail@2.png"
const MATERIAL := "res://scenes/levels/art/volcanic_ground_material.tres"
## Size of the detail texture, which the material maps 1:1 to world pixels (detail_world_px).
const DETAIL_PX := 256
## Light water colour of the backdrop (tools/flat_area_check.py WATER), the worst case under a transparent pixel.
const WATER := Color(0.6706, 0.8902, 0.9608)
const TILE_LAYERS := ["Sand", "Grass", "Shore", "Details"]
const OTHER_LEVELS := ["l1_beach_camp", "l2_farm_meadow", "l3_jungle", "l4_lagoon"]
const CELL := 128
const MAX_PARTICLES := 64
const MIN_CRACKS := 3
const MIN_VENTS := 2
const SOLID_MASK := PhysicsLayers.WORLD_SOLID | PhysicsLayers.WATER | PhysicsLayers.BOUNDS
const ENV_VAR := "TFI_DATA_DIR"
## Sampling of the cliff face texels (every n-th texel in both directions).
const TEXEL_STEP := 4
const SIDES := [["N", Vector2i(0, -1)], ["S", Vector2i(0, 1)], ["W", Vector2i(-1, 0)], ["E", Vector2i(1, 0)]]
const DIAGONALS := [["NW", Vector2i(-1, -1)], ["NE", Vector2i(1, -1)], ["SW", Vector2i(-1, 1)], ["SE", Vector2i(1, 1)]]
const PALETTE_PARAMS := {"rock_low": "volcano_rock_low", "rock_high": "volcano_rock_high", "ash_tint": "volcano_ash",
		"stone_tint": "volcano_stone"}

var _env_before := ""


func _open() -> LevelBase:
	return await open_level(LEVEL, {"autostart": false})


func _layout() -> PackedStringArray:
	return FileAccess.get_file_as_string(LAYOUT).replace("\r", "").split("\n", false)


func _char(rows: PackedStringArray, cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= rows[cell.y].length():
		return "~"
	return rows[cell.y][cell.x]


func _land(rows: PackedStringArray, cell: Vector2i) -> bool:
	return _char(rows, cell) in [".", ",", "#"]


func _cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))


func _decor(lvl: Node) -> VolcanoDecor:
	return lvl.get_node_or_null("GroundDecor/VolcanoDecor") as VolcanoDecor


func _solid_at(lvl: Node, pos: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = SOLID_MASK
	return not (lvl as Node2D).get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


## Cells (Chebyshev) blocked for lava decor: one cell around every zone rectangle, home point, the spawn and anchors.
func _blocked_cells(lvl: Node) -> Dictionary:
	var out := {}
	var rects := []
	for zone in lvl.get_node("Zones").get_children():
		for shape in zone.get_children():
			if shape is CollisionShape2D and (shape as CollisionShape2D).shape is RectangleShape2D:
				var size: Vector2 = ((shape as CollisionShape2D).shape as RectangleShape2D).size
				rects.append(Rect2((shape as Node2D).global_position - size / 2.0, size))
	var points := [(lvl.get_node("Markers/Spawn") as Node2D).global_position]
	for parent_name in ["HomePoints", "EventAnchors"]:
		for child in lvl.get_node(parent_name).get_children():
			points.append((child as Node2D).global_position)
	for p: Vector2 in points:
		rects.append(Rect2(p, Vector2(0.001, 0.001)))
	for r: Rect2 in rects:
		var a := _cell_of(r.position)
		var b := _cell_of(r.end - Vector2(0.001, 0.001))
		for y in range(a.y - 1, b.y + 2):
			for x in range(a.x - 1, b.x + 2):
				out[Vector2i(x, y)] = true
	return out


func _use_data_dir(sub: String, reduce: bool) -> void:
	_env_before = OS.get_environment(ENV_VAR)
	check_ne(_env_before, "", "run_tests sets TFI_DATA_DIR")
	var dir := _env_before.path_join("bi23").path_join(sub)
	DirAccess.make_dir_recursive_absolute(dir)
	OS.set_environment(ENV_VAR, dir)
	var f := FileAccess.open(dir.path_join(FxSettings.FILE), FileAccess.WRITE)
	f.store_string(JSON.stringify({FxSettings.KEY: reduce}))
	f.close()


func _restore_data_dir() -> void:
	if _env_before != "":
		OS.set_environment(ENV_VAR, _env_before)


# --- (a) play fingerprint -------------------------------------------------------------------------

func test_play_unchanged() -> void:
	var lvl := (load(LEVEL) as PackedScene).instantiate() as LevelBase
	add_node(lvl)
	var json := JSON.new()
	check_eq(json.parse(FileAccess.get_file_as_string(Fingerprint.baseline_path(LEVEL_ID))), OK, "baseline parses")
	var lines := Fingerprint.diff(Fingerprint.fingerprint(lvl), json.data)
	for line in lines:
		fail("%s in scenes/levels/%s.tscn – the volcano dressing must not move or reshape it; restore it" % [line, LEVEL_ID])
	check(lines.is_empty(), "L5 plays as before the volcano dressing")


# --- (b) lava decor placement ----------------------------------------------------------------------

func test_lava_decor_on_solid_rock_away_from_play() -> void:
	var lvl := await _open()
	var decor := _decor(lvl)
	check(decor != null, "VolcanoDecor under GroundDecor")
	if decor == null:
		return
	var rows := _layout()
	var blocked := _blocked_cells(lvl)
	var nodes: Array = decor.cracks() + decor.vents()
	for node: Node2D in nodes:
		var pos := node.global_position
		var cell := _cell_of(pos)
		var where := "%s at cell %s (%s)" % [decor.get_path_to(node), cell, DECOR_SCENE]
		check(_char(rows, cell) in ["#", "~"], "%s stands on '%s' – lava only on rock or water cells" % [where, _char(rows, cell)])
		check(_solid_at(lvl, pos), "%s stands on walkable ground – move it onto a solid rock cell" % where)
		check_false(blocked.has(cell), "%s is within one cell of a zone, home point, spawn or anchor" % where)


func test_decor_adds_no_physics() -> void:
	var lvl := await _open()
	var decor := _decor(lvl)
	for sub in [decor] + decor.find_children("*", "", true, false):
		var bad: bool = sub is CollisionObject2D or sub is CollisionShape2D or sub is CollisionPolygon2D \
				or sub is TileMapLayer
		check_false(bad, "decor %s carries %s – decor must stay walk-through" % [decor.get_path_to(sub), sub.get_class()])
		for group in ["level_entity", "actor", SwayProp.GROUP]:
			check_false(sub.is_in_group(group), "decor %s is in group %s" % [sub.name, group])
	var props := lvl.get_tree().get_nodes_in_group(SwayProp.GROUP).filter(func(n): return lvl.is_ancestor_of(n))
	for prop: Node in props:
		check_false(decor.is_ancestor_of(prop), "decor adds no prop (%s)" % prop.name)


# --- (c) counts and particle budget ----------------------------------------------------------------

func test_counts_and_particle_budget() -> void:
	var lvl := await _open()
	var decor := _decor(lvl)
	check(decor.cracks().size() >= MIN_CRACKS, "lava cracks (%d)" % decor.cracks().size())
	check(decor.vents().size() >= MIN_VENTS, "vents (%d)" % decor.vents().size())
	var total := 0
	for p in decor.find_children("*", "CPUParticles2D", true, false):
		total += (p as CPUParticles2D).amount
	check(total <= MAX_PARTICLES, "particle amounts sum to %d (at most %d)" % [total, MAX_PARTICLES])
	check(LavaVent.live_budget(decor) <= MAX_PARTICLES, "live budget")
	for vent in decor.vents():
		check(vent is LavaVent, "%s is a LavaVent" % vent.name)
		check(vent.get_node("Glow") is LavaGlow, "%s glow pulses" % vent.name)
	var vents := decor.get_node("Vents") as Node2D
	check_false(vents.z_as_relative, "vents use an absolute z")
	check_eq(vents.z_index, 1, "smoke rises above the rocks")


# --- (d) cliff coverage -----------------------------------------------------------------------------

## Required {"x,y,kind": true} from the layout: one piece per coast cell with its shore kind.
func _required_pieces(rows: PackedStringArray) -> Dictionary:
	var out := {}
	for y in rows.size():
		for x in rows[y].length():
			var cell := Vector2i(x, y)
			if not _land(rows, cell):
				continue
			var sides := ""
			for side in SIDES:
				if not _land(rows, cell + side[1]):
					sides += side[0]
			var kind := sides
			if sides == "":
				var diagonals := DIAGONALS.filter(func(d): return not _land(rows, cell + d[1]))
				kind = "I" + diagonals[0][0] if diagonals.size() == 1 else ""
			if kind != "":
				out["%d,%d,%s" % [x, y, kind]] = true
	return out


func test_every_coast_cell_has_its_cliff_piece() -> void:
	var decor := (load(DECOR_SCENE) as PackedScene).instantiate()
	add_node(decor)
	var required := _required_pieces(_layout())
	var found := {}
	for piece in decor.get_node("CliffFace").get_children():
		var parts := String(piece.name).split("_")
		check_eq(parts.size(), 4, "piece name %s is Face_<x>_<y>_<kind>" % piece.name)
		if parts.size() != 4:
			continue
		var key := "%s,%s,%s" % [parts[1], parts[2], parts[3]]
		check_false(found.has(key), "piece %s exists once" % key)
		found[key] = true
		check((piece as Sprite2D).texture is AtlasTexture, "%s uses the cliff atlas" % piece.name)
		if (piece as Sprite2D).texture is AtlasTexture:
			check_eq(Rect2i(((piece as Sprite2D).texture as AtlasTexture).region), VolcanoArt.region(parts[3]),
					"%s shows the %s piece" % [piece.name, parts[3]])
	for key in required:
		check(found.has(key), "coast cell %s has its cliff piece – rerun tools/place_volcano_decor.py" % key)
	for key in found:
		check(required.has(key), "cliff piece %s matches no coast cell" % key)
	check(required.size() >= 50, "coast cells found (%d)" % required.size())


func test_cliff_pieces_cover_no_walkable_ground() -> void:
	var lvl := await _open()
	var rows := _layout()
	var img := Image.load_from_file(ProjectSettings.globalize_path(VolcanoArt.OUT_DIR + "cliff_face@2.png"))
	img.convert(Image.FORMAT_RGBA8)
	var bad := 0
	var samples := 0
	for piece: Sprite2D in _decor(lvl).pieces():
		var region := Rect2i((piece.texture as AtlasTexture).region)
		for y in range(0, region.size.y, TEXEL_STEP):
			for x in range(0, region.size.x, TEXEL_STEP):
				if img.get_pixel(region.position.x + x, region.position.y + y).a <= 0.1:
					continue
				samples += 1
				var world := piece.global_position + Vector2(x + 0.5, y + 0.5)
				if _land(rows, _cell_of(world)) and not _solid_at(lvl, world):
					bad += 1
					if bad <= 5:
						fail("cliff piece %s covers walkable ground at %s" % [piece.name, world])
	check(samples > 1000, "cliff texels sampled (%d)" % samples)
	check_eq(bad, 0, "no cliff texel over walkable ground")


## Cliff atlas image and the decor pieces as {cell: [Sprite2D]} for every cell a piece overlaps.
func _atlas() -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(VolcanoArt.OUT_DIR + "cliff_face@2.png"))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _pieces_by_cell(decor: Node) -> Dictionary:
	var out := {}
	for piece: Sprite2D in decor.get_node("CliffFace").get_children():
		var a := _cell_of(piece.position)
		var b := _cell_of(piece.position + Vector2(VolcanoArt.PIECE - 1, VolcanoArt.PIECE - 1))
		for y in range(a.y, b.y + 1):
			for x in range(a.x, b.x + 1):
				if not out.has(Vector2i(x, y)):
					out[Vector2i(x, y)] = []
				out[Vector2i(x, y)].append(piece)
	return out


## Cliff colour over a world pixel: the overlapping pieces composited in draw order; rgb unpremultiplied, a the
## combined alpha.
func _cliff_color(atlas: Image, by_cell: Dictionary, world: Vector2i) -> Color:
	var acc := Color(0, 0, 0, 0)
	for piece: Sprite2D in by_cell.get(_cell_of(Vector2(world)), []):
		var local := world - Vector2i(piece.position)
		if local.x < 0 or local.y < 0 or local.x >= VolcanoArt.PIECE or local.y >= VolcanoArt.PIECE:
			continue
		var region := Rect2i((piece.texture as AtlasTexture).region)
		var c := atlas.get_pixel(region.position.x + local.x, region.position.y + local.y)
		acc = Color(c.r * c.a + acc.r * (1.0 - c.a), c.g * c.a + acc.g * (1.0 - c.a), c.b * c.a + acc.b * (1.0 - c.a),
				c.a + acc.a * (1.0 - c.a))
	if acc.a <= 0.0:
		return acc
	return Color(acc.r / acc.a, acc.g / acc.a, acc.b / acc.a, acc.a)


## Combined alpha of every cliff piece over a world pixel (alpha compositing of the overlapping pieces).
func _cover(atlas: Image, by_cell: Dictionary, world: Vector2i) -> float:
	return _cliff_color(atlas, by_cell, world).a


func _piece_kinds(decor: Node) -> Dictionary:
	var out := {}
	for piece in decor.get_node("CliffFace").get_children():
		var parts := String(piece.name).split("_")
		out[Vector2i(int(parts[1]), int(parts[2]))] = parts[3]
	return out


## CornerGround sprites by their own cell.
func _grounds_by_cell(decor: Node) -> Dictionary:
	var out := {}
	for sprite: Sprite2D in decor.get_node("CornerGround").get_children():
		out[_cell_of(sprite.position + Vector2(VolcanoArt.MARGIN, VolcanoArt.MARGIN))] = sprite
	return out


## Ground patch texel over a tile pixel of a cell (transparent when the cell has no patch).
func _ground_texel(atlas: Image, grounds: Dictionary, cell: Vector2i, p: Vector2i) -> Color:
	if not grounds.has(cell):
		return Color(0, 0, 0, 0)
	var region := Rect2i(((grounds[cell] as Sprite2D).texture as AtlasTexture).region)
	return atlas.get_pixel(region.position.x + VolcanoArt.MARGIN + p.x, region.position.y + VolcanoArt.MARGIN + p.y)


var _images := {}


## The real Shore tile of a level cell: [image, pixel offset of the tile in it] from the level tileset.
func _shore_tile(lvl: Node, cell: Vector2i) -> Array:
	var layer := lvl.get_node("Shore") as TileMapLayer
	var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
	var path := source.texture.resource_path
	if not _images.has(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		img.convert(Image.FORMAT_RGBA8)
		_images[path] = img
	return [_images[path], source.get_tile_texture_region(layer.get_cell_atlas_coords(cell)).position]


func _detail() -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(DETAIL))
	img.convert(Image.FORMAT_RGBA8)
	return img


static func _over(src: Color, dst: Color) -> Color:
	return Color(src.r * src.a + dst.r * (1.0 - src.a), src.g * src.a + dst.g * (1.0 - src.a),
			src.b * src.a + dst.b * (1.0 - src.a), 1.0)


## Final colour of a coast cell pixel: the shaded shore pixel over the water, the shaded ground patch over it and the
## cliff pieces on top.
func _compose(ctx: Dictionary, cell: Vector2i, p: Vector2i) -> Color:
	var world := cell * CELL + p
	var d: float = (ctx["detail"] as Image).get_pixel(posmod(world.x, DETAIL_PX), posmod(world.y, DETAIL_PX)).r
	var tile: Array = _shore_tile(ctx["level"], cell)
	var shore := (tile[0] as Image).get_pixel(tile[1].x + p.x, tile[1].y + p.y)
	var out := _over(VolcanicGround.apply(shore, d, ctx["params"]), WATER)
	var ground := _ground_texel(ctx["atlas"], ctx["grounds"], cell, p)
	if ground.a > 0.0:
		out = _over(VolcanicGround.apply(ground, d, ctx["params"]), out)
	return _over(_cliff_color(ctx["atlas"], ctx["by_cell"], world), out)


func _context(lvl: Node) -> Dictionary:
	var decor := _decor(lvl)
	return {"level": lvl, "atlas": _atlas(), "by_cell": _pieces_by_cell(decor), "grounds": _grounds_by_cell(decor),
			"kinds": _piece_kinds(decor), "detail": _detail(),
			"params": VolcanicGround.params_from_material((lvl.get_node("Sand") as CanvasItem).material as ShaderMaterial)}


static func _blue(c: Color) -> bool:
	return c.b > c.r + 0.1 and c.b > c.g


func test_coast_cells_show_no_water() -> void:
	var lvl := (load(LEVEL) as PackedScene).instantiate()
	add_node(lvl)
	var ctx := _context(lvl)
	var kinds: Dictionary = ctx["kinds"]
	var open := 0
	var checked := 0
	var per_cell := {}
	for cell: Vector2i in kinds:
		var tile: Array = _shore_tile(lvl, cell)
		var img: Image = tile[0]
		for ty in CELL:
			for tx in CELL:
				if not VolcanoArt.is_water_px(img.get_pixel(tile[1].x + tx, tile[1].y + ty)):
					continue
				checked += 1
				per_cell[cell] = int(per_cell.get(cell, 0)) + 1
				var p := Vector2i(tx, ty)
				var ground := _ground_texel(ctx["atlas"], ctx["grounds"], cell, p).a
				var cliff := _cover(ctx["atlas"], ctx["by_cell"], cell * CELL + p)
				var shut := 1.0 - (1.0 - ground) * (1.0 - cliff)
				if shut < 0.9:
					open += 1
					if open <= 5:
						fail("water shows through the %s coast cell %s at tile pixel %s (ground %.2f, cliff %.2f) – rerun tools/derive_volcano_art.gd and tools/place_volcano_decor.py"
								% [kinds[cell], cell, p, ground, cliff])
	check(checked > 10000, "water pixels of the shore tiles checked (%d)" % checked)
	for cell in [Vector2i(13, 20), Vector2i(19, 20)]:
		check(int(per_cell.get(cell, 0)) >= 250, "inlet corner %s contributes water pixels (%d)" % [cell, per_cell.get(cell, 0)])
	check_eq(open, 0, "no water shows through a shore tile of a coast cell")


func test_south_inlet_corners_closed() -> void:
	var lvl := (load(LEVEL) as PackedScene).instantiate()
	add_node(lvl)
	var ctx := _context(lvl)
	var expected := {Vector2i(13, 20): "SE", Vector2i(19, 20): "SW", Vector2i(13, 19): "ISE", Vector2i(19, 19): "ISW"}
	for cell: Vector2i in expected:
		check_eq((ctx["kinds"] as Dictionary).get(cell, ""), expected[cell], "inlet cell %s is %s" % [cell, expected[cell]])
		var blue := 0
		for ty in CELL:
			for tx in CELL:
				var c := _compose(ctx, cell, Vector2i(tx, ty))
				if _blue(c):
					blue += 1
					if blue <= 3:
						fail("inlet cell %s shows water at tile pixel %s (%s)" % [cell, Vector2i(tx, ty), c])
		check_eq(blue, 0, "inlet cell %s shows no water inside the land cell" % cell)


func test_corner_ground_matches_ground() -> void:
	var lvl := (load(LEVEL) as PackedScene).instantiate()
	add_node(lvl)
	var ctx := _context(lvl)
	var decor := _decor(lvl)
	var rows := _layout()
	var atlas: Image = ctx["atlas"]
	var sand := (lvl.get_node("Sand") as CanvasItem).material
	check(decor.get_child(0).name == "CornerGround", "CornerGround is the first decor child (below the cliff)")
	var grounds: Array = decor.corner_grounds()
	check(grounds.size() >= 4, "corner ground sprites (%d)" % grounds.size())
	# A cell gets a patch exactly when its kind has a non-empty ground region in the atlas.
	var with_patch := {}
	for kind: String in VolcanoArt.GROUND_KINDS:
		var r := VolcanoArt.ground_region(kind)
		with_patch[kind] = not atlas.get_region(r).is_invisible()
	var by_cell: Dictionary = ctx["grounds"]
	for cell: Vector2i in ctx["kinds"]:
		var kind: String = ctx["kinds"][cell]
		check_eq(by_cell.has(cell), bool(with_patch.get(kind, false)), "coast cell %s (%s) has a ground patch exactly when its kind has one" % [cell, kind])
	var rim_lum := VolcanicGround.luma(ArtPalette.color("volcano_rock_high")) + 0.05
	for sprite: Sprite2D in grounds:
		var parts := String(sprite.name).split("_")
		var kind := parts[3]
		var cell := Vector2i(int(parts[1]), int(parts[2]))
		check(sprite.material == sand and sprite.material.resource_path == MATERIAL,
				"%s uses the shared volcanic ground material" % sprite.name)
		check_eq(Rect2i((sprite.texture as AtlasTexture).region), VolcanoArt.ground_region(kind), "%s shows the %s patch" % [sprite.name, kind])
		check_eq(sprite.position, Vector2(cell * CELL) - Vector2(VolcanoArt.MARGIN, VolcanoArt.MARGIN), "%s sits on its cell" % sprite.name)
		var region := Rect2i((sprite.texture as AtlasTexture).region)
		var stray := 0
		for y in VolcanoArt.PIECE:
			for x in VolcanoArt.PIECE:
				if atlas.get_pixel(region.position.x + x, region.position.y + y).a <= 0.1:
					continue
				var p := Vector2i(x - VolcanoArt.MARGIN, y - VolcanoArt.MARGIN)
				if not VolcanoArt.effective_land(kind, p.x, p.y) or not _land(rows, cell):
					stray += 1
		check_eq(stray, 0, "%s paints only walkable ground of its own land cell" % sprite.name)
		var light := 0
		for ty in CELL:
			for tx in CELL:
				var p := Vector2i(tx, ty)
				if not VolcanoArt.effective_land(kind, tx, ty):
					continue
				if _ground_texel(atlas, by_cell, cell, p).a >= 0.9:
					continue
				var c := _compose(ctx, cell, p)
				if VolcanicGround.luma(c) > rim_lum or _blue(c):
					light += 1
					if light <= 3:
						fail("%s leaves a light shore rim at tile pixel %s (%s)" % [sprite.name, p, c])
		check_eq(light, 0, "%s leaves no light shore rim on walkable ground" % sprite.name)


## Rim texels on both sides of the cell edges where the quarter-ring of an inner corner ends: [[cell, tile pixel]].
func _lip_pairs(cell: Vector2i, kind: String) -> Array:
	var strip := VolcanoArt.STRIP_PX
	var rim := VolcanoArt.RIM_PX
	var east := kind.contains("E")
	var north := kind.contains("N")
	var band := []
	for k in rim:
		band.append(CELL - strip + k if east else strip - rim + k)
	var rows_band := []
	for k in rim:
		rows_band.append(strip - rim + k if north else CELL - strip + k)
	var out := []
	var vy := 0 if north else CELL - 1
	var ny := CELL - 1 if north else 0
	var vcell := cell + Vector2i(0, -1 if north else 1)
	for x: int in band:
		out.append([[cell, Vector2i(x, vy)], [vcell, Vector2i(x, ny)]])
	var hx := CELL - 1 if east else 0
	var nx := 0 if east else CELL - 1
	var hcell := cell + Vector2i(1 if east else -1, 0)
	for y: int in rows_band:
		out.append([[cell, Vector2i(hx, y)], [hcell, Vector2i(nx, y)]])
	return out


func test_inner_corner_lip_joins_neighbours() -> void:
	var decor := (load(DECOR_SCENE) as PackedScene).instantiate()
	add_node(decor)
	var atlas := _atlas()
	var by_cell := _pieces_by_cell(decor)
	var kinds := _piece_kinds(decor)
	var want := VolcanicGround.luma(ArtPalette.color("volcano_rim"))
	var inner := 0
	var bad := 0
	for cell: Vector2i in kinds:
		if not String(kinds[cell]).begins_with("I"):
			continue
		inner += 1
		for pair: Array in _lip_pairs(cell, kinds[cell]):
			for side: Array in pair:
				var c := _cliff_color(atlas, by_cell, side[0] * CELL + side[1])
				if c.a < 0.9 or absf(VolcanicGround.luma(c) - want) > 0.03:
					bad += 1
					if bad <= 5:
						fail("the %s lip of cell %s does not join the rim at cell %s pixel %s (alpha %.2f, luma %.3f, rim %.3f)"
								% [kinds[cell], cell, side[0], side[1], c.a, VolcanicGround.luma(c), want])
	check(inner >= 2, "inner corners found (%d)" % inner)
	check_eq(bad, 0, "every inner corner lip joins the rim band of its neighbours")


func test_wrap_face_fades_out() -> void:
	var atlas := _atlas()
	var m := VolcanoArt.MARGIN
	for kind in ["SE", "SW"]:
		var r := VolcanoArt.region(kind)
		var alphas := []
		# Columns beyond the tile, ordered from the tile edge outwards.
		for past in range(1, m + 1):
			var px := m + CELL - 1 + past if kind == "SE" else m - past
			var top := 0.0
			for py in range(m + CELL - VolcanoArt.STRIP_PX, VolcanoArt.PIECE):
				top = maxf(top, atlas.get_pixel(r.position.x + px, r.position.y + py).a)
			alphas.append(top)
		check(alphas[0] >= 0.99, "%s wrap face starts opaque at the tile edge (%.2f)" % [kind, alphas[0]])
		check(alphas[m - 1] <= 0.05, "%s wrap face fades out at the piece edge (%.2f)" % [kind, alphas[m - 1]])
		for i in range(m - VolcanoArt.WRAP_FADE_PX, m):
			check(alphas[i] <= alphas[i - 1] + 0.001, "%s wrap alpha does not rise %d px past the tile" % [kind, i + 1])
			check(alphas[i - 1] - alphas[i] <= 0.25, "%s wrap alpha has no hard step %d px past the tile" % [kind, i + 1])


## Premultiplied luminance of an atlas texel (the face over black).
func _lum(img: Image, x: int, y: int) -> float:
	var c := img.get_pixel(x, y)
	return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * c.a


func test_cliff_face_has_no_seams() -> void:
	var atlas := _atlas()
	var m := VolcanoArt.MARGIN
	var lo := m + CELL - VolcanoArt.STRIP_PX
	var hi := m + CELL + VolcanoArt.FACE_DEPTH
	var band_lo := m - VolcanoArt.BAND_PX
	var band_hi := m + VolcanoArt.STRIP_PX
	# [kind, run along x (S, N) or along y (E, W), first and last cross row of the face or band]
	for spec in [["S", true, lo, hi], ["N", true, band_lo, band_hi], ["E", false, lo, hi], ["W", false, band_lo, band_hi]]:
		var r := VolcanoArt.region(spec[0])
		var seam := 0.0
		var inner := 0.0
		var n := 0
		for k in range(spec[2], spec[3]):
			var a: Array = [m + CELL - 1, k] if spec[1] else [k, m + CELL - 1]
			var b: Array = [m, k] if spec[1] else [k, m]
			var c: Array = [m + CELL / 2 - 1, k] if spec[1] else [k, m + CELL / 2 - 1]
			var d: Array = [m + CELL / 2, k] if spec[1] else [k, m + CELL / 2]
			seam += absf(_lum(atlas, r.position.x + a[0], r.position.y + a[1]) - _lum(atlas, r.position.x + b[0], r.position.y + b[1]))
			inner += absf(_lum(atlas, r.position.x + c[0], r.position.y + c[1]) - _lum(atlas, r.position.x + d[0], r.position.y + d[1]))
			n += 1
		check(seam / n <= inner / n + 2.0 / 255.0,
				"%s pieces join without a seam (step %.4f, inner %.4f)" % [spec[0], seam / n, inner / n])
	# The strata shading repeats with the tile, so the right edge of one piece continues into the next.
	var worst := 0.0
	for depth in range(0, VolcanoArt.FACE_DEPTH + 1):
		for tx in range(-VolcanoArt.MARGIN, VolcanoArt.MARGIN):
			worst = maxf(worst, absf(VolcanoArt.strata(tx, depth) - VolcanoArt.strata(tx + CELL, depth)))
	check(worst <= 0.0001, "strata shading repeats every tile (max step %.4f)" % worst)
	# Straight pieces repeat their opaque texels past both tile ends, equal to the continuing neighbour.
	for spec in [["S", true], ["N", true], ["E", false], ["W", false]]:
		var r := VolcanoArt.region(spec[0])
		var bled := 0
		var off := 0
		for cross in VolcanoArt.PIECE:
			for pair in [[m - 1, m + CELL - 1], [m + CELL, m]]:
				var at: Vector2i = Vector2i(pair[0], cross) if spec[1] else Vector2i(cross, pair[0])
				var twin: Vector2i = Vector2i(pair[1], cross) if spec[1] else Vector2i(cross, pair[1])
				var c := atlas.get_pixel(r.position.x + at.x, r.position.y + at.y)
				if c.a < 1.0:
					continue
				bled += 1
				var t := atlas.get_pixel(r.position.x + twin.x, r.position.y + twin.y)
				if absf(c.r - t.r) > 2.0 / 255.0 or absf(c.g - t.g) > 2.0 / 255.0 or absf(c.b - t.b) > 2.0 / 255.0:
					off += 1
		check(bled >= 2 * VolcanoArt.STRIP_PX, "%s piece bleeds past both tile ends (%d texels)" % [spec[0], bled])
		check_eq(off, 0, "%s bleed texels equal the continuing neighbour" % spec[0])


func test_l5_props_use_palette_tint_key() -> void:
	var lvl := await _open()
	var want := ArtPalette.color("volcano_ash")
	var found := 0
	for i in range(8, 15):
		var prop := lvl.get_node_or_null("Actors/Prop%d" % i) as SwayProp
		check(prop != null, "L5 Prop%d is a SwayProp" % i)
		if prop == null:
			continue
		found += 1
		check_eq(prop.tint, Color.WHITE, "Prop%d keeps no fixed tint colour" % i)
		check_eq(prop.tint_key, "volcano_ash", "Prop%d tints from the palette key volcano_ash" % i)
		check(prop.sprite.self_modulate.is_equal_approx(want), "Prop%d self_modulate is the ash colour" % i)
		var m := prop.sprite.modulate
		check(Color(m.r, m.g, m.b).is_equal_approx(Color.WHITE), "Prop%d modulate keeps only the canopy fade alpha" % i)
	check_eq(found, 7, "seven ash-tinted props")


# --- (e) reduce motion and flashing ----------------------------------------------------------------

func _glows(decor: Node) -> Array:
	return decor.find_children("*", "Sprite2D", true, false).filter(func(n): return n is LavaGlow)


func test_reduce_motion_holds_glow_and_stops_sparks() -> void:
	_use_data_dir("reduce_on", true)
	var lvl := await _open()
	var decor := _decor(lvl)
	var before := {}
	for glow: LavaGlow in _glows(decor):
		check_true(glow.is_reduced(), "%s reads reduce" % glow.name)
		before[glow] = glow.modulate.a
	for vent in decor.vents():
		check_false((vent.get_node("Sparks") as CPUParticles2D).emitting, "%s sparks off under reduce" % vent.name)
		check_true((vent.get_node("Smoke") as CPUParticles2D).emitting, "%s smoke stays" % vent.name)
	await frames(120)
	for glow: LavaGlow in before:
		check_eq(glow.modulate.a, before[glow], "%s glow constant under reduce" % glow.name)
	_restore_data_dir()


func test_glow_pulses_without_reduce() -> void:
	_use_data_dir("reduce_off", false)
	var lvl := await _open()
	var decor := _decor(lvl)
	var glows := _glows(decor)
	check(glows.size() >= MIN_CRACKS, "glows found (%d)" % glows.size())
	var low := {}
	var high := {}
	for i in 120:
		await frames(1)
		for glow: LavaGlow in glows:
			low[glow] = minf(low.get(glow, 1.0), glow.modulate.a)
			high[glow] = maxf(high.get(glow, 0.0), glow.modulate.a)
	for glow: LavaGlow in glows:
		check(high[glow] - low[glow] > 0.02, "%s pulses" % glow.name)
	for vent in decor.vents():
		check_true((vent.get_node("Sparks") as CPUParticles2D).emitting, "%s sparks emit" % vent.name)
	_restore_data_dir()


func test_glow_never_flashes() -> void:
	var decor := (load(DECOR_SCENE) as PackedScene).instantiate()
	add_node(decor)
	var glows := _glows(decor)
	check(glows.size() >= MIN_CRACKS, "glows found")
	for glow: LavaGlow in glows:
		check(glow.pulse_hz <= LavaGlow.MAX_PULSE_HZ, "%s pulse %.2f Hz (at most 1)" % [glow.name, glow.pulse_hz])
		var prev := LavaGlow.alpha_at(0.0, glow.pulse_hz, glow.alpha_min, glow.alpha_max, glow.phase)
		var trend := 0
		var extrema := 0
		var lo := prev
		var hi := prev
		for i in range(1, 361):
			var a := LavaGlow.alpha_at(i / 120.0, glow.pulse_hz, glow.alpha_min, glow.alpha_max, glow.phase)
			var d := signi(int(signf(a - prev)))
			if d != 0 and trend != 0 and d != trend:
				extrema += 1
			if d != 0:
				trend = d
			prev = a
			lo = minf(lo, a)
			hi = maxf(hi, a)
		check(extrema <= 9, "%s: %d turns in 3 s (at most 3 per second)" % [glow.name, extrema])
		check(hi - lo <= LavaGlow.MAX_SWING + 0.001, "%s swing %.2f" % [glow.name, hi - lo])


# --- (f) surfaces and tileset ----------------------------------------------------------------------

func test_surfaces_unchanged() -> void:
	var lvl := await _open()
	var json := JSON.new()
	check_eq(json.parse(FileAccess.get_file_as_string(SURFACES)), OK, "surface fixture parses")
	var baseline: Dictionary = json.data
	var now: Dictionary = load("res://tests/support/capture_l5_surfaces.gd").collect(lvl, FileAccess.get_file_as_string(LAYOUT))
	check_eq(now.size(), baseline.size(), "every cell sampled")
	var changed := 0
	for key in baseline:
		if String(now.get(key, "")) != String(baseline[key]):
			changed += 1
			if changed <= 5:
				fail("surface at cell %s changed: %s -> %s" % [key, baseline[key], now.get(key, "")])
	check_eq(changed, 0, "surfaces as recorded before the dressing")


# --- (g) ground material ---------------------------------------------------------------------------

func test_ground_material_copies_the_palette() -> void:
	var lvl := (load(LEVEL) as PackedScene).instantiate()
	add_node(lvl)
	var first: ShaderMaterial = null
	for layer_name in TILE_LAYERS:
		var mat := (lvl.get_node(layer_name) as CanvasItem).material as ShaderMaterial
		check(mat != null and mat.shader != null and mat.shader.resource_path == SHADER,
				"L5 %s uses the volcanic ground shader" % layer_name)
		if first == null:
			first = mat
		check(mat == first, "L5 %s shares the one ground material" % layer_name)
		check(mat != null and mat.resource_path == MATERIAL, "L5 %s uses %s" % [layer_name, MATERIAL])
	for sprite: Sprite2D in _decor(lvl).corner_grounds():
		check(sprite.material == first, "corner ground %s shares the ground material" % sprite.name)
	if first == null:
		return
	for param in PALETTE_PARAMS:
		var got: Color = first.get_shader_parameter(param)
		var want := ArtPalette.color(PALETTE_PARAMS[param])
		for ch in 3:
			check(absf(got[ch] - want[ch]) <= 1.0 / 255.0 + 0.0005,
					"%s channel %d equals palette %s" % [param, ch, PALETTE_PARAMS[param]])
	var detail: Texture2D = first.get_shader_parameter("detail_tex")
	check(detail != null and detail.resource_path == DETAIL, "detail texture is the committed volcanic detail")
	for level_id in OTHER_LEVELS:
		var other := (load(LEVEL_DIR + level_id + ".tscn") as PackedScene).instantiate()
		add_node(other)
		for layer_name in TILE_LAYERS:
			var mat := (other.get_node(layer_name) as CanvasItem).material as ShaderMaterial
			check_false(mat != null and mat.shader != null and mat.shader.resource_path == SHADER,
					"%s %s keeps its own ground" % [level_id, layer_name])
