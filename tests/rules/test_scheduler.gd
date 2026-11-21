extends TestCase
## EventScheduler: seeded determinism, windows, worst-case modes, ordering and delta independence.

const H := preload("res://tests/support/rules_helpers.gd")
const SignalRecorder := preload("res://tests/support/signal_recorder.gd")


func _events() -> Array:
	return [
		{"id": "a", "type": "wave_wash", "window": [10.0, 40.0], "duration_s": 5.0},
		{"id": "b", "type": "mud_trail", "window": [20.0, 20.0], "duration_s": 3.0},
		{"id": "c", "type": "rain_panic", "window": [5.0, 90.0], "duration_s": 12.0},
	]


func test_same_seed_same_schedule() -> void:
	check_eq(EventScheduler.build(_events(), 1234), EventScheduler.build(_events(), 1234), "same seed")
	check_ne(EventScheduler.build(_events(), 1234), EventScheduler.build(_events(), 99), "other seed")


func test_windows_hold_for_100_seeds() -> void:
	var evs := _events()
	for s in 100:
		var sched := EventScheduler.build(evs, s, EventScheduler.MODE_SEEDED)
		check_eq(sched.size(), 3, "size")
		for entry in sched:
			var ev: Dictionary = evs[entry["index"]]
			check(entry["start"] >= ev["window"][0] and entry["start"] <= ev["window"][1],
					"seed %d %s in window" % [s, entry["id"]])
			check_eq(entry["end"], entry["start"] + ev["duration_s"], "end")
		for i in sched.size() - 1:
			check(sched[i]["start"] <= sched[i + 1]["start"], "sorted")


func test_worst_case_modes() -> void:
	for entry in EventScheduler.build(_events(), 5, EventScheduler.MODE_EARLIEST):
		check_eq(entry["start"], _events()[entry["index"]]["window"][0], "earliest %s" % entry["id"])
	for entry in EventScheduler.build(_events(), 5, EventScheduler.MODE_LATEST):
		check_eq(entry["start"], _events()[entry["index"]]["window"][1], "latest %s" % entry["id"])


func test_ties_in_data_order() -> void:
	var evs := [
		{"id": "z", "type": "wave_wash", "window": [30.0, 30.0], "duration_s": 1.0},
		{"id": "y", "type": "wave_wash", "window": [30.0, 30.0], "duration_s": 1.0},
		{"id": "x", "type": "wave_wash", "window": [30.0, 30.0], "duration_s": 1.0},
	]
	var ids := []
	for entry in EventScheduler.build(evs, 3):
		ids.append(entry["id"])
	check_eq(ids, ["z", "y", "x"], "data order")


func test_appending_keeps_earlier_starts() -> void:
	var evs := _events()
	var before := {}
	for entry in EventScheduler.build(evs, 777):
		before[entry["id"]] = entry["start"]
	evs.append({"id": "d", "type": "wave_wash", "window": [0.0, 100.0], "duration_s": 1.0})
	for entry in EventScheduler.build(evs, 777):
		if before.has(entry["id"]):
			check_eq(entry["start"], before[entry["id"]], "start of %s" % entry["id"])


func _record(delta: float) -> Array:
	var def := H.make_def(H.level_data())
	var rec := SignalRecorder.new(H.bus())
	var session := LevelSession.new(def, H.bus(), H.rules(), {"seed_override": 31})
	var times := {}
	var order := []
	var seen := 0
	session.start()
	while session.elapsed() < 170.0:
		session.tick(delta, H.snap())
		var evs := rec.filtered(["event_triggered", "event_ended"])
		while seen < evs.size():
			order.append([evs[seen][0], evs[seen][1][0]])
			if evs[seen][0] == "event_triggered":
				times[evs[seen][1][0]] = session.elapsed()
			seen += 1
	rec.disconnect_all()
	for entry in session.schedule():
		check(times.has(entry["id"]), "%s triggered" % entry["id"])
		var at: float = times.get(entry["id"], -100.0)
		check(at >= entry["start"] and at <= entry["start"] + delta + 0.000001,
				"trigger of %s within one delta (%f vs %f)" % [entry["id"], at, entry["start"]])
	return order


func test_delta_independence() -> void:
	var a := _record(1.0 / 30.0)
	var b := _record(1.0 / 60.0)
	var c := _record(1.0 / 144.0)
	check_eq(a.size(), 4, "two triggers and two ends")
	check_eq(b, a, "1/60 vs 1/30")
	check_eq(c, a, "1/144 vs 1/30")
