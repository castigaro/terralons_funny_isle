class_name FeedbackDirector
extends Node
## Level-scoped slapstick feedback: listens to every EventBus signal and plays the visual entries of
## data/feedback.json – popups (translated sound words), splats, smoke puffs, particles, emotes, flashes, screen
## shake, hit-stop, squash and recoil. Every effect type has a fixed pool sized to its cap in data/balance/
## feedback.json, so chaos never piles up and nothing is allocated after _ready. The director is the only writer
## of Engine.time_scale (hit-stop) and restores it on every way out (timer, pause, reset, free, safety check).
## Level scenes add one instance after the ground and before the actors (splats draw at z 0 between them); it is
## not an autoload so scene tests without it keep exact timing. Particle textures are black-backed and draw additive.

const FEEDBACK_PATH := "res://data/feedback.json"
const EVENT_BUS_SCRIPT := "res://scripts/autoload/event_bus.gd"
const FONT := preload(MenuTheme.FONT)
const CAMERA_GROUP := "game_camera"
const CASTAWAY_GROUP := "castaway"
const EVENT_ANCHOR_GROUP := "event_anchor"
const ANCHOR_SIGNALS := ["fx_anchor", "fx_anchor_node"]
const VISUAL_TYPES := ["popup", "splat", "puff", "particles", "emote", "flash"]
const COUNT_TYPES := ["squash", "recoil"]
const MS_PER_SECOND := 1000.0  # balance-exempt: unit conversion
const MAX_SIGNAL_ARGS := 4  # balance-exempt: number of generic adapters
const LAST_EFFECTS_SIZE := 64  # balance-exempt: length of the test ring buffer
const GOLDEN_ANGLE := 2.39996323  # balance-exempt: math constant that spreads splat rotations evenly
const POPUP_OUTLINE := Color(0.13, 0.09, 0.16)  # balance-exempt: colour of the comic outline

## Clock in milliseconds for the hit-stop cooldown, the flash rate limit and the safety check (injectable).
var clock: Callable
var map: FeedbackMap
var strengths: FxStrengths
var hit_stop: HitStop
var shake: FxShake
var ground_layer: Node2D
var fx_layer: Node2D
var popup_layer: Node2D
var screen_layer: CanvasLayer
var load_errors: Array = []
var _pools := {}
var _textures := {}
var _frames := {}
var _label_settings: LabelSettings
var _flash_material: CanvasItemMaterial
var _pending := {}
var _event_types := {}
var _last_flash_ms := -INF
var _last_popup_text := ""
var _last_effects: Array = []
var _connections: Array = []
var _built := false
var _shaking := false
var _camera_ref: WeakRef = null
var _splat_seq := 0


func _init() -> void:
	clock = _default_clock


func _default_clock() -> float:
	return float(Time.get_ticks_msec())


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	strengths = FxStrengths.from_balance(FxSettings.read_reduce(_settings_path()))
	var bus_script: Script = load(EVENT_BUS_SCRIPT)
	var parsed := FeedbackMap.parse(FEEDBACK_PATH, FeedbackMap.custom_signals(bus_script), strengths.sub("strengths"))
	map = parsed["map"]
	load_errors = parsed["errors"]
	for err in load_errors:
		push_error("FeedbackDirector: %s" % err)
	_build()
	_connect_bus()


func _enter_tree() -> void:
	if _built:
		_connect_bus()


func _exit_tree() -> void:
	_restore_time_scale()
	_apply_camera_offset(Vector2.ZERO)
	_disconnect_bus()


## Re-reads balance values and the reduce toggle (pools keep their size; caps need a new director).
func reload_config() -> void:
	strengths = FxStrengths.from_balance(FxSettings.read_reduce(_settings_path()))
	_label_settings.font_size = int(strengths.num("popup_font_size"))
	_label_settings.outline_size = int(strengths.num("popup_outline_size"))


func _settings_path() -> String:
	var data_dir := get_node_or_null("/root/DataDir")
	return String(data_dir.call("file", FxSettings.FILE)) if data_dir != null else ""


# --- Setup ------------------------------------------------------------------------------------------

