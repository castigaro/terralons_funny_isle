extends Node2D
## Feedback arena (tests only, also runnable windowed): the entity arena with a few animals and items, a Camera2D in
## group game_camera, an event_anchor marker and a FeedbackDirector. It fires every mapped EventBus signal in
## sequence (one step every STEP_FRAMES frames, anchored on the real castaway and animals) and ends with a burst of
## BURST back-to-back bonks. When done it prints "FX ARENA OK" if every step played an effect and the time scale is
## back to 1.0 after the last freeze ("FX ARENA FAILED ..." otherwise) and quits with -- --quit-when-done.
## Windowed: Godot_v4.7.2-stable_win64.exe --path . res://tests/scenes/fx_arena.tscn -- --quit-when-done
## [--fx-shot=<png path>] saves a screenshot every SHOT_EVERY steps (the step number is appended).

signal finished(ok: bool)

const ENTITY_ARENA := preload("res://tests/scenes/entity_arena.tscn")
const STEP_FRAMES := 12
const BURST := 20
const SETTLE_FRAMES := 40
## Upper bound for the wait until the last hit-stop has ended (uncapped windowed runs can be very fast).
const SETTLE_MAX_FRAMES := 2000
const SHOT_EVERY := 6
const ANIMALS := ["chicken", "goat", "pig", "monkey"]
const ITEMS := ["coconut", "bucket"]
const EVENT_MARKER_ID := "fx_event"


class EventMarker extends Node2D:
	var event_id := ""


var arena: Node2D
var director: FeedbackDirector
var camera: Camera2D
var marker: Node2D
var steps: Array = []
## Step label -> number of effects it played.
var results := {}
var done := false
var ok := false
var _frame := 0
var _step := 0
var _settle := 0
var _shot := ""
var _quit := false


func _ready() -> void:
	var args := CliArgs.current()
	_shot = str(args.get("fx-shot", ""))
	_quit = args.has("quit-when-done")
	arena = ENTITY_ARENA.instantiate()
	arena.animal_kinds = ANIMALS
	arena.item_kinds = ITEMS
	arena.castaway_input = func() -> CastawayInput: return CastawayInput.make(Vector2.ZERO, false, false)
	add_child(arena)
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.add_to_group(FeedbackDirector.CAMERA_GROUP)
	camera.position = arena.AREA.get_center()
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x / arena.AREA.size.x, view.y / arena.AREA.size.y)
	camera.zoom = Vector2.ONE * fit
	add_child(camera)
	camera.make_current()
	marker = EventMarker.new()
	marker.name = "EventMarker"
	marker.event_id = EVENT_MARKER_ID
	marker.position = Vector2(1100, 420)
	marker.add_to_group(FeedbackDirector.EVENT_ANCHOR_GROUP)
	add_child(marker)
	director = FeedbackDirector.new()
	director.name = "FeedbackDirector"
	arena.add_child(director)
	arena.move_child(director, _first_actor_index())
	_build_steps()


## The director goes after the floor and before the first actor, so splats lie on the ground below the actors.
func _first_actor_index() -> int:
	for child in arena.get_children():
		if child is Animal or child is Item or child is Castaway:
			return child.get_index()
	return arena.get_child_count() - 1


func _bus() -> Node:
	return get_node("/root/EventBus")


func _emit(sig_name: String, args: Array) -> void:
	_bus().callv("emit_signal", [sig_name] + args)


func _anchored(node: Node2D, sig_name: String, args: Array) -> Callable:
	return func() -> void:
		_emit("fx_anchor_node", [str(node.get("kind")) if "kind" in node else "castaway", node])
		_emit(sig_name, args)


func _plain(sig_name: String, args: Array) -> Callable:
	return func() -> void: _emit(sig_name, args)


func _add(label: String, action: Callable) -> void:
	steps.append([label, action])


