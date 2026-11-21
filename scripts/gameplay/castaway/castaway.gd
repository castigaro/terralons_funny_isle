class_name Castaway
extends CharacterBody2D
## Scene shell of the castaway: reads input in the physics frame, runs CastawayLogic, moves the body, carries out
## grab/use/throw on the contract nodes and reports everything on the EventBus. No health exists: a hit only
## knocks the castaway back and makes it dizzy for a moment.

## Emitted when a hit was accepted (hook for the BONK popup).
signal bonked(cause: String)

## Group used by animals and the entity registry to find the castaway.
const GROUP := "castaway"

var last_safe_position := Vector2.ZERO
var cfg: CastawayConfig
var _logic: CastawayLogic
var _world: CastawayWorld
var _input_source: Callable
var _last_verb := CastawayLogic.VERB_NONE
var _last_verb_kind := ""
var _step_time := 0.0
var _anim_time := 0.0
var _shadow_base := Vector2.ONE

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var shadow: Sprite2D = $Shadow
@onready var visual: CastawayVisual = $Visual
@onready var hold_point: Marker2D = $Visual/HoldPoint
@onready var stars: Node2D = $Stars
@onready var dust: CPUParticles2D = $DustEmitter


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = PhysicsLayers.CASTAWAY
	collision_mask = PhysicsLayers.CASTAWAY_MASK
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_shadow_base = shadow.scale
	if _world == null:
		_world = SceneCastawayWorld.new(self)
	apply_config(CastawayConfig.from_balance())
	last_safe_position = global_position


## Applies tuning values (from Balance by default; tests may inject their own).
func apply_config(config: CastawayConfig) -> void:
	cfg = config
	var facing := _logic.facing_angle if _logic != null else 0.0
	_logic = CastawayLogic.new(cfg)
	_logic.facing_angle = facing
	var circle := CircleShape2D.new()
	circle.radius = cfg.body_radius
	collision.shape = circle
	shadow.scale = _shadow_base * cfg.shadow_scale
	visual.setup(cfg)
	_build_stars()
	dust.amount = maxi(1, int(cfg.dust_amount))
	stars.position = Vector2(0.0, -cfg.star_height)
	stars.visible = false


## Replaces the input reader; the callable returns a CastawayInput (used by tests and bots).
func set_input_source(source: Callable) -> void:
	_input_source = source


func set_world(world: CastawayWorld) -> void:
	_world = world


func get_logic() -> CastawayLogic:
	return _logic


func get_interact_verb() -> String:
	return _logic.get_interact_verb()


func get_interact_target_kind() -> String:
	return _logic.get_interact_target_kind()


func get_pose() -> String:
	return _logic.get_pose()


func get_carried() -> Node2D:
	return _logic.carried as Node2D


func is_dizzy() -> bool:
	return _logic.is_dizzy()


func get_facing() -> float:
	return _logic.facing_angle


## A hit by a coconut, a stampede or a collision; from_direction is where the castaway gets pushed.
## Drops a carried thing at the castaway's feet. Returns false while dizzy or immune.
func bonk(cause: String, from_direction: Vector2) -> bool:
	var result := _logic.bonk(from_direction)
	if not result["accepted"]:
		return false
	var dropped: Object = result["dropped"]
	if dropped != null and is_instance_valid(dropped):
		if dropped is Node2D:
			dropped.global_position = global_position
		if dropped.has_method("on_released"):
			dropped.call("on_released")
	stars.visible = true
	_emit_verb()
	bonked.emit(cause)
	EventBus.fx_anchor_node.emit(GROUP, self)
	EventBus.object_bonked.emit("castaway", cause)
	EventBus.castaway_dizzy_started.emit(cause)
	return true


## Drops the carried thing at the castaway's feet without a bonk (an event snatched it); returns it or null.
func drop_carried() -> Node2D:
	var dropped: Object = _logic.release_carried()
	if dropped == null or not is_instance_valid(dropped):
		return null
	if dropped is Node2D:
		dropped.global_position = global_position
	if dropped.has_method("on_released"):
		dropped.call("on_released")
	_emit_verb()
	return dropped as Node2D