func _build() -> void:
	ground_layer = _layer("GroundLayer", int(strengths.sub("z").get("splat", 0)))
	fx_layer = _layer("FxLayer", int(strengths.sub("z").get("fx", 0)))
	popup_layer = _layer("PopupLayer", int(strengths.sub("z").get("popup", 0)))
	screen_layer = CanvasLayer.new()
	screen_layer.name = "ScreenLayer"
	screen_layer.layer = int(strengths.num("screen_layer", 1.0))
	add_child(screen_layer)
	_label_settings = LabelSettings.new()
	_label_settings.font = FONT
	_label_settings.font_size = int(strengths.num("popup_font_size"))
	_label_settings.font_color = Color.WHITE
	_label_settings.outline_size = int(strengths.num("popup_outline_size"))
	_label_settings.outline_color = POPUP_OUTLINE
	_flash_material = CanvasItemMaterial.new()
	_flash_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_preload_textures()
	_pools["popup"] = FxPool.new("popup", strengths.cap("popup"), _make_popup)
	_pools["splat"] = FxPool.new("splat", strengths.cap("splat"), _make_sprite.bind(ground_layer, false))
	_pools["puff"] = FxPool.new("puff", strengths.cap("puff"), _make_sprite.bind(fx_layer, false))
	_pools["particles"] = FxPool.new("particles", strengths.cap("particles"), _make_particles)
	_pools["emote"] = FxPool.new("emote", strengths.cap("emote"), _make_sprite.bind(fx_layer, false))
	_pools["flash"] = FxPool.new("flash", strengths.cap("flash"), _make_sprite.bind(fx_layer, true))
	for type in COUNT_TYPES:
		_pools[type] = FxPool.new(type, strengths.cap(type), Callable())
	hit_stop = HitStop.new(strengths.num("hitstop_max_ms"), strengths.num("hitstop_cooldown_ms"),
			strengths.num("hitstop_safety_grace_ms"))
	shake = FxShake.new(strengths.cap("shake"), strengths.num("shake_decay_per_second"),
			strengths.num("shake_noise_speed"), int(strengths.num("shake_seed")))
	_built = true


func _layer(layer_name: String, z: int) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	layer.z_index = z
	layer.y_sort_enabled = false
	# Effects are animated in _process only, so they are not physics-interpolated.
	layer.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(layer)
	return layer


func _make_popup() -> Node:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.label_settings = _label_settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	popup_layer.add_child(label)
	return label


func _make_sprite(parent: Node, additive: bool) -> Node:
	var sprite := Sprite2D.new()
	sprite.visible = false
	if additive:
		sprite.material = _flash_material
	parent.add_child(sprite)
	return sprite


func _make_particles() -> Node:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.local_coords = false
	p.gravity = Vector2.ZERO
	p.direction = Vector2.UP
	p.material = _flash_material
	p.visible = false
	fx_layer.add_child(p)
	return p


func _preload_textures() -> void:
	for entry: Dictionary in map.all_entries():
		var asset := str(entry.get("asset", ""))
		if asset != "":
			_texture(asset)
		var pattern := str(entry.get("frames", ""))
		if pattern != "":
			_frame_list(pattern, int(entry.get("frame_count", 1)))


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


func _frame_list(pattern: String, count: int) -> Array:
	var key := "%s|%d" % [pattern, count]
	if not _frames.has(key):
		var list: Array = []
		for i in maxi(1, count):
			var tex := _texture(pattern % i)
			if tex != null:
				list.append(tex)
		_frames[key] = list
	return _frames[key]


func _connect_bus() -> void:
	if not _connections.is_empty():
		return
	var bus := get_node_or_null("/root/EventBus")
	if bus == null:
		return
	for s in bus.get_script().get_script_signal_list():
		var sig_name: String = s["name"]
		var argc: int = s["args"].size()
		var cb: Callable
		match argc:
			0:
				cb = func() -> void: _on_signal(sig_name, [])
			1:
				cb = func(a: Variant) -> void: _on_signal(sig_name, [a])
			2:
				cb = func(a: Variant, b: Variant) -> void: _on_signal(sig_name, [a, b])
			3:  # balance-exempt: argument count
				cb = func(a: Variant, b: Variant, c: Variant) -> void: _on_signal(sig_name, [a, b, c])
			MAX_SIGNAL_ARGS:
				cb = func(a: Variant, b: Variant, c: Variant, d: Variant) -> void: _on_signal(sig_name, [a, b, c, d])
			_:
				push_error("FeedbackDirector: signal %s has more than %d arguments" % [sig_name, MAX_SIGNAL_ARGS])
				continue
		bus.connect(sig_name, cb)
		_connections.append([sig_name, cb])


