class_name EventEffects
extends Node2D
## Applies the declarative event effects of data/events.json to the level world. It listens to the EventBus:
## event_triggered starts the event presentation (actor animation, overlays) and, actor_impact_seconds later, the
## effects on animals, items, the castaway and the ground; event_ended and restarts stop everything again. Effects
## only move or nudge things: they never touch the session, the timer or a task, and they spare protected entities
## (counting for a done task) as well as carried, flying and worn ones – except the thief effects, which take an
## unprotected worn or carried thing. No level, task or event id appears here:
## everything comes from the level JSON (params) and the scene (Zones, EventAnchors).

const EVENTS_SECTION := "events"
const FEEDBACK_PATH := "res://data/feedback.json"
const MUD_MATERIAL := "mud"
const SPLAT_FRAMES := "res://assets/graphics/splats/PNG/Default (256px)/splat%02d.png"
const SPLAT_FRAME_COUNT := 8  # balance-exempt: frames of the splat set in the asset pack
const RAIN_TEXTURE := "res://assets/graphics/particles/PNG/circle_01.png"
const DUST_TEXTURE := "res://assets/graphics/particles/PNG/dirt_01.png"
const FOAM_TEXTURE := "res://assets/graphics/particles/PNG/circle_02.png"
const COCONUT_KIND := "coconut"
const STUN_CAUSE := "event"
## Where a thief looks for a wearable, most tempting first.
const STEAL_ORDER := ["worn", "carried", "loose"]
## Effect name of data/events.json -> handler method.
const EFFECT_HANDLERS := {
	"take_worn": "_effect_take_worn",
	"take_held": "_effect_take_held",
	"steal_wearable": "_effect_steal_wearable",
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
	"goat_stampede": "_present_stampede",
	"wave_wash": "_present_wave",
}
## Event type -> animal kind whose sprite plays the event actor.
const ACTOR_KINDS := {
	"parrot_steal_hat": "parrot",
	"coconut_throw": "monkey",
	"mud_trail": "pig",
	"goat_stampede": "goat",
}
## Event type -> [lead key, run key] of the events balance: the effects land lead + run / 2 after the trigger (when
## the stampede or the wave edge reaches the middle). Other types use actor_impact_seconds.
const IMPACT_KEYS := {
	"goat_stampede": ["stampede_lead_seconds", "stampede_run_seconds"],
	"wave_wash": ["", "wave_sweep_seconds"],
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
	_pending.append({"event_id": event_id, "left": impact_seconds(entry)})


## Seconds from the trigger to the effects of an event entry.
func impact_seconds(entry: Dictionary) -> float:
	var keys: Array = IMPACT_KEYS.get(String(entry.get("type", "")), [])
	if keys.is_empty():
		return float(_cfg.get("actor_impact_seconds", 0.0))
	var lead := float(_cfg.get(String(keys[0]), 0.0)) if String(keys[0]) != "" else 0.0
	return lead + float(_cfg.get(String(keys[1]), 0.0)) * 0.5


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


## The one wearable a thief grabs: a worn unprotected one, else the castaway's carried one, else one lying free;
## never a protected or flying item, ties broken by uid. Returns null when there is none.
func _steal_target() -> Node2D:
	var reg := _registry()
	if reg == null:
		return null
	var castaway := _level.castaway()
	var carried: Node2D = castaway.get_carried() if castaway != null and castaway.has_method("get_carried") else null
	var best: Node2D = null
	var best_rank := STEAL_ORDER.size()
	for item in reg.items():
		if not item.call("is_wearable") or item.call("is_flying") or reg.is_protected(item):
			continue
		var place := ""
		if String(item.get("worn_by")) != "":
			place = "worn"
		elif item == carried:
			place = "carried"
		elif item.call("is_free"):
			place = "loose"
		var rank := STEAL_ORDER.find(place)
		if rank < 0:
			continue
		if best == null or rank < best_rank or (rank == best_rank and String(item.get("uid")) < String(best.get("uid"))):
			best = item
			best_rank = rank
	return best


func _effect_steal_wearable(entry: Dictionary) -> void:
	var item := _steal_target()
	if item == null:
		return
	var castaway := _level.castaway()
	if String(item.get("worn_by")) != "":
		item.call("take_off")
	elif castaway != null and castaway.has_method("get_carried") and castaway.get_carried() == item:
		castaway.call("drop_carried")
	var params: Dictionary = entry.get("params", {})
	var centre := _place_of(String(params.get("flee_zone", "")), String(entry["id"]))
	var pos := _free_point_near(centre, float(_cfg.get("flee_drop_radius_px", 0.0)), _rng(entry))
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
	var area := _area_param(params)
	if area != null and not area.contains_point(castaway.global_position):
		return
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
	var area := _area_param(params)
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
	var avoid: Zone = null
	if kind == "" and area != null:
		radius *= float(params.get("strength", 1.0))
		avoid = area
	for e in targets:
		var centre: Vector2 = e.get("home") if e.get("home") is Vector2 else e.global_position
		if avoid != null:
			centre = e.global_position
		var pos := _free_point_near(centre, radius, rng, avoid)
		e.call("relocate_to", pos)
		_relocations[String(e.get("uid"))] = pos
		EventBus.fx_anchor.emit(String(e.get("kind")), pos)


func _effect_slippery_ground(entry: Dictionary) -> void:
	var area := _level.zone(String(entry.get("params", {}).get("zone", "")))
	if area != null:
		_level.set_surface_override(String(entry["id"]), area, Grabbable.SURFACE_MUD)


## The zone named by the zone or lane param, or null.
func _area_param(params: Dictionary) -> Zone:
	var zone_id := String(params.get("zone", params.get("lane", "")))
	return _level.zone(zone_id) if zone_id != "" and _level != null else null


# --- Presentations -------------------------------------------------------------------------------------

func _actor(entry: Dictionary, sprite_scale: float) -> EventActor:
	var kind := String(ACTOR_KINDS.get(String(entry["type"]), ""))
	var actor := EventActor.make(String(EntityDefs.get_animal(kind).get("sprite", "")), sprite_scale)
	actor.name = "Actor_%s" % entry["id"]
	add_child(actor)
	_track(String(entry["id"]), actor)
	return actor


## Parrot: swoops in from the anchor over the wearable it will steal (or the castaway) and off to the flee zone.
func _present_flyover(entry: Dictionary) -> void:
	var event_id := String(entry["id"])
	var start := _anchor_pos(event_id)
	var over := _level.castaway().global_position if _level.castaway() != null else start
	var target := _steal_target()
	if target != null:
		over = target.global_position
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
		t.timeout.connect(_launch_nut.bind(nut.get_instance_id(), from, aim))


func _launch_nut(nut_id: int, from: Vector2, aim: Vector2) -> void:
	var nut := _live_actor(nut_id)
	if nut == null:
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


## Goat stampede: a striped warning tint over the lane, then goats charge from the lane end nearest to the event
## anchor to the other end, staggered and spread across the lane, with a dust trail (less dust with reduced effects).
func _present_stampede(entry: Dictionary) -> void:
	var event_id := String(entry["id"])
	var params: Dictionary = entry.get("params", {})
	var area := _area_param(params)
	var rect := _zone_rect(area) if area != null else Rect2(_anchor_pos(event_id), Vector2.ZERO)
	var horizontal := rect.size.x >= rect.size.y
	var length := rect.size.x if horizontal else rect.size.y
	var width := rect.size.y if horizontal else rect.size.x
	var along := Vector2.RIGHT if horizontal else Vector2.DOWN
	var across := Vector2.DOWN if horizontal else Vector2.RIGHT
	var tint := ArtPalette.color("ui_warning")
	tint.a = float(_cfg.get("stampede_tint_alpha", 0.0))
	var clear := tint
	clear.a = 0.0
	var stripe := maxi(1, int(_cfg.get("stampede_stripe_px", 1)))
	var telegraph := Sprite2D.new()
	telegraph.name = "Telegraph_%s" % event_id
	telegraph.texture = _gradient_texture([tint, clear], Vector2i(stripe * 2, stripe), Vector2.RIGHT, true)
	telegraph.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	telegraph.region_enabled = true
	telegraph.region_rect = Rect2(Vector2.ZERO, Vector2(length, width))
	telegraph.rotation = 0.0 if horizontal else PI * 0.5
	telegraph.z_index = -1
	add_child(telegraph)
	telegraph.global_position = rect.get_center()
	_track(event_id, telegraph)
	var start := rect.position + across * width * 0.5
	var finish := start + along * length
	var anchor := _anchor_pos(event_id)
	if finish.distance_to(anchor) < start.distance_to(anchor):
		var swap := start
		start = finish
		finish = swap
	var goats := maxi(1, int(params.get("goats", _cfg.get("stampede_goat_count", 1))))
	var lead := float(_cfg.get("stampede_lead_seconds", 0.0))
	var gap := float(_cfg.get("stampede_goat_gap_seconds", 0.0))
	var spread := float(_cfg.get("stampede_spread_px", 0.0))
	for i in goats:
		var goat := _actor(entry, float(_cfg.get("actor_scale", 1.0)))
		goat.name = "Goat%d_%s" % [i, event_id]
		var shift := across * (float(i) - float(goats - 1) * 0.5) * spread
		goat.global_position = start + shift
		goat.reset_physics_interpolation()
		var t := get_tree().create_timer(lead + gap * i, true, true)
		t.timeout.connect(_launch_goat.bind(goat.get_instance_id(), start + shift, finish + shift))
	var dust := _particles("Dust_%s" % event_id, DUST_TEXTURE, "stampede_dust_amount", "stampede_dust_reduced_amount")
	dust.lifetime = float(_cfg.get("stampede_run_seconds", 1.0)) * 0.5
	dust.emission_rect_extents = rect.size * 0.5
	dust.position = rect.get_center()
	dust.color = ArtPalette.color("sand")
	dust.scale_amount_min = float(_cfg.get("stampede_dust_scale", 1.0))
	dust.scale_amount_max = dust.scale_amount_min
	add_child(dust)
	_track(event_id, dust)
	dust.emitting = true


func _launch_goat(goat_id: int, from: Vector2, to: Vector2) -> void:
	var goat := _live_actor(goat_id)
	if goat == null:
		return
	goat.fly_path([from, to], float(_cfg.get("stampede_run_seconds", 1.0)), 0.0)


## The actor behind an instance id, or null once it is freed or queued for deletion (timers outlive actors).
func _live_actor(id: int) -> EventActor:
	var obj := instance_from_id(id)
	if obj == null or not is_instance_valid(obj) or obj.is_queued_for_deletion():
		return null
	return obj as EventActor


## Rectangle-emitting particles with the full or the reduced amount of the balance (reduce effects toggle).
func _particles(node_name: String, texture_path: String, full_key: String, reduced_key: String) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = node_name
	p.texture = load(texture_path)
	var reduced := FxSettings.read_reduce(_settings_path())
	p.amount = maxi(1, int(_cfg.get(reduced_key if reduced else full_key, 1)))
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.gravity = Vector2.ZERO
	return p


## A gradient texture of size along dir; hard switches the colours without blending (stripes).
static func _gradient_texture(colors: Array, size: Vector2i, dir: Vector2, hard: bool) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	if hard:
		gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = maxi(1, size.x)
	tex.height = maxi(1, size.y)
	tex.fill_from = Vector2(0.5, 0.5) - dir * 0.5
	tex.fill_to = Vector2(0.5, 0.5) + dir * 0.5
	return tex


## Big wave: a water band with a foam edge sweeps over the zone from its sea side (the side nearest to the level
## bounds) and retreats again; foam particles ride the edge (fewer with reduced effects).
func _present_wave(entry: Dictionary) -> void:
	var event_id := String(entry["id"])
	var area := _area_param(entry.get("params", {}))
	var rect := _zone_rect(area) if area != null else Rect2(_anchor_pos(event_id), Vector2.ZERO)
	var into := _sea_side(rect)
	var wave := Node2D.new()
	wave.name = "Wave_%s" % event_id
	add_child(wave)
	_track(event_id, wave)
	var deep := ArtPalette.color("water_deep")
	deep.a = float(_cfg.get("wave_tint_alpha", 0.0))
	var light := ArtPalette.color("water")
	light.a = deep.a
	var band := Sprite2D.new()
	band.name = "Band"
	band.centered = false
	band.texture = _gradient_texture([deep, light], Vector2i(2, 2), into, false)
	wave.add_child(band)
	var foam_px := float(_cfg.get("wave_foam_width_px", 1.0))
	var edge := Sprite2D.new()
	edge.name = "Foam"
	var white := Color.WHITE
	var fade := Color(1.0, 1.0, 1.0, 0.0)
	edge.texture = _gradient_texture([fade, white, fade], Vector2i(2, 2), Vector2.RIGHT, false)
	wave.add_child(edge)
	var foam := _particles("FoamParticles", FOAM_TEXTURE, "wave_foam_amount", "wave_foam_reduced_amount")
	foam.lifetime = float(_cfg.get("wave_retreat_seconds", 1.0))
	foam.color = Color.WHITE
	foam.scale_amount_min = float(_cfg.get("wave_foam_scale", 1.0))
	foam.scale_amount_max = foam.scale_amount_min
	wave.add_child(foam)
	foam.emitting = true
	var step := _wave_step.bind(rect, into, foam_px, band, edge, foam)
	step.call(0.0)
	var tween := wave.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(step, 0.0, 1.0, float(_cfg.get("wave_sweep_seconds", 1.0)))
	tween.tween_method(step, 1.0, 0.0, float(_cfg.get("wave_retreat_seconds", 1.0)))


## Unit vector pointing from the sea into the zone: the zone side nearest to the level bounds faces the sea.
func _sea_side(rect: Rect2) -> Vector2:
	var bounds := _level.get_bounds_rect()
	var gaps := {Vector2.DOWN: rect.position.y - bounds.position.y, Vector2.UP: bounds.end.y - rect.end.y,
			Vector2.RIGHT: rect.position.x - bounds.position.x, Vector2.LEFT: bounds.end.x - rect.end.x}
	var best := Vector2.DOWN
	for dir in gaps:
		if float(gaps[dir]) < float(gaps[best]):
			best = dir
	return best


## Places the wave band, its foam edge and the foam emitter for a sweep share (0 = at the sea edge, 1 = across).
func _wave_step(share: float, rect: Rect2, into: Vector2, foam_px: float, band: Sprite2D, edge: Sprite2D,
		foam: CPUParticles2D) -> void:
	if not is_instance_valid(band):
		return
	var vertical := into.x == 0.0
	var depth := (rect.size.y if vertical else rect.size.x) * share
	var span := rect.size.x if vertical else rect.size.y
	var sea := rect.position
	if into == Vector2.UP:
		sea = Vector2(rect.position.x, rect.end.y)
	elif into == Vector2.LEFT:
		sea = Vector2(rect.end.x, rect.position.y)
	var front := sea + into * depth
	var band_rect := Rect2(sea, Vector2.ZERO).expand(front + (Vector2(span, 0.0) if vertical else Vector2(0.0, span)))
	band.global_position = band_rect.position
	band.scale = band_rect.size / 2.0
	var mid := front + (Vector2(span * 0.5, 0.0) if vertical else Vector2(0.0, span * 0.5))
	edge.global_position = mid
	edge.rotation = into.angle()
	edge.scale = Vector2(foam_px, span) / 2.0
	foam.global_position = mid
	foam.emission_rect_extents = (Vector2(span, foam_px) if vertical else Vector2(foam_px, span)) * 0.5


## Foam edge centre of an active wave event (test API), or null without one.
func wave_front(event_id: String) -> Variant:
	for node in _nodes.get(event_id, []):
		if is_instance_valid(node) and String(node.name).begins_with("Wave_"):
			return (node.get_node("Foam") as Node2D).global_position
	return null


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


## A seeded free cell centre within radius of pos, else the free cell nearest to pos; cells inside avoid are skipped.
func _free_point_near(pos: Vector2, radius: float, rng: SeededRng, avoid: Zone = null) -> Vector2:
	var near: Array = []
	var best := pos
	var best_d := INF
	for cell in free_cells():
		var c := _level.cell_center(cell)
		if avoid != null and avoid.contains_point(c):
			continue
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
