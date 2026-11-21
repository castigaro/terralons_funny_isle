extends TestCase
## SeededRng: determinism for event schedules.


func test_same_seed_same_sequence() -> void:
	var a := SeededRng.new(42)
	var b := SeededRng.new(42)
	var seq_a := []
	var seq_b := []
	for i in 10:
		seq_a.append(a.randi_range(0, 1000))
		seq_b.append(b.randi_range(0, 1000))
	check_eq(seq_a, seq_b, "sequences")
	check_eq(a.get_seed(), 42, "seed")


func test_shuffle_deterministic_and_complete() -> void:
	var first := SeededRng.new(7).shuffle([1, 2, 3, 4, 5, 6])
	var second := SeededRng.new(7).shuffle([1, 2, 3, 4, 5, 6])
	check_eq(first, second, "deterministic")
	var sorted := first.duplicate()
	sorted.sort()
	check_eq(sorted, [1, 2, 3, 4, 5, 6], "same elements")


func test_jitter_and_pick() -> void:
	var rng := SeededRng.new(3)
	for i in 50:
		var v := rng.jitter(10.0, 2.0)
		check(v >= 8.0 and v <= 12.0, "jitter %f in range" % v)
	check(["a", "b"].has(rng.pick(["a", "b"])), "pick")
	check_eq(rng.pick([]), null, "empty pick")
