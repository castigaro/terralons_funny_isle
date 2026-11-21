extends TestCase
## Pure castaway traction on slippery ground (mud): slower to speed up, much longer to stop, dash and knockback
## unchanged, sand unaffected.

const H := preload("res://tests/support/castaway_helpers.gd")
const BIG := Rect2(-100000, -100000, 200000, 200000)


func _mud_world() -> CastawayWorld:
	var w := H.StubWorld.new()
	w.mud.append(BIG)
	return w


## Distance travelled after releasing the input at full speed.
func _stopping_distance(w: CastawayWorld) -> float:
	var l := H.logic()
	H.run(l, 120, Vector2.RIGHT, w)
	var travelled := 0.0
	var ticks := 0
	while l.velocity != Vector2.ZERO and ticks < 2000:
		travelled += H.tick(l, Vector2.ZERO, false, false, w).velocity.length() * H.DT
		ticks += 1
	return travelled


func _ticks_to_speed(w: CastawayWorld) -> int:
	var l := H.logic()
	var ticks := 0
	while l.velocity.length() < l.cfg.move_speed - 0.01 and ticks < 2000:
		H.tick(l, Vector2.RIGHT, false, false, w)
		ticks += 1
	return ticks


func test_mud_lengthens_the_stopping_distance() -> void:
	var cfg := H.config()
	var sand := _stopping_distance(H.world())
	var mud := _stopping_distance(_mud_world())
	var factor := 1.0 / cfg.slippery_friction_factor
	check(mud >= sand * factor * 0.9, "mud stop %.1f px vs sand %.1f px (factor %.1f)" % [mud, sand, factor])


func test_mud_slows_the_acceleration() -> void:
	var sand := _ticks_to_speed(H.world())
	var mud := _ticks_to_speed(_mud_world())
	check(mud > sand * 2, "mud reaches speed after %d ticks, sand after %d" % [mud, sand])


func test_top_speed_unchanged_on_mud() -> void:
	var l := H.logic()
	H.run(l, 600, Vector2.RIGHT, _mud_world())
	check(absf(l.velocity.length() - l.cfg.move_speed) < 0.5, "top speed %.1f" % l.velocity.length())


func test_dash_and_knockback_unaffected() -> void:
	for w in [H.world(), _mud_world()]:
		var l := H.logic()
		var step := H.tick(l, Vector2.RIGHT, true, false, w)
		check(step.dash_started, "dash starts")
		check(absf(step.velocity.length() - l.cfg.dash_speed()) < 0.01, "dash speed %.1f" % step.velocity.length())
		var k := H.logic()
		k.bonk(Vector2.LEFT)
		var ks := H.tick(k, Vector2.ZERO, false, false, w)
		check(absf(ks.velocity.length() - k.cfg.knockback_speed()) < 0.01, "knockback speed %.1f" % ks.velocity.length())