func _disconnect_bus() -> void:
	var bus := get_node_or_null("/root/EventBus")
	for c in _connections:
		if bus != null and bus.is_connected(c[0], c[1]):
			bus.disconnect(c[0], c[1])
	_connections.clear()


# --- Dispatch ---------------------------------------------------------------------------------------

func _on_signal(sig_name: String, args: Array) -> void:
	if not _built:
		return
	if ANCHOR_SIGNALS.has(sig_name):
		_pending = {"kind": str(args[0]), "value": args[1]}
		return
	if sig_name == "settings_changed":
		var key := str(args[0])
		if key == FxSettings.KEY or key == "":
			strengths.reduce = FxSettings.read_reduce(_settings_path())
	elif sig_name == "level_started":
		reset_all()
	elif sig_name == "event_warning":
		_event_types[str(args[0])] = str(args[1])
	if map.is_no_visual(sig_name):
		return
	var entries: Array = map.entries_for(sig_name, args).duplicate()
	var event_id := ""
	if sig_name == "event_warning":
		event_id = str(args[0])
		entries.append_array(map.event_entries(str(args[1]), "warning"))
	elif sig_name == "event_triggered":
		event_id = str(args[0])
		entries.append_array(map.event_entries(str(_event_types.get(event_id, "")), "start"))
	var ctx := _context(args, event_id)
	_pending = {}
	for entry: Dictionary in entries:
		_play(entry, ctx, sig_name)


func _context(args: Array, event_id: String) -> Dictionary:
	var ctx := {"has_pos": false, "pos": Vector2.ZERO, "node": null, "event_id": event_id}
	for a in args:
		if a is Vector2:
			ctx["has_pos"] = true
			ctx["pos"] = a
			break
	if not _pending.is_empty():
		var value: Variant = _pending["value"]
		if value is Node2D and is_instance_valid(value):
			ctx["node"] = value
			if not ctx["has_pos"]:
				ctx["has_pos"] = true
				ctx["pos"] = (value as Node2D).global_position
		elif value is Vector2 and not ctx["has_pos"]:
			ctx["has_pos"] = true
			ctx["pos"] = value
	return ctx


func _castaway() -> Node2D:
	return get_tree().get_first_node_in_group(CASTAWAY_GROUP) as Node2D if is_inside_tree() else null


func _screen_center() -> Vector2:
	return get_viewport().get_visible_rect().size / 2.0


## Returns {screen, pos, node} for an entry anchor.
func _resolve(anchor: String, ctx: Dictionary) -> Dictionary:
	if anchor == "screen":
		return {"screen": true, "pos": _screen_center(), "node": null}
	if anchor == "event_zone":
		for marker in get_tree().get_nodes_in_group(EVENT_ANCHOR_GROUP):
			if marker is Node2D and str(marker.get("event_id")) == str(ctx["event_id"]):
				return {"screen": false, "pos": (marker as Node2D).global_position, "node": marker}
		var head := _castaway()
		if head != null:
			return {"screen": false, "pos": head.global_position + strengths.vec("popup_face_offset"), "node": null}
	if anchor == "follow":
		var target: Node2D = ctx["node"] if ctx["node"] != null else _castaway()
		if target != null:
			return {"screen": false, "pos": target.global_position, "node": target}
	if ctx["has_pos"]:
		return {"screen": false, "pos": ctx["pos"], "node": ctx["node"]}
	var cast := _castaway()
	if cast != null:
		return {"screen": false, "pos": cast.global_position, "node": cast}
	return {"screen": true, "pos": _screen_center(), "node": null}


