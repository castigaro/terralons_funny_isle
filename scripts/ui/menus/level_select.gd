extends MenuScreen
## Level select: one row tile per campaign level with number, title, best stars and best time (won levels), "Locked"
## (not unlocked yet; the tile stays focusable but starts nothing) or "Coming soon" (scene not built yet).
## Initial focus is the first unlocked level that is not won yet. Esc goes back.

signal level_chosen(level_id: String)
signal back_pressed

const ICON_BACK := "res://assets/ui/ui-pack/PNG/Yellow/Default/arrow_basic_w.png"
const ICON_LOCKED := "res://assets/ui/ui-pack/PNG/Yellow/Default/icon_cross.png"
const STAR_FULL := "res://assets/ui/ui-pack/PNG/Yellow/Default/star.png"
const STAR_EMPTY := "res://assets/ui/ui-pack/PNG/Yellow/Default/star_outline.png"

var back_button: Button
## level id -> {button, state: "open"|"locked"|"soon", note: Label}
var tiles := {}
var _row: VBoxContainer
var _note_left := 0.0
var _flashing: Label


func _build() -> void:
	var box := make_panel()
	box.add_child(make_label("menu.level_select.title", {}, MenuTheme.VARIATION_HEADING))
	_row = VBoxContainer.new()
	_row.name = "Tiles"
	_row.add_theme_constant_override("separation", int(cfg.get("tile_separation", 0)))
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_row)
	back_button = make_button("menu.back", ICON_BACK)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(back_pressed.emit)
	box.add_child(back_button)
	rebuild()


## Builds the tiles from the Progress autoload (campaign order, unlocks and best values).
func rebuild() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_texts = _texts.filter(_is_live_text)
	tiles.clear()
	var campaign: Campaign = Progress.campaign()
	var model: ProgressModel = Progress.model()
	for level_id in campaign.ids():
		var entry := campaign.entry(level_id)
		var state := "open"
		if not entry["available"]:
			state = "soon"
		elif not model.is_unlocked(level_id):
			state = "locked"
		_row.add_child(_make_tile(entry, state, model))
	_first_focus = null
	var target := model.first_open_id()
	if tiles.has(target):
		_first_focus = tiles[target]["button"]
	elif not tiles.is_empty():
		_first_focus = tiles[campaign.first_id()]["button"]
	else:
		_first_focus = back_button


func _is_live_text(entry: Array) -> bool:
	var node: Variant = entry[0]
	return is_instance_valid(node) and (node as Node).is_inside_tree()


func _make_tile(entry: Dictionary, state: String, model: ProgressModel) -> Button:
	var level_id := String(entry["id"])
	var tile := Button.new()
	tile.name = "Tile_" + level_id
	tile.theme_type_variation = MenuTheme.VARIATION_TILE
	tile.focus_mode = Control.FOCUS_ALL
	tile.custom_minimum_size = Vector2(float(cfg.get("tile_width", 0)), float(cfg.get("tile_height", 0)))
	wire_button(tile)
	tile.pressed.connect(_on_tile_pressed.bind(level_id))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := int(cfg.get("tile_padding", 0))
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, pad)
	tile.add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)
	var number := Label.new()
	number.theme_type_variation = MenuTheme.VARIATION_ACCENT
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.custom_minimum_size.x = float(cfg.get("tile_number_width", 0))
	number.text = str(entry["number"])
	row.add_child(number)
	var title := Label.new()
	title.name = "Title"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if String(entry["title_key"]) != "":
		bind_text(title, String(entry["title_key"]))
	else:
		bind_text(title, "menu.level_number", {"n": entry["number"]})
	row.add_child(title)
	var note := Label.new()
	note.name = "Note"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.custom_minimum_size.x = float(cfg.get("tile_note_width", 0))
	if state == "open":
		row.add_child(_star_row(model.best_stars(level_id)))
		if model.is_won(level_id) and model.best_time(level_id) > 0.0:
			bind_text(note, "menu.best_time", {"time": FlowRules.format_time(model.best_time(level_id))})
		else:
			bind_text(note, "menu.new_level")
	else:
		var icon := TextureRect.new()
		icon.name = "Locked"
		icon.texture = load(ICON_LOCKED)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.custom_minimum_size.x = float(cfg.get("star_px", 0)) * float(Stars.MAX_STARS)
		row.add_child(icon)
		bind_text(note, "menu.locked" if state == "locked" else "menu.coming_soon")
		tile.modulate.a = float(cfg.get("locked_alpha", 1.0))
	row.add_child(note)
	_ignore_mouse(margin)
	tiles[level_id] = {"button": tile, "state": state, "note": note, "title": title}
	return tile


func _star_row(count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Stars"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var px := float(cfg.get("star_px", 0))
	for i in Stars.MAX_STARS:
		var star := TextureRect.new()
		star.name = "Star%d" % i
		star.texture = load(STAR_FULL if i < count else STAR_EMPTY)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.custom_minimum_size = Vector2(px, px)
		row.add_child(star)
	return row


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func _on_tile_pressed(level_id: String) -> void:
	var tile: Dictionary = tiles.get(level_id, {})
	if tile.is_empty():
		return
	if tile["state"] == "open":
		level_chosen.emit(level_id)
		return
	_flash(tile["note"])


## Pulses the Locked/Coming soon note so a press on a closed tile visibly does nothing.
func _flash(note: Label) -> void:
	_flashing = note
	_note_left = float(cfg.get("locked_label_s", 0))
	note.modulate = ArtPalette.color("ui_accent")


func _tick(delta: float) -> void:
	if _flashing == null:
		return
	_note_left -= delta
	if _note_left <= 0.0:
		if is_instance_valid(_flashing):
			_flashing.modulate = Color.WHITE
		_flashing = null


func is_flashing() -> bool:
	return _flashing != null


func tile_button(level_id: String) -> Button:
	return tiles[level_id]["button"] if tiles.has(level_id) else null


func tile_state(level_id: String) -> String:
	return String(tiles[level_id]["state"]) if tiles.has(level_id) else ""


func handle_input(event: InputEvent) -> bool:
	if is_back(event):
		back_pressed.emit()
		return true
	return false


func overflow_sample() -> void:
	rebuild()
