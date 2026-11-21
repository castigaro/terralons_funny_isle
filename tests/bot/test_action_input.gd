extends TestCase
## ActionInput drives the castaway of the sample level only through the InputMap actions: move, one interact edge
## per press, the finish action and a clean release.

const SAMPLE_LEVEL := "res://tests/scenes/sample_level.tscn"
const ActionInput := preload("res://tests/support/action_input.gd")
const MOVE_TICKS := 30
const FINISH_WAIT_TICKS := 10
const WALK_LIMIT_TICKS := 60 * 20
const ACTIONS := ["move_up", "move_down", "move_left", "move_right", "dash", "interact"]

var level: LevelBase
var castaway: Castaway
var input: Node
var want := {}


func _open(auto_finish: bool = true) -> void:
	if not auto_finish:
		Balance.set_override("rules", "auto_finish_when_all_done", false)
	level = (load(SAMPLE_LEVEL) as PackedScene).instantiate() as LevelBase
	add_node(level)
	castaway = level.castaway() as Castaway
	await physics_frames(2)
	input = ActionInput.new()
	input.source = func() -> Dictionary: return want
	add_node(input)


func test_move_action_moves_castaway() -> void:
	await _open()
	var start_x := castaway.global_position.x
	want = {"move": Vector2.RIGHT}
	await physics_frames(MOVE_TICKS)
	check(castaway.global_position.x > start_x + 50.0, "castaway walked right: %s" % str(castaway.global_position))


func test_one_interact_edge_grabs() -> void:
	await _open()
	var coconut := level.get_node("Actors/Coconut1") as Node2D
	var ticks := 0
	while castaway.global_position.distance_to(coconut.global_position) > castaway.cfg.grab_radius * 0.5 \
			and ticks < WALK_LIMIT_TICKS:
		want = {"move": (coconut.global_position - castaway.global_position).normalized()}
		await physics_frames(1)
		ticks += 1
	want = {}
	await physics_frames(2)
	check_eq(castaway.get_interact_verb(), CastawayLogic.VERB_GRAB, "grab offered")
	want = {"interact": true}
	await physics_frames(1)
	want = {}
	await physics_frames(2)
	check(castaway.get_carried() == coconut, "one interact edge grabbed the coconut")


func test_held_interact_yields_one_press_every_second_tick() -> void:
	await _open()
	want = {"interact": true}
	await physics_frames(3)
	want = {}
	check_eq(input.pressed_counts["interact"], 2, "3 wanted ticks press on ticks 1 and 3")
	await physics_frames(1)
	check_false(Input.is_action_pressed("interact"), "released after the edge")


func test_finish_action_wins_after_required_done() -> void:
	await _open(false)
	var zone_center := level.zone("zone_a").global_position
	var session := level.level_session()
	var ticks := 0
	while session.get_state() == LevelSession.State.RUNNING and ticks < WALK_LIMIT_TICKS:
		want = {"move": (zone_center - castaway.global_position).normalized()}
		await physics_frames(1)
		ticks += 1
	want = {}
	check_eq(session.get_state(), LevelSession.State.REQUIRED_DONE, "required task done, auto-finish off")
	await physics_frames(FINISH_WAIT_TICKS)
	check_eq(session.get_state(), LevelSession.State.REQUIRED_DONE, "no win without the finish action")
	want = {"finish": true}
	ticks = 0
	while session.get_state() != LevelSession.State.WON and ticks < FINISH_WAIT_TICKS:
		await physics_frames(1)
		ticks += 1
	want = {}
	check_eq(session.get_state(), LevelSession.State.WON, "finish action won the level")
	check_eq(input.pressed_counts["finish"], 1, "one finish press")


func test_release_all_releases_every_action() -> void:
	await _open()
	want = {"move": Vector2(1, 1).normalized(), "dash": true, "interact": true}
	await physics_frames(1)
	input.release_all()
	for action in ACTIONS:
		check_false(Input.is_action_pressed(action), "%s released" % action)