func _play(entry: Dictionary, ctx: Dictionary, sig_name: String) -> void:
	var effect := str(entry.get("effect", ""))
	var key := str(entry.get("strength", ""))
	match effect:
		"shake":
			if shake.add(strengths.base("shake", key, "trauma"), strengths.shake_amplitude(key)):
				_record("shake", Vector2.ZERO, sig_name, false)
		"hitstop":
			if request_hitstop(strengths.hitstop_ms(key)):
				_record("hitstop", Vector2.ZERO, sig_name, false)
		"squash", "recoil":
			_play_body(effect, key, ctx, sig_name)
		_:
			if VISUAL_TYPES.has(effect):
				_play_visual(effect, entry, key, _resolve(str(entry.get("anchor", "auto")), ctx), sig_name)


func _play_body(effect: String, key: String, ctx: Dictionary, sig_name: String) -> void:
	var target: Node2D = ctx["node"]
	if target == null or not is_instance_valid(target) or not target.has_method("fx_" + effect):
		return
	var pool: FxPool = _pools[effect]
	if pool.active_count() >= pool.size():
		return
	var seconds := strengths.base(effect, key, "seconds")
	if effect == "squash":
		var sx := strengths.effective("squash", key, "x")
		var sy := strengths.effective("squash", key, "y")
		if is_equal_approx(sx, 1.0) and is_equal_approx(sy, 1.0):
			return
		target.call("fx_squash", sx, sy, seconds)
	else:
		var px := strengths.effective("recoil", key, "px")
		if px <= 0.0:
			return
		target.call("fx_recoil", _recoil_dir(target) * px, seconds)
	var slot := pool.acquire()
	slot["duration"] = seconds
	_record(effect, target.global_position, sig_name, false)


func _recoil_dir(target: Node2D) -> Vector2:
	var cast := _castaway()
	if cast == null or cast == target:
		if target.has_method("get_facing"):
			return -Vector2.from_angle(float(target.call("get_facing")))
		return Vector2.UP
	var d := target.global_position - cast.global_position
	return d.normalized() if d != Vector2.ZERO else Vector2.UP


func _play_visual(effect: String, entry: Dictionary, key: String, at: Dictionary, sig_name: String) -> void:
	if effect == "flash":
		var now := float(clock.call())
		var alpha := strengths.flash_alpha(key)
		if alpha <= 0.0 or now - _last_flash_ms < strengths.num("flash_min_interval_ms"):
			return
		_last_flash_ms = now
	if effect == "particles" and roundi(strengths.effective("particles", key, "amount")) <= 0:
		return
	var pool: FxPool = _pools[effect]
	var slot := pool.acquire()
	var node: CanvasItem = slot["node"]
	var screen: bool = at["screen"]
	var pos: Vector2 = at["pos"]
	var offset: Variant = entry.get("offset", [])
	if offset is Array and offset.size() == 2:
		pos += Vector2(float(offset[0]), float(offset[1]))
	_place(node, effect, screen)
	slot["follow"] = null
	slot["screen"] = screen
	match effect:
		"popup":
			_start_popup(slot, entry, key, pos, screen)
		"splat":
			_start_splat(slot, entry, key, pos)
		"puff":
			_start_puff(slot, entry, key, pos)
		"particles":
			_start_particles(slot, entry, key, pos)
		"emote":
			_start_emote(slot, entry, key, pos, at, screen)
		"flash":
			_start_flash(slot, entry, key, pos)
	node.visible = true
	_record(effect, slot.get("origin", pos), sig_name, screen)


func _place(node: CanvasItem, effect: String, screen: bool) -> void:
	var parent: Node = screen_layer
	if not screen:
		parent = ground_layer if effect == "splat" else (popup_layer if effect == "popup" else fx_layer)
	if node.get_parent() != parent:
		node.reparent(parent, false)


func _start_popup(slot: Dictionary, entry: Dictionary, key: String, pos: Vector2, screen: bool) -> void:
	var label: Label = slot["node"]
	_last_popup_text = I18n.t(str(entry.get("word", "")))
	label.text = _last_popup_text
	label.reset_size()
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size / 2.0
	label.modulate = Color.WHITE
	var origin := pos + (strengths.vec("popup_screen_offset") if screen else strengths.vec("popup_face_offset"))
	slot["base_scale"] = strengths.effective("popup", key, "scale")
	slot["origin"] = _stacked(slot, origin, screen)
	slot["duration"] = strengths.num("popup_seconds")
	_update_popup(slot)


