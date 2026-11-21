extends Node
## Feeds a decision callable into the real InputMap actions once per physics tick, before the castaway and the level
## read them: analog move per axis, dash and interact as one-tick press edges, finish as a parsed InputEventAction.
## The source returns {move: Vector2, dash: bool, interact: bool, finish: bool}; this is the bot's only path into the game.

const PRIORITY := -100
const FINISH_COOLDOWN_TICKS := 30
const AXES := [["move_right", "move_left"], ["move_down", "move_up"]]
const EDGE_ACTIONS := ["dash", "interact"]
const FINISH_ACTION := "finish"

var source: Callable
var pressed_counts := {"interact": 0, "dash": 0, "finish": 0}
var _down := {"dash": false, "interact": false}
var _finish_down := false
var _ticks_since_finish := FINISH_COOLDOWN_TICKS


func _ready() -> void:
	process_physics_priority = PRIORITY


func _physics_process(_delta: float) -> void:
	_ticks_since_finish += 1
	if _finish_down:
		_send_finish(false)
	if not source.is_valid():
		release_all()
		return
	var d: Dictionary = source.call()
	var move: Vector2 = d.get("move", Vector2.ZERO)
	_axis(AXES[0], move.x)
	_axis(AXES[1], move.y)
	for action in EDGE_ACTIONS:
		_edge(action, bool(d.get(action, false)))
	if bool(d.get("finish", false)) and _ticks_since_finish >= FINISH_COOLDOWN_TICKS:
		_send_finish(true)
		_ticks_since_finish = 0
		pressed_counts["finish"] += 1


func _axis(pair: Array, value: float) -> void:
	var positive: String = pair[0]
	var negative: String = pair[1]
	if value > 0.0:
		Input.action_press(positive, minf(value, 1.0))
		Input.action_release(negative)
	elif value < 0.0:
		Input.action_press(negative, minf(-value, 1.0))
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


func _edge(action: String, wanted: bool) -> void:
	if _down[action]:
		Input.action_release(action)
		_down[action] = false
		return
	if wanted:
		Input.action_press(action)
		_down[action] = true
		pressed_counts[action] += 1


func _send_finish(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = FINISH_ACTION
	event.pressed = pressed
	Input.parse_input_event(event)
	_finish_down = pressed


## Releases every action this node may have pressed.
func release_all() -> void:
	for pair in AXES:
		for action in pair:
			Input.action_release(action)
	for action in EDGE_ACTIONS:
		Input.action_release(action)
		_down[action] = false
	if _finish_down:
		_send_finish(false)


func _exit_tree() -> void:
	source = Callable()
	release_all()
