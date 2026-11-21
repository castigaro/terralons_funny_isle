extends TestCase
## AnimalBrain (pure): wall slide, corner escape away from the castaway, separation and the speed limit.

const H := preload("res://tests/support/entity_helpers.gd")


func _max(kind: String) -> float:
	var d := H.def(kind)
	return float(d["speed"]) * float(d["flee_speed_factor"])


func test_wall_slide_keeps_tangent() -> void:
	var b := H.brain("chicken")
	b.scare(Vector2(1, 1).normalized(), false)
	var p := H.perception(Vector2.ZERO, null, Vector2.ZERO, {"wall_normal": Vector2.LEFT})
	var intent := {}
	for i in 30:
		intent = b.tick(H.DT, p)
	var v: Vector2 = intent["velocity"]
	check(v.y > 0.0, "slides along the wall: %s" % str(v))
	check(absf(v.x) < 1.0, "no push into the wall: %s" % str(v))


func test_corner_escape_turns_away_from_castaway() -> void:
	var cfg := H.config()
	for side in [1.0, -1.0]:
		var b := H.brain("chicken")
		b.scare(Vector2.RIGHT, false)
		var castaway := Vector2(-100, -10.0 * side)
		var p := H.perception(Vector2.ZERO, castaway, Vector2.ZERO, {"wall_normal": Vector2.LEFT})
		var intent := {}
		for i in 40:
			intent = b.tick(H.DT, p)
		var v: Vector2 = intent["velocity"]
		var flee: Vector2 = (Vector2.ZERO - castaway).normalized()
		check(rad_to_deg(absf(v.angle_to(flee))) <= cfg.corner_escape_degrees + 1.0, "rotated at most the escape angle")
		check(signf(v.y) == side, "turns away from the castaway (side %d): %s" % [side, str(v)])


func test_separation_pushes_apart() -> void:
	var a := H.brain("chicken", 1)
	var b := H.brain("chicken", 2)
	var pa := Vector2(0, 0)
	var pb := Vector2(0, 0)
	for i in 60:
		var ia := a.tick(H.DT, H.perception(pa, null, Vector2.ZERO, {"neighbors": [pb]}))
		var ib := b.tick(H.DT, H.perception(pb, null, Vector2.ZERO, {"neighbors": [pa]}))
		pa += ia["velocity"] * H.DT
		pb += ib["velocity"] * H.DT
	check(pa.distance_to(pb) > 10.0, "apart: %.1f" % pa.distance_to(pb))


func test_speed_never_above_flee_speed() -> void:
	for kind in EntityDefs.animal_kinds():
		var b := H.brain(kind, 9)
		var limit := _max(kind) + 0.01
		var castaway := Vector2(-60, 0)
		var fastest := 0.0
		for i in 240:
			var p := H.perception(Vector2(float(i), 0), castaway, Vector2(400, 0),
					{"neighbors": [Vector2(float(i) + 1.0, 0)], "wall_normal": Vector2.UP if i % 2 == 0 else Vector2.ZERO})
			if i == 100:
				b.panic(1.0)
			fastest = maxf(fastest, b.tick(H.DT, p)["velocity"].length())
		check(fastest <= limit, "%s: %.1f <= %.1f" % [kind, fastest, limit])
