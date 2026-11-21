extends TestCase
## The feedback arena runs its full sequence headless: every mapped signal plays at least one effect, the bonk
## burst ends with Engine.time_scale back at 1.0, caps hold every frame and the arena reports done.

const ARENA := preload("res://tests/scenes/fx_arena.tscn")
const TYPES := ["popup", "splat", "puff", "particles", "emote", "shake", "flash", "squash", "recoil"]


func test_full_sequence() -> void:
	var arena: Node2D = ARENA.instantiate()
	add_node(arena)
	var limit: int = (arena.steps.size() + 2) * arena.STEP_FRAMES + arena.SETTLE_FRAMES + 60
	var n := 0
	while not arena.done and n < limit:
		for type in TYPES:
			if arena.director.active_count(type) > arena.director.cap(type):
				fail("%s over its cap at frame %d" % [type, n])
		await frames(1)
		n += 1
	check(arena.done, "arena finished after %d frames" % n)
	check(arena.ok, "arena ok: %s" % str(arena.results))
	check_eq(Engine.time_scale, 1.0, "time scale restored")
	var director: FeedbackDirector = arena.director
	for name in director.map.signals:
		var played := false
		for label in arena.results:
			if String(label).get_slice(":", 0) == name and arena.results[label] > 0:
				played = true
		check(played, "%s produced an effect in the arena" % name)
	for type in director.map.events:
		check(arena.results.get("event_warning:" + type, 0) > 0, "%s warning played" % type)
	check(arena.results.get("bonk_burst", 0) >= 20, "burst of 20 bonks played")
