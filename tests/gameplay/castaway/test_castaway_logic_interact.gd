extends TestCase
## Pure castaway interact: grab cone and touch fallback, tie-break, use, throw, aim snap, no target, throw pose.

const H := preload("res://tests/support/castaway_helpers.gd")


func _at(angle_deg: float, dist: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(angle_deg)) * dist


func test_grab_in_half_angle_cone() -> void:
	var l := H.logic(0.0)
	check_eq(l.cfg.grab_cone_degrees, 75.0, "test assumes the default cone")
	var w = H.world()
	var inside = H.StubThing.item("coconut", _at(70, 80))
	w.items = [inside]
	var step := H.tick(l, Vector2.ZERO, false, true, w)
	check_eq(step.intent, CastawayLogic.VERB_GRAB, "grab at 70 degrees")
	check(step.intent_target == inside and l.carried == inside, "carried")
	var l2 := H.logic(0.0)
	var w2 = H.world()
	w2.items = [H.StubThing.item("coconut", _at(80, 80))]
	check_eq(H.tick(l2, Vector2.ZERO, false, true, w2).intent, "none", "no grab at 80 degrees")
	check_eq(l2.get_interact_verb(), CastawayLogic.VERB_NONE, "verb none")


func test_touch_fallback_behind() -> void:
	var l := H.logic(0.0)
	var w = H.world()
	var behind = H.StubThing.item("chicken", _at(180, l.cfg.grab_touch_radius - 4))
	w.items = [behind]
	H.tick(l, Vector2.ZERO, false, false, w)
	check_eq(l.get_interact_verb(), CastawayLogic.VERB_GRAB, "verb grab")
	check_eq(l.get_interact_target_kind(), "chicken", "kind")
	var step := H.tick(l, Vector2.ZERO, false, true, w)
	check(step.intent_target == behind, "touch grab")


func test_cone_beats_touch_and_unavailable_skipped() -> void:
	var l := H.logic(0.0)
	var w = H.world()
	var touch = H.StubThing.item("a", _at(180, 20))
	var cone = H.StubThing.item("b", _at(0, 90))
	var blocked = H.StubThing.item("c", _at(0, 30))
	blocked.grabbable = false
	w.items = [touch, cone, blocked]
	var step := H.tick(l, Vector2.ZERO, false, true, w)
	check(step.intent_target == cone, "cone candidate first, unavailable skipped")


func test_tie_break_distance_then_instance_id() -> void:
	var l := H.logic(0.0)
	var w = H.world()
	var far = H.StubThing.item("far", _at(0, 80))
	var near = H.StubThing.item("near", _at(10, 50))
	w.items = [far, near]
	check(H.tick(l, Vector2.ZERO, false, true, w).intent_target == near, "nearer wins")
	var l2 := H.logic(0.0)
	var a = H.StubThing.item("a", _at(20, 60))
	var b = H.StubThing.item("b", _at(-20, 60))
	var w2 = H.world()
	w2.items = [b, a]
	var expected = a if a.get_instance_id() < b.get_instance_id() else b
	check(H.tick(l2, Vector2.ZERO, false, true, w2).intent_target == expected, "lower instance id wins")


func test_no_target_does_nothing() -> void:
	var l := H.logic()
	var step := H.tick(l, Vector2.ZERO, false, true)
	check_eq(step.intent, "none", "intent")
	check_eq(step.verb, CastawayLogic.VERB_NONE, "verb")
	check(l.carried == null, "nothing carried")


func test_carrying_never_grabs_second_object() -> void:
	var l := H.logic(0.0)
	var w = H.world()
	var first = H.StubThing.item("coconut", _at(0, 40))
	w.items = [first]
	H.tick(l, Vector2.ZERO, false, true, w)
	var second = H.StubThing.item("coconut", _at(0, 30))
	w.items = [first, second]
	H.tick(l, Vector2.ZERO, false, false, w)
	check_eq(l.get_interact_verb(), CastawayLogic.VERB_THROW, "verb throw while carrying")
	var step := H.tick(l, Vector2.ZERO, false, true, w)
	check_eq(step.intent, CastawayLogic.VERB_THROW, "throws")
	check(step.intent_object == first, "throws the carried one")
	check(step.intent_target != second and l.carried == null, "second untouched")


