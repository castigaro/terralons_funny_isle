class_name BackdropCritter
extends Node2D
## Decorative menu animal: the shared AnimalBrain wanders and idles around its start point, a LandRect keeps it on
## its patch of land, and the sprite flips and hops while walking. No body, no group, no EventBus signal, no sound.
## The hop is off while the reduce-motion setting is on (walking stays). See docs/flow.md "Menu backdrop".

## Animal kind from data/animals.json (a non-swimmer).
@export var kind := "chicken"
@export var seed_value := 1
## Land area in local units of the backdrop scene; the critter never leaves it.
@export var land := Rect2()

## Why the critter cannot show (unknown kind or missing sprite); "" when it is fine.
var error := ""
var reduce_motion := false
var brain: AnimalBrain = null
var sprite: Sprite2D = null
var _land: LandRect
var _walk_time := 0.0
var _hop_hz := 0.0
var _hop_px := 0.0
var _walk_min_speed := 0.0


func _ready() -> void:
	var cfg := Balance.get_section("flow")
	_hop_hz = float(cfg.get("backdrop_hop_hz", 0.0))
	_hop_px = float(cfg.get("backdrop_hop_px", 0.0))
	_walk_min_speed = float(cfg.get("backdrop_walk_min_speed", 0.0))
	_land = LandRect.new(land)
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	add_child(sprite)
	var def := EntityDefs.get_animal(kind)
	var path := String(def.get("sprite", ""))
	if def.is_empty():
		error = "unknown animal kind %s" % kind
	elif path == "" or not ResourceLoader.exists(path):
		error = "missing sprite for %s" % kind
	if error != "":
		set_process(false)
		return
	sprite.texture = load(path)
	sprite.scale = Vector2.ONE * float(def.get("sprite_scale", 1.0)) * float(cfg.get("backdrop_critter_scale", 1.0))
	position = _land.clamp_point(position)
	brain = AnimalBrain.new(def, EntityConfig.from_balance(), SeededRng.new(seed_value), position)
	reduce_motion = bool(Settings.get_value(SettingsModel.KEY_REDUCE))
	EventBus.settings_changed.connect(_on_settings_changed)


func _process(delta: float) -> void:
	step(delta)


## One tick: brain intent, move inside the land rect, flip and hop. Tests call it with a fixed delta.
func step(delta: float) -> void:
	if brain == null or delta <= 0.0:
		return
	var intent := brain.tick(delta, {"pos": position})
	var velocity: Vector2 = intent["velocity"]
	position = _land.clamp_point(position + velocity * delta)
	sprite.flip_h = float(intent["facing_x"]) < 0.0
	if velocity.length() > _walk_min_speed and not reduce_motion:
		_walk_time += delta
		sprite.position.y = -absf(sin(_walk_time * TAU * _hop_hz)) * _hop_px
	else:
		sprite.position.y = 0.0


func state_name() -> String:
	return brain.get_state_name() if brain != null else ""


func hop_height() -> float:
	return -sprite.position.y if sprite != null else 0.0


func _on_settings_changed(key: String) -> void:
	if key == SettingsModel.KEY_REDUCE:
		reduce_motion = bool(Settings.get_value(SettingsModel.KEY_REDUCE))