## Moves a new popup up while another active popup on the same layer is closer than popup_stack_radius and its
## line (popup_stack_px times the mean scale of both) overlaps, so words that pop at once stay readable.
func _stacked(slot: Dictionary, origin: Vector2, screen: bool) -> Vector2:
	var step := strengths.num("popup_stack_px")
	var radius := strengths.num("popup_stack_radius")
	if step <= 0.0 or radius <= 0.0:
		return origin
	var pool: FxPool = _pools["popup"]
	var own := float(slot["base_scale"])
	var out := origin
	for _i in pool.size():
		var moved := false
		for other in pool.active_slots():
			if is_same(other, slot) or not other.has("origin") or bool(other.get("screen", false)) != screen:
				continue
			var line := step * (own + float(other.get("base_scale", 1.0))) / 2.0
			var at: Vector2 = other.get("shown", other["origin"])
			if at.distance_to(out) < radius + line and absf(at.y - out.y) < line:
				out.y = at.y - line
				moved = true
		if not moved:
			break
	return out


func _start_splat(slot: Dictionary, entry: Dictionary, key: String, pos: Vector2) -> void:
	var sprite: Sprite2D = slot["node"]
	var frames := _frame_list(str(entry.get("frames", "")), int(entry.get("frame_count", 1)))
	_splat_seq += 1
	if not frames.is_empty():
		sprite.texture = frames[_splat_seq % frames.size()]
	sprite.rotation = float(_splat_seq) * GOLDEN_ANGLE
	var color := map.material_color(str(entry.get("material", "")))
	color.a = strengths.num("splat_alpha", 1.0)
	sprite.modulate = color
	sprite.position = pos
	sprite.scale = Vector2.ONE * strengths.num("splat_scale") * strengths.effective("splat", key, "scale")
	slot["origin"] = pos
	slot["alpha"] = color.a
	slot["duration"] = strengths.num("splat_seconds") + strengths.num("splat_fade_seconds")


func _start_puff(slot: Dictionary, entry: Dictionary, key: String, pos: Vector2) -> void:
	var sprite: Sprite2D = slot["node"]
	slot["frames"] = _frame_list(str(entry.get("frames", "")), int(entry.get("frame_count", 1)))
	sprite.position = pos
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE * strengths.num("puff_scale") * strengths.effective("puff", key, "scale")
	sprite.modulate = Color.WHITE
	slot["origin"] = pos
	slot["duration"] = strengths.num("puff_seconds")
	_update_frames(slot, 1.0)


func _start_particles(slot: Dictionary, entry: Dictionary, key: String, pos: Vector2) -> void:
	var p: CPUParticles2D = slot["node"]
	var tex := _texture(str(entry.get("asset", "")))
	p.texture = tex
	p.amount = maxi(1, roundi(strengths.effective("particles", key, "amount")))
	p.lifetime = maxf(strengths.base("particles", key, "lifetime"), strengths.num("particle_lifetime_margin"))
	p.spread = strengths.base("particles", key, "spread")
	var speed := strengths.base("particles", key, "speed")
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	var s := strengths.effective("particles", key, "scale")
	p.scale_amount_min = s * 0.5
	p.scale_amount_max = s
	var material := str(entry.get("material", ""))
	p.color = map.material_color(material) if material != "" else Color.WHITE
	p.position = pos
	slot["origin"] = pos
	slot["duration"] = p.lifetime + strengths.num("particle_lifetime_margin")
	p.restart()


func _start_emote(slot: Dictionary, entry: Dictionary, key: String, pos: Vector2, at: Dictionary,
		screen: bool) -> void:
	var sprite: Sprite2D = slot["node"]
	sprite.texture = _texture(str(entry.get("asset", "")))
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	if str(entry.get("anchor", "auto")) == "follow" and at["node"] != null and not screen:
		slot["follow"] = weakref(at["node"])
	slot["origin"] = pos + Vector2(0.0, -strengths.num("emote_height"))
	slot["base_scale"] = strengths.num("emote_scale") * strengths.effective("emote", key, "scale")
	slot["duration"] = strengths.num("emote_seconds")
	_update_emote(slot)