func test_use_with_accepting_target_else_throw() -> void:
	var l := H.logic(0.0)
	var w = H.world()
	var goat = H.StubThing.target("goat", _at(90, l.cfg.use_radius - 10), ["hat"])
	w.targets = [goat]
	var hat = H.StubThing.item("hat", Vector2.ZERO)
	l.carried = hat
	H.tick(l, Vector2.ZERO, false, false, w)
	check_eq(l.get_interact_verb(), CastawayLogic.VERB_USE, "verb use")
	check_eq(l.get_interact_target_kind(), "goat", "target kind")
	var step := H.tick(l, Vector2.ZERO, false, true, w)
	check_eq(step.intent, CastawayLogic.VERB_USE, "use")
	check(step.intent_target == goat and step.intent_object == hat, "use target and object")
	check(l.carried == null, "hands empty")
	var l2 := H.logic(0.0)
	l2.carried = H.StubThing.item("coconut", Vector2.ZERO)
	H.tick(l2, Vector2.ZERO, false, false, w)
	check_eq(l2.get_interact_verb(), CastawayLogic.VERB_THROW, "verb throw with non-accepting target")
	check_eq(H.tick(l2, Vector2.ZERO, false, true, w).intent, CastawayLogic.VERB_THROW, "throw")


func test_verb_matches_next_intent() -> void:
	var l := H.logic(0.0)
	var w = H.world()
	w.items = [H.StubThing.item("hat", _at(0, 50))]
	w.targets = [H.StubThing.target("goat", _at(180, 60), ["hat"])]
	for i in 4:
		H.tick(l, Vector2.ZERO, false, false, w)
		var verb := l.get_interact_verb()
		var step := H.tick(l, Vector2.ZERO, false, true, w)
		var intent := step.intent if step.intent != "none" else CastawayLogic.VERB_NONE
		check_eq(intent, verb, "round %d" % i)
		H.run(l, H.ticks_for(l.cfg.throw_pose_seconds) + 1, Vector2.ZERO, w)


func test_throw_destination_and_aim_snap() -> void:
	var l := H.logic(0.0)
	var w = H.world()
	l.carried = H.StubThing.item("hat", Vector2.ZERO)
	var tol := l.cfg.throw_aim_tolerance_degrees
	var inside = H.StubThing.target("goat", _at(tol - 5, 300), ["hat"])
	w.targets = [inside]
	var step := H.tick(l, Vector2.ZERO, false, true, w)
	check(step.throw_destination.is_equal_approx(inside.global_position), "snaps inside tolerance")
	var l2 := H.logic(0.0)
	l2.carried = H.StubThing.item("hat", Vector2.ZERO)
	var w2 = H.world()
	w2.targets = [H.StubThing.target("goat", _at(tol + 5, 300), ["hat"])]
	var step2 := H.tick(l2, Vector2.ZERO, false, true, w2)
	check(step2.throw_destination.is_equal_approx(Vector2(l2.cfg.throw_range, 0)), "no snap outside: %s"
			% str(step2.throw_destination))
	check_eq(l2.get_pose(), CastawayLogic.POSE_THROW, "throw pose")


func test_press_during_throw_pose_dropped() -> void:
	var l := H.logic(0.0)
	var w = H.world()
	l.carried = H.StubThing.item("coconut", Vector2.ZERO)
	H.tick(l, Vector2.ZERO, false, true, w)
	w.items = [H.StubThing.item("coconut", _at(0, 40))]
	check_eq(H.tick(l, Vector2.ZERO, false, true, w).intent, "none", "dropped during throw pose")
	H.run(l, H.ticks_for(l.cfg.throw_pose_seconds), Vector2.ZERO, w)
	check_eq(H.tick(l, Vector2.ZERO, false, true, w).intent, CastawayLogic.VERB_GRAB, "grab after the pose")
