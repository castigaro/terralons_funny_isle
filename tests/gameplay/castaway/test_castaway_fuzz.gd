extends TestCase
## Randomised input fuzz (seeded): 5 seeds x 1000 ticks of moves, dash and interact presses and bonks against a
## stub world; timers stay bounded, at most one object is carried, the castaway never ends up inside a blocker
## and once the dizzy time is over input always has an effect again.

const H := preload("res://tests/support/castaway_helpers.gd")
const SEEDS := [11, 2024, 31337, 4242, 987654]
const STEPS := 1000
const EPS := 0.001


func _world() -> CastawayWorld:
	var w = H.world()
	w.bounds = Rect2(0, 0, 1600, 900)
	w.solids = [Rect2(900, 350, 200, 200), Rect2(300, 100, 80, 80)]
	w.waters = [Rect2(0, 750, 1600, 150)]
	w.grass = [Rect2(100, 100, 300, 200)]
	for i in 6:
		w.items.append(H.StubThing.item("coconut" if i % 2 == 0 else "hat", Vector2(200 + i * 220, 300 + (i % 3) * 120)))
	w.targets = [H.StubThing.target("goat", Vector2(1300, 600), ["hat"]),
			H.StubThing.target("cage", Vector2(600, 650), ["coconut"])]
	return w


func _check_invariants(l: CastawayLogic, w: CastawayWorld, pos: Vector2, tag: String) -> void:
	var cfg := l.cfg
	check(l.dash_left <= cfg.dash_duration + EPS, "%s dash_left %f" % [tag, l.dash_left])
	check(l.cooldown_left <= cfg.dash_cooldown + EPS, "%s cooldown %f" % [tag, l.cooldown_left])
	check(l.throw_pose_left <= cfg.throw_pose_seconds + EPS, "%s throw pose %f" % [tag, l.throw_pose_left])
	check(l.dizzy_left <= cfg.dizzy_seconds + EPS, "%s dizzy %f" % [tag, l.dizzy_left])
	check(l.immunity_left <= cfg.dizzy_immunity_seconds + EPS, "%s immunity %f" % [tag, l.immunity_left])
	check(l.knock_left <= cfg.knockback_duration + EPS, "%s knock %f" % [tag, l.knock_left])
	var max_speed := maxf(cfg.dash_speed(), cfg.knockback_speed()) + EPS
	check(l.velocity.length() <= max_speed, "%s speed %f" % [tag, l.velocity.length()])
	check_false(w.is_blocked(pos, cfg.body_radius), "%s inside a blocker at %s" % [tag, str(pos)])


func _run_seed(seed_value: int) -> void:
	var rng := SeededRng.new(seed_value)
	var w := _world()
	var l := H.logic(0.0)
	var pos := Vector2(500, 450)
	var carried_count := 0
	for i in STEPS:
		var tag := "seed %d step %d" % [seed_value, i]
		var move := Vector2.ZERO
		if rng.randf() < 0.8:
			move = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			if rng.randf() < 0.5:
				move = move.sign()
		var dash := rng.randf() < 0.05
		var interact := rng.randf() < 0.08
		if rng.randf() < 0.01:
			l.bonk(Vector2.from_angle(rng.randf_range(-PI, PI)))
		var before_carried := l.carried
		var step := l.step(CastawayInput.make(move, dash, interact), H.DT, pos, w)
		if step.intent == CastawayLogic.VERB_GRAB:
			check(before_carried == null, "%s grabbed while carrying" % tag)
		if step.intent == CastawayLogic.VERB_THROW or step.intent == CastawayLogic.VERB_USE:
			step.intent_object.global_position = step.throw_destination if step.intent == CastawayLogic.VERB_THROW \
					else step.intent_target.global_position
		var old_pos := pos
		var moved: Array = w.move(pos, step.velocity * H.DT, l.cfg.body_radius, step.mode == CastawayStep.MODE_WALK)
		pos = moved[0]
		if moved[1]:
			if step.mode == CastawayStep.MODE_BURST:
				l.stop_motion()
			else:
				l.set_walk_velocity((pos - old_pos) / H.DT)
		if l.carried != null:
			l.carried.global_position = pos
		carried_count = 1 if l.carried != null else 0
		check(carried_count <= 1, "%s carry slot" % tag)
		_check_invariants(l, w, pos, tag)
		if not failures.is_empty():
			return
	_check_recovers(l, w, pos, seed_value)


## After the dizzy time plus one tick a move input changes the velocity and some direction moves the castaway.
func _check_recovers(l: CastawayLogic, w: CastawayWorld, pos: Vector2, seed_value: int) -> void:
	l.bonk(Vector2.ZERO)
	for i in H.ticks_for(l.cfg.dizzy_seconds) + 1:
		var step := l.step(CastawayInput.make(), H.DT, pos, w)
		var moved: Array = w.move(pos, step.velocity * H.DT, l.cfg.body_radius, step.mode == CastawayStep.MODE_WALK)
		pos = moved[0]
		if moved[1] and step.mode == CastawayStep.MODE_BURST:
			l.stop_motion()
	check_false(l.is_dizzy(), "seed %d still dizzy" % seed_value)
	var any_moved := false
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var probe := CastawayLogic.new(l.cfg)
		probe.facing_angle = l.facing_angle
		probe.carried = l.carried
		var step := probe.step(CastawayInput.make(dir), H.DT, pos, w)
		check(step.velocity.dot(dir) > 0.0, "seed %d: input %s has no effect" % [seed_value, str(dir)])
		var moved: Array = w.move(pos, step.velocity * H.DT, l.cfg.body_radius, true)
		any_moved = any_moved or moved[0] != pos
	var step_real := l.step(CastawayInput.make(Vector2.RIGHT), H.DT, pos, w)
	check(step_real.velocity.x > 0.0, "seed %d: real logic ignores input after dizzy" % seed_value)
	check(any_moved, "seed %d: stuck at %s" % [seed_value, str(pos)])


func test_fuzz_seed_0() -> void:
	_run_seed(SEEDS[0])


func test_fuzz_seed_1() -> void:
	_run_seed(SEEDS[1])


func test_fuzz_seed_2() -> void:
	_run_seed(SEEDS[2])


func test_fuzz_seed_3() -> void:
	_run_seed(SEEDS[3])


func test_fuzz_seed_4() -> void:
	_run_seed(SEEDS[4])