func _start_flash(slot: Dictionary, entry: Dictionary, key: String, pos: Vector2) -> void:
	var sprite: Sprite2D = slot["node"]
	slot["frames"] = _frame_list(str(entry.get("frames", "")), int(entry.get("frame_count", 1)))
	slot["alpha"] = strengths.flash_alpha(key)
	sprite.position = pos
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE * strengths.num("flash_scale")
	slot["origin"] = pos
	slot["duration"] = strengths.num("flash_seconds")
	_update_frames(slot, 1.0)


func _record(type: String, pos: Vector2, sig_name: String, screen: bool) -> void:
	_last_effects.append({"type": type, "position": pos, "signal": sig_name, "screen": screen})
	if _last_effects.size() > LAST_EFFECTS_SIZE:
		_last_effects.pop_front()


# --- Per-frame animation -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _built:
		return
	var paused := get_tree().paused
	if hit_stop.active and (paused or hit_stop.check(float(clock.call()))):
		_restore_time_scale()
	_pending = {}
	if paused:
		return
	for type in _pools:
		var pool: FxPool = _pools[type]
		for slot in pool.active_slots():
			slot["age"] = float(slot["age"]) + delta
			if slot["age"] >= slot["duration"]:
				pool.release(slot)
				continue
			match type:
				"popup":
					_update_popup(slot)
				"splat":
					_update_splat(slot)
				"puff":
					_update_frames(slot, 1.0 - pow(_share(slot), 2.0))
				"flash":
					_update_frames(slot, float(slot["alpha"]) * (1.0 - _share(slot)))
				"emote":
					_update_emote(slot)
	var offset := shake.tick(delta)
	if offset != Vector2.ZERO or _shaking:
		_apply_camera_offset(offset)
	_shaking = offset != Vector2.ZERO


func _share(slot: Dictionary) -> float:
	var duration := float(slot["duration"])
	return clampf(float(slot["age"]) / duration, 0.0, 1.0) if duration > 0.0 else 1.0


func _update_popup(slot: Dictionary) -> void:
	var label: Label = slot["node"]
	var share := _share(slot)
	var pop_seconds := strengths.num("popup_pop_seconds")
	var pop := 1.0
	if pop_seconds > 0.0 and float(slot["age"]) < pop_seconds:
		pop = lerpf(strengths.num("popup_pop_scale", 1.0), 1.0, float(slot["age"]) / pop_seconds)
	label.scale = Vector2.ONE * float(slot["base_scale"]) * pop
	var rise := strengths.num("popup_rise_px") * (1.0 - pow(1.0 - share, 2.0))
	slot["shown"] = (slot["origin"] as Vector2) + Vector2(0.0, -rise)
	label.position = slot["shown"] - label.size / 2.0
	label.modulate.a = 1.0 - maxf(0.0, share - 0.5) * 2.0


func _update_splat(slot: Dictionary) -> void:
	var sprite: Sprite2D = slot["node"]
	var hold := strengths.num("splat_seconds")
	var fade := strengths.num("splat_fade_seconds")
	var age := float(slot["age"])
	var share := clampf((age - hold) / fade, 0.0, 1.0) if fade > 0.0 else 0.0
	sprite.modulate.a = float(slot["alpha"]) * (1.0 - share)


func _update_frames(slot: Dictionary, alpha: float) -> void:
	var sprite: Sprite2D = slot["node"]
	var frames: Array = slot.get("frames", [])
	if not frames.is_empty():
		sprite.texture = frames[mini(frames.size() - 1, int(_share(slot) * frames.size()))]
	sprite.modulate.a = alpha


