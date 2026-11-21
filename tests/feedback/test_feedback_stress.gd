extends "res://tests/support/feedback_case.gd"
## Stress (AC4): 50 mixed gameplay signals in one frame, then 120 frames of steps; the active count per effect type
## never exceeds its cap from data/balance, pools and effect layers keep their size and nothing new is allocated.
## The runner's error scan fails the file if anything is logged.

const TYPES := ["popup", "splat", "puff", "particles", "emote", "shake", "flash", "squash", "recoil"]


func _check_caps(frame: int) -> void:
	for type in TYPES:
		var cap := director.cap(type)
		check(cap >= 1, "%s cap from balance" % type)
		if director.active_count(type) > cap:
			fail("frame %d: %s active %d > cap %d" % [frame, type, director.active_count(type), cap])


func test_fifty_events_in_one_frame() -> void:
	make_director()
	var animal := make_target(Vector2(600, 400))
	await frames(1)
	var sizes := {}
	for type in TYPES:
		sizes[type] = director.pool_size(type)
		check_eq(sizes[type], director.cap(type), "%s pool preallocated to its cap" % type)
	var children := director.effect_layer_child_count()
	var own_children := director.get_child_count()
	var objects_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var surfaces := ["water", "sand", "mud", "grass"]
	for i in 50:
		match i % 10:
			0:
				emit("object_landed", ["coconut", Vector2(i * 10, 300), surfaces[i % 4]])
			1:
				emit("fx_anchor_node", ["goat", animal])
				emit("animal_bonked", ["goat", "coconut"])
			2:
				emit("castaway_dashed", [Vector2(i, 0), Vector2.RIGHT])
			3:
				emit("fx_anchor_node", ["chicken", animal])
				emit("animal_panicked", ["chicken"])
			4:
				emit("fx_anchor_node", ["pig", animal])
				emit("object_grabbed", ["pig"])
			5:
				emit("object_bonked", ["castaway", "coconut"])
			6:
				emit("task_completed", ["lvl", "t%d" % i])
			7:
				emit("event_warning", ["e%d" % i, "mud_trail", 2.0])
			8:
				emit("timer_warning", ["lvl", 10.0])
			9:
				emit("fx_anchor", ["coconut", Vector2(i, i)])
				emit("entity_lost", ["coconut", "water"])
		_check_caps(-1)
	for type in ["popup", "splat", "puff", "particles", "emote"]:
		check(director.played(type) > director.cap(type) or director.active_count(type) == director.played(type),
				"%s played %d" % [type, director.played(type)])
	for f in 120:
		emit("castaway_step", [Vector2(f * 4, 200), surfaces[f % 4]])
		_check_caps(f)
		await frames(1)
	for type in TYPES:
		check_eq(director.pool_size(type), sizes[type], "%s pool size constant" % type)
	check_eq(director.effect_layer_child_count(), children, "effect layer children constant")
	check_eq(director.get_child_count(), own_children, "director children constant")
	check_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), objects_before, "no nodes allocated")
	await frames(10)
	check_eq(Engine.time_scale, 1.0, "time scale restored after the storm")
	check(director.played("popup") > director.cap("popup"), "popups were recycled, not piled up")