## Puts the castaway back to a spawn point with every state cleared (level start and instant restart).
func reset_to(spawn_position: Vector2, facing: float) -> void:
	var held: Object = _logic.carried
	if held != null and is_instance_valid(held) and held.has_method("on_released"):
		held.call("on_released")
	_logic.reset_to(facing)
	velocity = Vector2.ZERO
	global_position = spawn_position
	last_safe_position = spawn_position
	_step_time = 0.0
	_last_verb = CastawayLogic.VERB_NONE
	_last_verb_kind = ""
	visual.reset_look(facing)
	stars.visible = false
	dust.emitting = false
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var input: CastawayInput = _input_source.call() if _input_source.is_valid() else CastawayInput.from_input()
	var step := _logic.step(input, delta, global_position, _world)
	velocity = step.velocity
	if step.mode == CastawayStep.MODE_WALK:
		move_and_slide()
		_logic.set_walk_velocity(velocity)
	elif velocity != Vector2.ZERO:
		if move_and_collide(velocity * delta) != null:
			_logic.stop_motion()
			velocity = Vector2.ZERO
	_safety_net()
	if step.dash_started:
		visual.play_dash()
		dust.restart()
		EventBus.castaway_dashed.emit(global_position, step.dash_direction)
	_carry_out(step)
	if step.dizzy_ended:
		stars.visible = false
		EventBus.castaway_dizzy_ended.emit()
	_emit_steps(step, delta)
	_animate(delta)
	_follow_hold_point()
	_emit_verb()


func _carry_out(step: CastawayStep) -> void:
	match step.intent:
		CastawayLogic.VERB_GRAB:
			var thing: Node2D = step.intent_target
			thing.call("on_grabbed", self)
			EventBus.fx_anchor_node.emit(_kind_of(thing), thing)
			EventBus.object_grabbed.emit(_kind_of(thing))
		CastawayLogic.VERB_USE:
			var used: Node2D = step.intent_object
			var target: Object = step.intent_target
			used.call("on_released")
			target.call("use", used)
			if target is Node2D:
				EventBus.fx_anchor_node.emit(String(target.get("target_kind")), target)
			EventBus.object_used.emit(_kind_of(used), String(target.get("target_kind")))
		CastawayLogic.VERB_THROW:
			var thrown: Node2D = step.intent_object
			ThrowFlight.launch(thrown, thrown.global_position, step.throw_destination, cfg, global_position)
			visual.play_throw()
			EventBus.fx_anchor_node.emit(GROUP, self)
			EventBus.object_thrown.emit(_kind_of(thrown))


func _follow_hold_point() -> void:
	var held := get_carried()
	if held != null and is_instance_valid(held):
		held.global_position = hold_point.global_position


func _safety_net() -> void:
	if collision.shape == null or not is_inside_tree():
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	if get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		last_safe_position = global_position
	else:
		global_position = last_safe_position
		velocity = Vector2.ZERO
		_logic.stop_motion()
		reset_physics_interpolation()


func _emit_steps(step: CastawayStep, delta: float) -> void:
	if step.mode != CastawayStep.MODE_WALK or velocity == Vector2.ZERO:
		_step_time = 0.0
		return
	_step_time += delta
	if _step_time >= cfg.step_interval:
		_step_time -= cfg.step_interval
		EventBus.castaway_step.emit(global_position, _world.surface_at(global_position))


func _animate(delta: float) -> void:
	_anim_time += delta
	visual.apply_pose(_logic.get_pose(), velocity, _logic.facing_angle, delta)
	if stars.visible:
		var count := stars.get_child_count()
		for i in count:
			var star := stars.get_child(i) as Node2D
			var angle := _anim_time * cfg.star_orbit_speed + TAU * float(i) / float(count)
			star.position = Vector2(cos(angle), sin(angle) / 2.0) * cfg.star_orbit_radius
			star.rotation = angle


func _emit_verb() -> void:
	var verb := _logic.get_interact_verb()
	var kind := _logic.get_interact_target_kind()
	if verb == _last_verb and kind == _last_verb_kind:
		return
	_last_verb = verb
	_last_verb_kind = kind
	EventBus.interact_verb_changed.emit(verb, kind)


func _build_stars() -> void:
	var template := stars.get_child(0) as Sprite2D
	while stars.get_child_count() > 1:
		var extra := stars.get_child(stars.get_child_count() - 1)
		stars.remove_child(extra)
		extra.free()
	template.scale = Vector2.ONE * cfg.star_scale
	for i in range(1, maxi(1, int(cfg.star_count))):
		var star := template.duplicate() as Sprite2D
		star.name = "Star%d" % (i + 1)
		stars.add_child(star)


## Feedback hook (duck-typed FeedbackDirector contract): a short squash and stretch of the castaway sprite.
func fx_squash(sx: float, sy: float, seconds: float) -> void:
	visual.fx_squash(sx, sy, seconds)


## Feedback hook: a short visual recoil of the sprite by a world-space offset (gameplay knockback is separate).
func fx_recoil(offset: Vector2, seconds: float) -> void:
	visual.fx_recoil(offset, seconds)


func _kind_of(obj: Object) -> String:
	return String(obj.get("kind")) if obj != null and "kind" in obj else ""
