extends TestCase
## BI-18 BackdropCritter: wanders and idles inside its land rect without settling, flips with its walk direction,
## hops only while walking and never with reduce motion, has no body or group and sends no game signal or sound.

const STEP := 1.0 / 60.0
const SECONDS := 40.0
const LAND := Rect2(100, 100, 600, 500)
const SignalRecorder := preload("res://tests/support/signal_recorder.gd")


func _make(kind: String, seed_value: int = 7) -> BackdropCritter:
	var c := BackdropCritter.new()
	c.kind = kind
	c.seed_value = seed_value
	c.land = LAND
	c.position = LAND.get_center()
	add_node(c)
	c.set_process(false)
	return c


func test_wanders_and_idles_inside_its_land() -> void:
	var c := _make("chicken")
	check_eq(c.error, "", "no error")
	check(c.sprite.texture != null, "sprite loaded")
	var states := {}
	var start := c.position
	var far := 0.0
	var flips_ok := true
	var outside := 0
	for i in int(SECONDS / STEP):
		var before := c.position
		c.step(STEP)
		states[c.state_name()] = true
		if not LAND.grow(0.01).has_point(c.position):
			outside += 1
		far = maxf(far, c.position.distance_to(start))
		var dx := c.position.x - before.x
		if absf(dx) > 0.01 and c.sprite.flip_h != (dx < 0.0):
			flips_ok = false
	check_true(states.has("idle"), "idles")
	check_true(states.has("wander"), "wanders")
	check_false(states.has("settled"), "never settles")
	check(far > 50.0, "moves at least 50 units (got %.1f)" % far)
	check_true(flips_ok, "flip_h follows the walk direction")
	check_eq(outside, 0, "steps outside the land rect")


func test_clamped_back_into_its_land() -> void:
	var c := _make("goat")
	c.position = Vector2(-500, 2000)
	c.step(STEP)
	check(LAND.grow(0.01).has_point(c.position), "a critter outside its land is put back inside")


func test_hops_while_walking_but_not_with_reduce_motion() -> void:
	var c := _make("pig", 3)
	var max_hop := 0.0
	for i in int(SECONDS / STEP):
		c.step(STEP)
		max_hop = maxf(max_hop, c.hop_height())
	check(max_hop > 0.0, "hops while walking")
	check(max_hop <= Balance.get_float("flow", "backdrop_hop_px") + 0.01, "hop within backdrop_hop_px")
	c.reduce_motion = true
	var reduced := 0.0
	for i in int(SECONDS / STEP):
		c.step(STEP)
		reduced = maxf(reduced, c.hop_height())
	check_eq(reduced, 0.0, "no hop with reduce motion")


func test_no_body_no_group_no_signal_no_sound() -> void:
	var rec := SignalRecorder.new(EventBus)
	var sfx_before := (Audio.call("sfx_requests") as Array).size()
	var c := _make("monkey", 5)
	for i in int(SECONDS / STEP):
		c.step(STEP)
	check_eq(c.get_groups().filter(func(g: StringName) -> bool: return not String(g).begins_with("_")).size(), 0,
			"joins no group")
	check_eq(c.find_children("*", "CollisionObject2D", true, false).size(), 0, "no physics body")
	check_eq(rec.names(), [], "no EventBus signal")
	rec.disconnect_all()
	check_eq((Audio.call("sfx_requests") as Array).size(), sfx_before, "no sound request")


func test_unknown_kind_reports_an_error() -> void:
	var c := _make("unicorn")
	check_ne(c.error, "", "unknown kind sets error")
	check_eq(c.brain, null, "no brain")
	c.step(STEP)
	check_eq(c.state_name(), "", "idle shell without brain")