func _update_emote(slot: Dictionary) -> void:
	var sprite: Sprite2D = slot["node"]
	var ref: Variant = slot.get("follow")
	if ref is WeakRef:
		var target: Variant = (ref as WeakRef).get_ref()
		if target is Node2D and (target as Node2D).is_inside_tree():
			slot["origin"] = (target as Node2D).global_position + Vector2(0.0, -strengths.num("emote_height"))
	sprite.position = slot["origin"]
	var pop_seconds := strengths.num("emote_pop_seconds")
	var grow := clampf(float(slot["age"]) / pop_seconds, 0.0, 1.0) if pop_seconds > 0.0 else 1.0
	sprite.scale = Vector2.ONE * float(slot["base_scale"]) * lerpf(0.5, 1.0, grow)
	sprite.modulate.a = 1.0 - maxf(0.0, _share(slot) - 0.5) * 2.0


func _apply_camera_offset(offset: Vector2) -> void:
	var camera: Camera2D = null
	if is_inside_tree():
		camera = get_tree().get_first_node_in_group(CAMERA_GROUP) as Camera2D
	if camera == null and _camera_ref != null:
		camera = _camera_ref.get_ref() as Camera2D
	if camera == null:
		return
	_camera_ref = weakref(camera)
	camera.offset = offset


# --- Hit-stop --------------------------------------------------------------------------------------------

## Freezes the game for ms milliseconds via Engine.time_scale; returns true when the request was accepted.
func request_hitstop(ms: float) -> bool:
	if not is_inside_tree():
		return false
	var now := float(clock.call())
	var r := hit_stop.request(now, ms, get_tree().paused)
	if not r["accepted"]:
		return false
	if r["started"]:
		Engine.time_scale = strengths.num("hitstop_time_scale", 1.0)
	if r["rearm"]:
		var seconds := hit_stop.remaining_ms(now) / MS_PER_SECOND
		get_tree().create_timer(seconds, true, false, true).timeout.connect(_on_hitstop_timer.bind(r["generation"]))
	return true


func _on_hitstop_timer(gen: int) -> void:
	if hit_stop.timer_fired(gen):
		_restore_time_scale()


## The single restore path of Engine.time_scale.
func _restore_time_scale() -> void:
	if hit_stop != null:
		hit_stop.restore(float(clock.call()))
	Engine.time_scale = 1.0


# --- Public API ------------------------------------------------------------------------------------------

## Restores time, releases every effect and clears anchors and shake (level start and restart).
func reset_all() -> void:
	_restore_time_scale()
	hit_stop.reset()
	for type in _pools:
		(_pools[type] as FxPool).release_all()
	shake.clear()
	_apply_camera_offset(Vector2.ZERO)
	_shaking = false
	_pending = {}
	_event_types.clear()
	_last_flash_ms = -INF


func active_count(type: String) -> int:
	if type == "shake":
		return shake.active_count()
	if type == "hitstop":
		return 1 if hit_stop.active else 0
	return (_pools[type] as FxPool).active_count() if _pools.has(type) else 0


func pool_size(type: String) -> int:
	if type == "shake":
		return shake.cap
	return (_pools[type] as FxPool).size() if _pools.has(type) else 0


func played(type: String) -> int:
	return (_pools[type] as FxPool).played if _pools.has(type) else 0


func cap(type: String) -> int:
	return strengths.cap(type)


## Number of effect nodes below the four layers (constant after _ready).
func effect_layer_child_count() -> int:
	return ground_layer.get_child_count() + fx_layer.get_child_count() + popup_layer.get_child_count() \
			+ screen_layer.get_child_count()


func effective_shake_amplitude(key: String) -> float:
	return strengths.shake_amplitude(key)


func effective_flash_alpha(key: String) -> float:
	return strengths.flash_alpha(key)


func effective_hitstop_ms(key: String) -> float:
	return strengths.hitstop_ms(key)


func reduce_enabled() -> bool:
	return strengths.reduce


func hitstop_active() -> bool:
	return hit_stop.active


func hitstop_state() -> Dictionary:
	return hit_stop.state()


func last_popup_text() -> String:
	return _last_popup_text


## The most recent effects [{type, position, signal, screen}] (oldest first).
func last_effects() -> Array:
	return _last_effects.duplicate()


func clear_last_effects() -> void:
	_last_effects.clear()


## Active effect nodes of a type (for tests).
func active_nodes(type: String) -> Array:
	var out: Array = []
	if _pools.has(type):
		for slot in (_pools[type] as FxPool).active_slots():
			if slot["node"] != null:
				out.append(slot["node"])
	return out
