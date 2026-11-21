class_name EventEffects
extends Node2D
## Applies the declarative event effects of data/events.json to the level world. It listens to the EventBus:
## event_triggered starts the event presentation (actor animation, overlays) and, actor_impact_seconds later, the
## effects on animals, items, the castaway and the ground; event_ended and restarts stop everything again. Effects
## only move or nudge things: they never touch the session, the timer or a task, and they spare protected entities
## (counting for a done task) as well as carried, flying and worn ones. No level, task or event id appears here:
## everything comes from the level JSON (params) and the scene (Zones, EventAnchors).

const EVENTS_SECTION := "events"
const FEEDBACK_PATH := "res://data/feedback.json"
const MUD_MATERIAL := "mud"
const SPLAT_FRAMES := "res://assets/graphics/splats/PNG/Default (256px)/splat%02d.png"
const SPLAT_FRAME_COUNT := 8  # balance-exempt: frames of the splat set in the asset pack
const RAIN_TEXTURE := "res://assets/graphics/particles/PNG/circle_01.png"
const COCONUT_KIND := "coconut"
const STUN_CAUSE := "event"
## Effect name of data/events.json -> handler method.
const EFFECT_HANDLERS := {
	"take_worn": "_effect_take_worn",
	"take_held": "_effect_take_held",
	"stun_player": "_effect_stun_player",
	"panic_animals": "_effect_panic_animals",
	"relocate_entities": "_effect_relocate_entities",
	"slippery_ground": "_effect_slippery_ground",
}
## Event type -> presentation method (actor animation and overlays); types without one only show the feedback.
const PRESENTATIONS := {
	"parrot_steal_hat": "_present_flyover",
	"coconut_throw": "_present_volley",
	"mud_trail": "_present_trail",
	"rain_panic": "_present_rain",
}
## Event type -> animal kind whose sprite plays the event actor.
const ACTOR_KINDS := {
	"parrot_steal_hat": "parrot",
	"coconut_throw": "monkey",
	"mud_trail": "pig",
}

var _level: LevelBase
var _cfg := {}
var _types := {}
var _active := {}
var _nodes := {}
var _pending: Array = []
var _relocations := {}
var _cells: Array = []
var _cells_ready := false
var _warned := {}


func _ready() -> void:
	_cfg = Balance.get_section(EVENTS_SECTION)
	_level = get_parent() as LevelBase
	EventBus.event_triggered.connect(_on_event_triggered)
	EventBus.event_ended.connect(_on_event_ended)
	EventBus.level_restarted.connect(_on_level_restarted)


