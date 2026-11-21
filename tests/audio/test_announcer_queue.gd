extends TestCase
## Single-voice announcer queue: never two lines at once, gap between lines, duplicates and overflow handled,
## restart clears the queue, announcer_line carries the caption key and duration.

const STEP := 0.05

var _lines: Array = []


func _audio() -> Node:
	return root().get_node("Audio")


func _bus() -> Node:
	return root().get_node("EventBus")


func _on_line(line_id: String, caption_key: String, seconds: float) -> void:
	_lines.append([line_id, caption_key, seconds])


func before_each() -> void:
	_audio().set("manual_clock", true)
	_audio().set("levels_dir", "res://tests/fixtures/audio/levels")
	_lines.clear()
	_bus().announcer_line.connect(_on_line)


func after_each() -> void:
	_bus().announcer_line.disconnect(_on_line)


func test_pure_queue_one_at_a_time() -> void:
	var q := AnnouncerQueue.new(2, 0.15)
	check_true(q.enqueue("go", 1.0), "go queued")
	check_true(q.enqueue("hurry_up", 1.0), "hurry queued")
	check_eq(q.tick(0.0), "go", "go starts")
	var started := {}
	var now := 0.0
	while now < 3.0:
		now += STEP
		var line := q.tick(now)
		if line != "":
			started[line] = now
		check(q.current(now) == "" or q.queued().size() <= 1, "one current")
	check(started.has("hurry_up"), "second line started")
	check(started.get("hurry_up", 0.0) >= 1.15 - 0.0001, "second waits for end + gap: %s" % started.get("hurry_up"))
	check(started.get("hurry_up", 0.0) < 1.15 + STEP + 0.0001, "second starts right after the gap")


func test_pure_queue_duplicates_and_overflow() -> void:
	var q := AnnouncerQueue.new(2, 0.0)
	q.enqueue("go", 1.0)
	q.tick(0.0)
	check_false(q.enqueue("go", 1.0), "current not queued again")
	check_true(q.enqueue("a", 1.0), "a")
	check_false(q.enqueue("a", 1.0), "duplicate a")
	check_true(q.enqueue("b", 1.0), "b")
	check_true(q.enqueue("c", 1.0), "c")
	check_eq(q.queued(), ["b", "c"], "oldest dropped, newest kept")
	q.clear()
	check_eq(q.current(0.5), "", "cleared")
	check_eq(q.queued(), [], "cleared queue")


func test_audio_two_lines_never_overlap() -> void:
	var audio := _audio()
	var tuning: AudioTuning = audio.call("tuning")
	audio.call("say", "go")
	audio.call("say", "hurry_up")
	check_eq(audio.call("announcer_current"), "go", "go first")
	check_eq(audio.call("announcer_queued"), ["hurry_up"], "hurry waits")
	var go_len := (load("res://assets/audio/voiceover/Male/go.ogg") as AudioStream).get_length()
	var hurry_start := -1.0
	var t := 0.0
	while t < go_len + 2.0:
		audio.call("advance", STEP)
		t += STEP
		if hurry_start < 0.0 and audio.call("announcer_current") == "hurry_up":
			hurry_start = t
	check(hurry_start >= go_len + tuning.announcer_gap - 0.0001, "hurry after go + gap (%s)" % hurry_start)
	check_eq(_lines.size(), 2, "two lines emitted")
	if _lines.size() == 2:
		check_eq(_lines[0][0], "go", "first id")
		check_eq(_lines[0][1], "audio.announcer_go", "caption key")
		check(absf(float(_lines[0][2]) - (go_len + tuning.caption_extra)) < 0.001, "caption seconds")
		check_eq(_lines[1][0], "hurry_up", "second id")


func test_restart_clears_queue_and_says_go() -> void:
	var audio := _audio()
	audio.call("say", "times_up")
	audio.call("say", "level_complete")
	_bus().level_started.emit("fx_level_1")
	check_eq(audio.call("announcer_current"), "go", "go after restart")
	check_eq(audio.call("announcer_queued"), [], "old lines dropped")
	_bus().level_started.emit("fx_level_1")
	check_eq(audio.call("announcer_current"), "go", "go again after a second restart")
	check_eq(_lines.back()[0], "go", "go emitted")


func test_signals_drive_lines() -> void:
	var audio := _audio()
	_bus().timer_warning.emit("fx_level_1", 30.0)
	check_eq(audio.call("announcer_current"), "hurry_up", "hurry on timer warning")
	_bus().level_won.emit("fx_level_1", 3)
	check_eq(audio.call("announcer_queued"), ["level_complete"], "complete queued")