func _build_steps() -> void:
	var cast: Node2D = arena.castaway
	var animals: Dictionary = arena.animals
	var items: Dictionary = arena.items
	var c := cast.global_position
	_add("level_started", _plain("level_started", ["fx_arena"]))
	for surface in ["sand", "grass", "water"]:
		_add("castaway_step:" + surface, _plain("castaway_step", [c, surface]))
	_add("castaway_dashed", _plain("castaway_dashed", [c, Vector2.RIGHT]))
	_add("object_grabbed", _anchored(items["coconut"], "object_grabbed", ["coconut"]))
	_add("object_thrown", _anchored(cast, "object_thrown", ["coconut"]))
	var spots := {"water": Vector2(300, 820), "sand": Vector2(500, 420), "mud": Vector2(700, 600),
		"grass": Vector2(1300, 600)}
	for surface in spots:
		_add("object_landed:" + surface, _plain("object_landed", ["coconut", spots[surface], surface]))
	_add("object_used", _anchored(items["bucket"], "object_used", ["bucket", "sandcastle"]))
	_add("object_bonked", _anchored(cast, "object_bonked", ["castaway", "coconut"]))
	_add("castaway_dizzy_started", _anchored(cast, "castaway_dizzy_started", ["coconut"]))
	_add("animal_fled", _anchored(animals["chicken"], "animal_fled", ["chicken"]))
	_add("animal_panicked", _anchored(animals["chicken"], "animal_panicked", ["chicken"]))
	_add("animal_lured", _anchored(animals["monkey"], "animal_lured", ["monkey"]))
	_add("animal_caught", _anchored(animals["pig"], "animal_caught", ["pig"]))
	_add("animal_bonked", _anchored(animals["goat"], "animal_bonked", ["goat", "coconut"]))
	_add("entity_lost", func() -> void:
		_emit("fx_anchor", ["coconut", Vector2(200, 850)])
		_emit("entity_lost", ["coconut", "water"]))
	_add("entity_respawned", _plain("entity_respawned", ["coconut", items["coconut"].global_position]))
	_add("task_completed", _plain("task_completed", ["fx_arena", "t_one"]))
	_add("all_required_done", _plain("all_required_done", ["fx_arena"]))
	_add("timer_warning", _plain("timer_warning", ["fx_arena", 10.0]))
	for type in director.map.events:
		_add("event_warning:" + type, _plain("event_warning", [EVENT_MARKER_ID, type, 2.0]))
		_add("event_triggered:" + type, _plain("event_triggered", [EVENT_MARKER_ID]))
	_add("level_won", _plain("level_won", ["fx_arena", 3]))
	_add("level_lost", _plain("level_lost", ["fx_arena", ["t_two"]]))
	_add("bonk_burst", func() -> void:
		for i in BURST:
			_emit("fx_anchor_node", ["castaway", cast])
			_emit("object_bonked", ["castaway", "coconut"]))


func _process(_delta: float) -> void:
	if done or director == null or not director.is_inside_tree():
		return
	_frame += 1
	if _step < steps.size():
		if _frame % STEP_FRAMES != 0:
			return
		var label: String = steps[_step][0]
		director.clear_last_effects()
		(steps[_step][1] as Callable).call()
		var sig_name := label.get_slice(":", 0)
		var count := 0
		for e in director.last_effects():
			if e["signal"] == sig_name or (label == "bonk_burst" and e["signal"] == "object_bonked"):
				count += 1
		results[label] = count
		if _shot != "" and _step % SHOT_EVERY == SHOT_EVERY - 1:
			_save_shot(_step)
		_step += 1
		return
	_settle += 1
	if _settle < SETTLE_FRAMES or (director.hitstop_active() and _settle < SETTLE_MAX_FRAMES):
		return
	_finish()


func _finish() -> void:
	done = true
	var missing: Array = []
	for label in results:
		if results[label] <= 0:
			missing.append(label)
	ok = missing.is_empty() and Engine.time_scale == 1.0 and results.size() == steps.size()
	if ok:
		print("FX ARENA OK steps=%d" % steps.size())
	else:
		print("FX ARENA FAILED missing=%s time_scale=%.2f" % [str(missing), Engine.time_scale])
	finished.emit(ok)
	if _quit:
		get_tree().quit(0 if ok else 1)


func _save_shot(step: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var image := tex.get_image()
	if image != null and not image.is_empty():
		image.save_png(_shot.replace(".png", "_%02d.png" % step))
