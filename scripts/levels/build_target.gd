class_name BuildTarget
extends DeliveryTarget
## Delivery target that grows with every delivery (a sandcastle built from sand pails): its Art sprite shows the
## stage frame that matches the session progress of every delivered_to task naming this target kind, and the
## flattened frame once such a task is missed (for example a wave came first). It stops taking deliveries when the
## build is finished. The stage is presentation only: progress always comes from the session, never from task ids.

const FLATTEN_FX := "sand"

## Frames from empty to finished; the frame index follows current * (frames - 1) / target.
@export var stage_frames: Array[Texture2D] = []
## Frame shown while a matching task is missed and not done.
@export var flattened_frame: Texture2D

var _frame := 0
var _flattened := false


func _ready() -> void:
	super._ready()
	for pair in _signals():
		var sig: Signal = pair[0]
		sig.connect(pair[1])
	_show()


func _exit_tree() -> void:
	for pair in _signals():
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


func _signals() -> Array:
	return [[EventBus.task_progress, _on_task_progress], [EventBus.task_completed, _on_task_completed],
			[EventBus.event_triggered, _on_event_triggered], [EventBus.level_restarted, _on_level_restarted]]


func _on_task_progress(_level_id: String, _task_id: String, _current: int, _target: int) -> void:
	refresh.call_deferred()


func _on_task_completed(_level_id: String, _task_id: String) -> void:
	refresh.call_deferred()


func _on_event_triggered(_event_id: String) -> void:
	refresh.call_deferred()


func _on_level_restarted(_level_id: String) -> void:
	_frame = 0
	_flattened = false
	_show()


## Session progress entries of the tasks with a delivered_to condition for this target kind.
func matching_progress() -> Array:
	var lvl := level()
	if lvl == null or lvl.level_session() == null or lvl.level_def() == null:
		return []
	var ids := {}
	for task in lvl.level_def().tasks:
		for cond in task["conditions"]:
			if String(cond.get("type", "")) == "delivered_to" and String(cond.get("target", "")) == target_kind:
				ids[String(task["id"])] = true
	return lvl.level_session().task_progress().filter(func(e: Dictionary) -> bool: return ids.has(String(e["id"])))


## Recomputes the stage from the session and updates the Art sprite.
func refresh() -> void:
	if not is_inside_tree():
		return
	var stages := stage_frames.size()
	var frame := 0
	var flattened := false
	for entry in matching_progress():
		if bool(entry["missed"]) and not bool(entry["done"]):
			flattened = true
		var target := maxi(1, int(entry["target"]))
		frame = maxi(frame, mini(int(entry["current"]) * (stages - 1) / target, stages - 1))
	if flattened and not _flattened:
		EventBus.fx_anchor.emit(FLATTEN_FX, global_position)
	_frame = maxi(0, frame)
	_flattened = flattened
	_show()


func _show() -> void:
	var art := get_node_or_null("Art") as Sprite2D
	if art == null:
		return
	if _flattened and flattened_frame != null:
		art.texture = flattened_frame
	elif _frame < stage_frames.size():
		art.texture = stage_frames[_frame]


func is_finished() -> bool:
	var entries := matching_progress()
	return not entries.is_empty() and entries.all(func(e: Dictionary) -> bool: return bool(e["done"]))


func is_flattened() -> bool:
	return _flattened


func current_frame() -> int:
	return _frame


func accepts(obj: Object) -> bool:
	return super.accepts(obj) and not is_finished()