func _exit_tree() -> void:
	stop_all()
	for pair in [[EventBus.event_triggered, _on_event_triggered], [EventBus.event_ended, _on_event_ended],
			[EventBus.level_restarted, _on_level_restarted]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


func _physics_process(delta: float) -> void:
	if _pending.is_empty():
		return
	var due: Array = []
	for entry in _pending:
		entry["left"] = float(entry["left"]) - delta
		if entry["left"] <= 0.0:
			due.append(entry)
	for entry in due:
		_pending.erase(entry)
		if _active.has(entry["event_id"]):
			_apply_effects(_active[entry["event_id"]])


# --- Event lifecycle ---------------------------------------------------------------------------------

func _session_entry(event_id: String) -> Dictionary:
	if _level == null or _level.level_session() == null:
		return {}
	for entry in _level.level_session().schedule():
		if String(entry["id"]) == event_id:
			return entry
	return {}


func _on_event_triggered(event_id: String) -> void:
	var entry := _session_entry(event_id)
	if entry.is_empty():
		return
	stop_event(event_id)
	_active[event_id] = entry
	_nodes[event_id] = []
	var present := String(PRESENTATIONS.get(String(entry["type"]), ""))
	if present != "":
		call(present, entry)
	_pending.append({"event_id": event_id, "left": float(_cfg.get("actor_impact_seconds", 0.0))})


func _on_event_ended(event_id: String) -> void:
	stop_event(event_id)


func _on_level_restarted(_level_id: String) -> void:
	stop_all()


## Stops one event: pending effects, actors, overlays and its surface override.
func stop_event(event_id: String) -> void:
	_active.erase(event_id)
	_pending = _pending.filter(func(e: Dictionary) -> bool: return e["event_id"] != event_id)
	for node in _nodes.get(event_id, []):
		if is_instance_valid(node):
			node.queue_free()
	_nodes.erase(event_id)
	if _level != null:
		_level.clear_surface_override(event_id)


func stop_all() -> void:
	for event_id in _nodes.keys():
		stop_event(String(event_id))
	_active.clear()
	_pending.clear()


func _apply_effects(entry: Dictionary) -> void:
	_relocations.clear()
	var spec: Dictionary = _event_types().get(String(entry["type"]), {})
	for effect in spec.get("effects", []):
		var handler := String(EFFECT_HANDLERS.get(String(effect), ""))
		if handler == "":
			if not _warned.has(effect):
				_warned[effect] = true
				push_warning("EventEffects: unknown effect %s ignored" % effect)
			continue
		call(handler, entry)


func _event_types() -> Dictionary:
	if _types.is_empty():
		_types = LevelDef.load_event_types()["types"]
	return _types


func _rng(entry: Dictionary) -> SeededRng:
	var level_seed := _level.level_def().level_seed if _level.level_def() != null else 0
	return SeededRng.new(level_seed + int(entry.get("index", 0)))


func _track(event_id: String, node: Node) -> void:
	if not _nodes.has(event_id):
		_nodes[event_id] = []
	_nodes[event_id].append(node)


# --- Effects -------------------------------------------------------------------------------------------

func _registry() -> EntityRegistry:
	return _level.entity_registry() if _level != null else null


func _movable(e: Node2D) -> bool:
	var reg := _registry()
	return e.call("is_free") and (reg == null or not reg.is_protected(e))


func _effect_take_worn(entry: Dictionary) -> void:
	var reg := _registry()
	if reg == null:
		return
	var params: Dictionary = entry.get("params", {})
	var centre := _place_of(String(params.get("flee_zone", "")), String(entry["id"]))
	var rng := _rng(entry)
	for item in reg.items():
		if String(item.get("worn_by")) == "" or reg.is_protected(item):
			continue
		item.call("take_off")
		var pos := _free_point_near(centre, float(_cfg.get("flee_drop_radius_px", 0.0)), rng)
		item.call("relocate_to", pos)
		_relocations[String(item.get("uid"))] = pos
		EventBus.fx_anchor.emit(String(item.get("kind")), pos)


func _effect_take_held(_entry: Dictionary) -> void:
	var castaway := _level.castaway() if _level != null else null
	if castaway != null and castaway.has_method("drop_carried"):
		castaway.call("drop_carried")


func _effect_stun_player(entry: Dictionary) -> void:
	var castaway := _level.castaway() if _level != null else null
	if castaway == null or not castaway.has_method("bonk"):
		return
	var params: Dictionary = entry.get("params", {})
	var from := _place_of(String(params.get("thrower_zone", params.get("lane", ""))), String(entry["id"]))
	var dir := castaway.global_position - from
	castaway.call("bonk", STUN_CAUSE, dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN)


func _effect_panic_animals(entry: Dictionary) -> void:
	var reg := _registry()
	if reg == null:
		return
	var kind := String(entry.get("params", {}).get("kind", ""))
	var seconds := float(_cfg.get("panic_seconds", 1.0))
	for animal in reg.animals():
		if kind != "" and String(animal.get("kind")) != kind:
			continue
		if not _movable(animal) or animal.get("brain").unreachable:
			continue
		animal.call("panic", seconds)


func _effect_relocate_entities(entry: Dictionary) -> void:
	var reg := _registry()
	if reg == null:
		return
	var params: Dictionary = entry.get("params", {})
	var kind := String(params.get("kind", ""))
	var area := _level.zone(String(params.get("zone", params.get("lane", ""))))
	var targets: Array = []
	for e in reg.entities():
		if kind != "":
			if String(e.get("kind")) != kind:
				continue
		elif area != null:
			if not area.contains_point(e.global_position):
				continue
		elif not e.call("is_animal"):
			continue
		if _movable(e):
			targets.append(e)
	targets.sort_custom(func(a: Node, b: Node) -> bool: return String(a.get("uid")) < String(b.get("uid")))
	var rng := _rng(entry)
	var radius := float(_cfg.get("scatter_radius_px", 0.0))
	for e in targets:
		var centre: Vector2 = e.get("home") if e.get("home") is Vector2 else e.global_position
		var pos := _free_point_near(centre, radius, rng)
		e.call("relocate_to", pos)
		_relocations[String(e.get("uid"))] = pos
		EventBus.fx_anchor.emit(String(e.get("kind")), pos)


func _effect_slippery_ground(entry: Dictionary) -> void:
	var area := _level.zone(String(entry.get("params", {}).get("zone", "")))
	if area != null:
		_level.set_surface_override(String(entry["id"]), area, Grabbable.SURFACE_MUD)


# --- Presentations -------------------------------------------------------------------------------------

func _actor(entry: Dictionary, sprite_scale: float) -> EventActor:
	var kind := String(ACTOR_KINDS.get(String(entry["type"]), ""))
	var actor := EventActor.make(String(EntityDefs.get_animal(kind).get("sprite", "")), sprite_scale)
	actor.name = "Actor_%s" % entry["id"]
	add_child(actor)
	_track(String(entry["id"]), actor)
	return actor


## Parrot: swoops in from the anchor over the first wearer (or the castaway) and off to the flee zone.
func _present_flyover(entry: Dictionary) -> void:
	var event_id := String(entry["id"])
	var start := _anchor_pos(event_id)
	var over := _level.castaway().global_position if _level.castaway() != null else start
	var reg := _registry()
	if reg != null:
		for item in reg.items():
			if String(item.get("worn_by")) != "" and not reg.is_protected(item):
				over = item.global_position
				break
	var flee := _place_of(String(entry.get("params", {}).get("flee_zone", "")), event_id)
	var actor := _actor(entry, float(_cfg.get("actor_scale", 1.0)))
	var fly := float(_cfg.get("actor_fly_seconds", 1.0))
	actor.fly_path([start, over, flee], fly * 2.0, float(_cfg.get("actor_height_px", 0.0)))


## Monkey: sits at the thrower zone and lobs coconuts at the castaway; the first one lands at the impact time.
func _present_volley(entry: Dictionary) -> void:
	var event_id := String(entry["id"])
	var params: Dictionary = entry.get("params", {})
	var from := _place_of(String(params.get("thrower_zone", "")), event_id)
	var monkey := _actor(entry, float(_cfg.get("actor_scale", 1.0)))
	monkey.global_position = from
	monkey.reset_physics_interpolation()
	var throws := maxi(1, int(params.get("throws", 1)))
	var coconut_path := String(EntityDefs.get_item(COCONUT_KIND).get("sprite", ""))
	var target := _level.castaway().global_position if _level.castaway() != null else from
	var gap := float(_cfg.get("coconut_throw_gap_seconds", 0.0))
	for i in throws:
		var nut := EventActor.make(coconut_path, float(_cfg.get("coconut_scale", 1.0)))
		nut.name = "Coconut%d_%s" % [i, event_id]
		nut.visible = false
		add_child(nut)
		_track(event_id, nut)
		var aim := target + Vector2((float(i) - float(throws - 1) / 2.0) * float(_cfg.get("coconut_spread_px", 0.0)), 0.0)
		var t := get_tree().create_timer(gap * i, true, true)
		t.timeout.connect(_launch_nut.bind(nut, from, aim))


func _launch_nut(nut: EventActor, from: Vector2, aim: Vector2) -> void:
	if not is_instance_valid(nut):
		return
	nut.visible = true
	nut.fly_path([from, aim], float(_cfg.get("actor_impact_seconds", 1.0)), float(_cfg.get("coconut_arc_height", 0.0)))


## Muddy piglet: trots along the mud zone and back while splats cover the slippery ground.
func _present_trail(entry: Dictionary) -> void:
	var event_id := String(entry["id"])
	var area := _level.zone(String(entry.get("params", {}).get("zone", "")))
	var rect := _zone_rect(area) if area != null else Rect2(_anchor_pos(event_id), Vector2.ZERO)
	var mud := _material_color(MUD_MATERIAL)
	mud.a = float(_cfg.get("mud_splat_alpha", 1.0))
	var spacing := maxf(1.0, float(_cfg.get("mud_splat_spacing_px", 1.0)))
	var rng := _rng(entry)
	var y := rect.position.y + spacing / 2.0
	var index := 0
	while y < rect.end.y:
		var x := rect.position.x + spacing / 2.0
		while x < rect.end.x:
			var splat := Sprite2D.new()
			splat.name = "Mud%d_%s" % [index, event_id]
			splat.texture = load(SPLAT_FRAMES % (index % SPLAT_FRAME_COUNT))
			splat.modulate = mud
			splat.scale = Vector2.ONE * float(_cfg.get("mud_splat_scale", 1.0))
			splat.rotation = rng.randf() * TAU
			splat.z_index = -1
			add_child(splat)
			splat.global_position = Vector2(x, y) + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * spacing / 2.0
			_track(event_id, splat)
			index += 1
			x += spacing
		y += spacing
	var piglet := _actor(entry, float(_cfg.get("piglet_scale", 1.0)))
	piglet.body.modulate = mud.lerp(Color.WHITE, 0.5)
	var left := Vector2(rect.position.x, rect.get_center().y)
	var right := Vector2(rect.end.x, rect.get_center().y)
	if rect.size.y > rect.size.x:
		left = Vector2(rect.get_center().x, rect.position.y)
		right = Vector2(rect.get_center().x, rect.end.y)
	var duration := float(entry["end"]) - float(entry["start"])
	piglet.fly_path([left, right, left], maxf(float(_cfg.get("actor_fly_seconds", 1.0)), duration), 0.0, false)


## Rain: a light blue tint and falling drops over the screen (fewer drops with reduced effects).
func _present_rain(entry: Dictionary) -> void:
	var event_id := String(entry["id"])
	var layer := CanvasLayer.new()
	layer.name = "Rain_%s" % event_id
	layer.layer = int(_cfg.get("rain_layer", 1))
	add_child(layer)
	_track(event_id, layer)
	var view := get_viewport_rect().size
	var gradient := Gradient.new()
	var top := ArtPalette.color("water_deep")
	top.a = float(_cfg.get("rain_tint_alpha", 0.0))
	var bottom := ArtPalette.color("water")
	bottom.a = top.a / 2.0
	gradient.colors = PackedColorArray([top, bottom])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var tint := TextureRect.new()
	tint.name = "Tint"
	tint.texture = tex
	tint.stretch_mode = TextureRect.STRETCH_SCALE
	tint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.size = view
	layer.add_child(tint)
	var drops := CPUParticles2D.new()
	drops.name = "Drops"
	drops.texture = load(RAIN_TEXTURE)
	var reduced := FxSettings.read_reduce(_settings_path())
	drops.amount = int(_cfg.get("rain_reduced_amount" if reduced else "rain_particle_amount", 1))
	drops.lifetime = view.y / maxf(1.0, float(_cfg.get("rain_drop_speed", 1.0)))
	drops.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	drops.emission_rect_extents = Vector2(view.x / 2.0, 1.0)
	drops.position = Vector2(view.x / 2.0, 0.0)
	drops.direction = Vector2.DOWN
	drops.spread = 0.0
	drops.gravity = Vector2.ZERO
	drops.initial_velocity_min = float(_cfg.get("rain_drop_speed", 1.0))
	drops.initial_velocity_max = drops.initial_velocity_min
	drops.scale_amount_min = float(_cfg.get("rain_drop_scale", 1.0))
	drops.scale_amount_max = drops.scale_amount_min
	drops.color = ArtPalette.color("water")
	drops.preprocess = drops.lifetime
	layer.add_child(drops)
	drops.emitting = true


func _settings_path() -> String:
	var data_dir := get_node_or_null("/root/DataDir")
	return String(data_dir.call("file", FxSettings.FILE)) if data_dir != null else ""


# --- Places --------------------------------------------------------------------------------------------

func _anchor_pos(event_id: String) -> Vector2:
	for marker in get_tree().get_nodes_in_group(FeedbackDirector.EVENT_ANCHOR_GROUP):
		if marker is Node2D and _level.is_ancestor_of(marker) and String(marker.get("event_id")) == event_id:
			return (marker as Node2D).global_position
	return _level.spawn_position()


## Centre of the named zone, else the event anchor.
func _place_of(zone_id: String, event_id: String) -> Vector2:
	var area := _level.zone(zone_id) if zone_id != "" else null
	return area.global_position if area != null else _anchor_pos(event_id)


## Global rectangle of a zone's first rectangle shape (a square around a circle).
static func _zone_rect(area: Zone) -> Rect2:
	for child in area.get_children():
		var cs := child as CollisionShape2D
		if cs == null or cs.shape == null:
			continue
		var size := Vector2.ZERO
		if cs.shape is RectangleShape2D:
			size = (cs.shape as RectangleShape2D).size
		elif cs.shape is CircleShape2D:
			size = Vector2.ONE * (cs.shape as CircleShape2D).radius * 2.0
		return Rect2(cs.global_position - size / 2.0, size)
	return Rect2(area.global_position, Vector2.ZERO)


## Walkable cells reachable from the spawn and outside every pen (computed once per level).
func free_cells() -> Array:
	if _cells_ready or _level == null:
		return _cells
	_cells_ready = true
	var pens: Array = []
	for z in _level.get_node("Zones").get_children():
		if z is Zone and (z as Zone).contains:
			pens.append(z)
	var reach := _level.reachable_from(_level.cell_of(_level.spawn_position()))
	for cell in reach.keys():
		var centre := _level.cell_center(cell)
		if pens.any(func(z: Zone) -> bool: return z.contains_point(centre)):
			continue
		_cells.append(cell)
	_cells.sort()
	return _cells


## A seeded free cell centre within radius of pos, else the free cell nearest to pos.
func _free_point_near(pos: Vector2, radius: float, rng: SeededRng) -> Vector2:
	var near: Array = []
	var best := pos
	var best_d := INF
	for cell in free_cells():
		var c := _level.cell_center(cell)
		var d := c.distance_to(pos)
		if d <= radius:
			near.append(c)
		if d < best_d:
			best_d = d
			best = c
	if near.is_empty():
		return best
	return near[rng.randi_range(0, near.size() - 1)]


static func _material_color(material_name: String) -> Color:
	var data: Variant = EntityDefs.read_json(FEEDBACK_PATH)["data"]
	var materials: Dictionary = data.get("materials", {}) if data is Dictionary else {}
	return Color.html(String(materials.get(material_name, "#ffffff")))


# --- Test API ------------------------------------------------------------------------------------------

func active_event_ids() -> Array:
	var ids := _active.keys()
	ids.sort()
	return ids


func actor_nodes() -> Array:
	return get_children().filter(func(n: Node) -> bool: return n is EventActor and not n.is_queued_for_deletion())


func overlay_nodes() -> Array:
	var out: Array = []
	for event_id in _nodes:
		for node in _nodes[event_id]:
			if is_instance_valid(node) and not node.is_queued_for_deletion() and not node is EventActor:
				out.append(node)
	return out


func pending_effects() -> int:
	return _pending.size()


## uid -> position of every entity moved by the last effects.
func last_relocations() -> Dictionary:
	return _relocations.duplicate()
