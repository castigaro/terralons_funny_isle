class_name RespawnPuff
extends Sprite2D
## A white smoke puff that plays the pack's whitePuff frames once and frees itself (respawn feedback).

const FRAME_PATTERN := "res://assets/graphics/smoke/PNG/White puff/whitePuff%02d.png"
const GROUP := "respawn_puff"

var cfg: EntityConfig
var _frames: Array[Texture2D] = []
var _time := 0.0


## Creates a puff at global position pos below parent.
static func spawn(parent: Node, pos: Vector2, config: EntityConfig) -> RespawnPuff:
	var puff := RespawnPuff.new()
	puff.cfg = config
	puff.name = "RespawnPuff"
	puff.top_level = true
	parent.add_child(puff)
	puff.global_position = pos
	return puff


func _ready() -> void:
	add_to_group(GROUP)
	for i in maxi(1, int(cfg.puff_frames)):
		var path := FRAME_PATTERN % i
		if ResourceLoader.exists(path):
			_frames.append(load(path))
	scale = Vector2.ONE * cfg.puff_scale
	z_index = 1
	texture = _frames[0] if not _frames.is_empty() else null


func _process(delta: float) -> void:
	_time += delta
	var share := _time / cfg.puff_seconds
	if share >= 1.0 or _frames.is_empty():
		queue_free()
		return
	texture = _frames[mini(_frames.size() - 1, int(share * _frames.size()))]
	modulate.a = 1.0 - share * share
