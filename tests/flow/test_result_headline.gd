extends "res://tests/support/flow_case.gd"
## Result screen reads cleanly: exactly one visible headline on a win and a loss (EN and DE), no caption, popup word,
## HUD, cue or world prompt behind it, earned stars pop in once and then stay (reduce motion snaps), a press during
## the pop snaps it and still works, everything comes back after Retry, Next and Esc, and no two visible texts of
## the panel overlap at 1280x720 and 1920x1080.

const ClipCheck := preload("res://tests/support/clip_check.gd")
const SIZES := [Vector2(1280, 720), Vector2(1920, 1080)]
const RESULT_SCENE := "res://scenes/ui/menus/result_screen.tscn"
const REAL_CAMPAIGN := "res://data/campaign.json"
const REAL_LEVELS := "res://data/levels"
const L1 := "l1_beach_camp"
const HEADLINES := {
	"en": {"won": "Level complete!", "lost": "Time's up!"},
	"de": {"won": "Level geschafft!", "lost": "Die Zeit ist um!"},
}


func after_each() -> void:
	super.after_each()
	I18n.set_locale("en")
	Audio.reset_for_tests()
	Progress.use_campaign(FIXTURE_CAMPAIGN)


func _start(level_id: String = SAMPLE) -> void:
	flow.call("start_level_flow", level_id, false)
	await frames(1)


func _caption() -> Node:
	return Audio.caption()


func _paths(nodes: Array) -> Array:
	return nodes.map(func(n: Node) -> String: return "%s '%s'" % [n.get_path(), n.get("text")])


## One visible headline, nothing with text outside the result screen, caption and HUD quiet.
func _check_clean(won: bool, locale: String) -> void:
	var headline: String = HEADLINES[locale]["won" if won else "lost"]
	var result := screen_node()
	check_eq(screen(), FlowRules.Screen.RESULT, "result shown")
	check_eq((result.get("heading") as Label).text, headline, "heading text")
	var texts := ClipCheck.visible_texts(root())
	var same := texts.filter(func(n: Node) -> bool: return String(n.get("text")).strip_edges() == headline)
	check_eq(_paths(same).size(), 1, "exactly one visible headline [%s]: %s" % [locale, str(_paths(same))])
	var outside := texts.filter(func(n: Node) -> bool: return not result.is_ancestor_of(n))
	check_eq(_paths(outside), [], "no visible text outside the result screen [%s]" % locale)
	check_false(_caption().call("is_showing"), "caption hidden")
	check_true(_caption().call("is_suppressed"), "caption suppressed")
	check_false(level().hud().visible, "HUD hidden")
	check_false((level().get_node("Prompts") as Node2D).visible, "world prompts hidden")
	check_false((level().get_node("Overlay/LevelCue") as CanvasLayer).visible, "level cue hidden")
	check_true(level().result_mode(), "level in result mode")


func _headline_win(locale: String) -> void:
	await open_flow("headline_win_" + locale)
	I18n.set_locale(locale)
	await _start()
	await frames(30)
	await win_level()
	await frames(90)
	EventBus.announcer_line.emit("level_complete", "audio.announcer_level_complete", 3.0)
	await frames(1)
	_check_clean(true, locale)


func _headline_loss(locale: String) -> void:
	await open_flow("headline_loss_" + locale)
	I18n.set_locale(locale)
	await _start()
	await lose_level()
	await frames(90)
	EventBus.announcer_line.emit("times_up", "audio.announcer_times_up", 3.0)
	await frames(1)
	_check_clean(false, locale)
	var missing: Label = screen_node().get("missing_label")
	check_true(missing.visible, "missing list stays")
	check_ne(missing.text, "", "missing text")
	if locale == "en":
		check_eq(missing.text, "Missing: Visit zone A", "missing text as before")


func test_single_headline_win_en() -> void:
	await _headline_win("en")


func test_single_headline_win_de() -> void:
	await _headline_win("de")


func test_single_headline_loss_en() -> void:
	await _headline_loss("en")


func test_single_headline_loss_de() -> void:
	await _headline_loss("de")


## A real level has a FeedbackDirector: its loss popup ("UH-OH!") and a late level_won popup ("YAY!") stay away.
func test_real_level_popups_are_skipped() -> void:
	await open_flow("headline_real", REAL_CAMPAIGN)
	Audio.levels_dir = REAL_LEVELS
	await _start(L1)
	await frames(5)
	var director := level().feedback_director()
	check_ne(director, null, "real level has a director")
	await lose_level()
	await frames(30)
	check_eq(director.active_count("popup"), 0, "no loss popup behind the result")
	check_true(director.text_suppressed(), "director suppressed")
	var particles := director.played("particles")
	EventBus.level_won.emit(L1, 3)
	await frames(2)
	check_eq(screen(), FlowRules.Screen.RESULT, "a late level_won does not reopen anything")
	check_eq(director.active_count("popup"), 0, "late level_won popup skipped")
	check(director.played("particles") > particles, "particles still play")
	_check_clean(false, "en")
	await wait_guard()
	await key(KEY_R)
	check_eq(screen(), FlowRules.Screen.PLAYING, "retry")
	check_false(director.text_suppressed(), "director unsuppressed after retry")


func _host_result(size: Vector2) -> MenuScreen:
	var host := Control.new()
	host.size = size
	add_node(host)
	var node := (load(RESULT_SCENE) as PackedScene).instantiate() as MenuScreen
	host.add_child(node)
	await frames(1)
	return node


func _win_data(count: int) -> Dictionary:
	return {"won": true, "stars": count, "time_left": 30.0, "new_best": false, "missing_keys": [],
			"next_enabled": true}


func _star(node: MenuScreen, i: int) -> TextureRect:
	return (node.get("stars") as Array)[i]


func _final(star: TextureRect) -> bool:
	return is_equal_approx(star.scale.x, 1.0) and is_equal_approx(star.modulate.a, 1.0)


func test_star_animation() -> void:
	use_data_dir("headline_stars")
	var node := await _host_result(Vector2(1920, 1080))
	node.call("setup", _win_data(2))
	check_eq(node.call("star_count"), 2, "final textures at once")
	check_true(node.call("stars_animating"), "animating")
	check(_star(node, 0).scale.x < 0.01 and _star(node, 0).modulate.a < 0.01, "star 1 starts hidden")
	check(_star(node, 1).scale.x < 0.01 and _star(node, 1).modulate.a < 0.01, "star 2 starts hidden")
	check_true(_final(_star(node, 2)), "unearned star shown at full alpha")
	check_eq(_star(node, 2).texture.resource_path.get_file(), "star_outline.png", "unearned outline")
	var flow_cfg := Balance.get_section("flow")
	var interval := float(flow_cfg["result_star_interval_s"])
	var pop := float(flow_cfg["result_star_pop_s"])
	node.advance_time(interval + pop * 0.3)
	check_true(_final(_star(node, 0)), "star 1 done after its pop")
	check(_star(node, 1).scale.x > 0.0 and _star(node, 1).modulate.a > 0.0, "star 2 popping, one after another")
	node.advance_time(float(node.call("star_anim_total")))
	check_false(node.call("stars_animating"), "animation over")
	for i in 3:
		check_true(_final(_star(node, i)), "star %d final" % i)
	node.refresh_texts()
	I18n.set_locale("de")
	await frames(1)
	check_false(node.call("stars_animating"), "language switch does not replay")
	node.call("setup", _win_data(2))
	check_false(node.call("stars_animating"), "a second setup does not replay")
	check_true(_final(_star(node, 0)), "second setup snaps")
	check_eq((node.find_children("Star*", "TextureRect", true, false)).size(), 3, "one star row")


func test_star_animation_reduce() -> void:
	use_data_dir("headline_reduce")
	write_file(DataDir.file(FxSettings.FILE), JSON.stringify({FxSettings.KEY: true}))
	var node := await _host_result(Vector2(1920, 1080))
	node.call("setup", _win_data(3))
	check_false(node.call("stars_animating"), "reduce motion: no pop")
	check_eq(node.call("star_count"), 3, "three stars")
	for i in 3:
		check_true(_final(_star(node, i)), "star %d final at once" % i)


func test_star_animation_zero_stars() -> void:
	use_data_dir("headline_zero")
	var node := await _host_result(Vector2(1920, 1080))
	node.call("setup", {"won": false, "stars": 0, "time_left": 0.0, "missing_keys": [], "next_enabled": false})
	check_false(node.call("stars_animating"), "nothing to pop")
	for i in 3:
		check_true(_final(_star(node, i)), "outline %d at full alpha" % i)
		check_eq(_star(node, i).texture.resource_path.get_file(), "star_outline.png", "outline %d" % i)


func test_press_during_animation_snaps() -> void:
	use_data_dir("headline_press")
	var node := await _host_result(Vector2(1920, 1080))
	node.call("setup", _win_data(3))
	node.guard_s = 0.0
	node.advance_time(0.0)
	check_true(node.call("accepts_input"), "input open")
	check_true(node.call("stars_animating"), "still popping")
	var got := []
	node.connect("retry_pressed", func() -> void: got.append([node.call("stars_animating"), _final(_star(node, 2))]))
	var ev := InputEventKey.new()
	ev.keycode = KEY_R
	ev.physical_keycode = KEY_R
	ev.pressed = true
	check_true(node.handle_input(ev), "R handled")
	check_eq(got, [[false, true]], "R snaps the stars before retrying")
	var node2 := await _host_result(Vector2(1920, 1080))
	node2.call("setup", _win_data(3))
	node2.guard_s = 0.0
	node2.advance_time(0.0)
	var got2 := []
	node2.connect("next_pressed", func() -> void: got2.append(node2.call("stars_animating")))
	(node2.get("next_button") as Button).pressed.emit()
	check_eq(got2, [false], "Next button snaps the stars before emitting")


func test_press_during_animation_in_flow() -> void:
	await open_flow("headline_press_flow")
	await _start()
	await win_level()
	var result := screen_node()
	check_true(result.call("stars_animating"), "one star popping")
	result.guard_s = 0.0
	result.advance_time(0.0)
	check_true(result.call("stars_animating"), "still popping when input opens")
	await key(KEY_R)
	check_eq(screen(), FlowRules.Screen.PLAYING, "R retries during the pop")


func test_everything_restored_after_retry_next_and_esc() -> void:
	await open_flow("headline_restore")
	await _start()
	await frames(5)
	var hud_before := level().hud().visible
	var prompts_before := (level().get_node("Prompts") as Node2D).visible
	await win_level()
	check_false(level().hud().visible, "HUD hidden under the result")
	await wait_guard()
	await key(KEY_R)
	check_eq(screen(), FlowRules.Screen.PLAYING, "retry")
	check_eq(level().hud().visible, hud_before, "HUD back")
	check_eq((level().get_node("Prompts") as Node2D).visible, prompts_before, "prompts back")
	check_true((level().get_node("Overlay/LevelCue") as CanvasLayer).visible, "restart cue shows")
	check_false(level().result_mode(), "result mode off")
	check_false(_caption().call("is_suppressed"), "caption unsuppressed after retry")
	EventBus.announcer_line.emit("hurry_up", "audio.announcer_hurry_up", 2.0)
	check_true(_caption().call("is_showing"), "captions show again")
	_caption().call("hide_now")
	EventBus.announcer_line.emit("go", "audio.announcer_go", 2.0)
	check_false(_caption().call("is_showing"), "the go line shows no chip, the GO popup is the start cue")
	_caption().call("hide_now")
	await win_level()
	await wait_guard()
	await key(KEY_ENTER)
	check_eq(screen(), FlowRules.Screen.INTRO, "Next -> intro of the next level")
	check_false(_caption().call("is_suppressed"), "caption unsuppressed on the intro")
	await wait_guard()
	await key(KEY_SPACE)
	check_eq(screen(), FlowRules.Screen.PLAYING, "next level running")
	check_true(level().hud().visible, "fresh HUD visible")
	check_false(level().result_mode(), "fresh level not in result mode")
	await win_level()
	await wait_guard()
	await key(KEY_ESCAPE)
	check_eq(screen(), FlowRules.Screen.LEVEL_SELECT, "Esc -> level select")
	check_false(_caption().call("is_suppressed"), "caption unsuppressed on the level select")


func test_result_mode_is_idempotent() -> void:
	await open_flow("headline_idempotent")
	await _start()
	await frames(5)
	var lvl := level()
	var prompts := lvl.get_node("Prompts") as Node2D
	prompts.visible = false
	var hud_before := lvl.hud().visible
	lvl.set_result_mode(true)
	lvl.set_result_mode(true)
	check_true(lvl.result_mode(), "on")
	check_false(lvl.hud().visible, "HUD hidden")
	lvl.set_result_mode(false)
	check_false(lvl.result_mode(), "off")
	check_eq(lvl.hud().visible, hud_before, "HUD restored after two ons")
	check_false(prompts.visible, "prompts that were hidden before stay hidden")


func _fill(node: MenuScreen, won: bool) -> void:
	if won:
		node.call("setup", {"won": true, "stars": 3, "time_left": 600.0, "new_best": true, "missing_keys": [],
				"next_enabled": true})
		node.advance_time(float(node.call("star_anim_total")))
	else:
		var keys: Array = []
		for i in int(Balance.get_section("rules").get("tasks_max", 0)) - 1:
			keys.append("flowfix.long_task" if i == 0 else "flowfix.short_task")
		node.call("setup", {"won": false, "stars": 0, "time_left": 0.0, "missing_keys": keys, "next_enabled": false})
	node.advance_time(node.guard_s)


func test_no_text_overlap() -> void:
	use_data_dir("headline_overlap")
	install_fixture_translations()
	var errors: Array[String] = []
	for locale in ["en", "de"]:
		I18n.set_locale(locale)
		for size in SIZES:
			for won in [true, false]:
				var node := await _host_result(size)
				_fill(node, won)
				await frames(2)
				var where := "%s %s@%dx%d" % ["win" if won else "loss", locale, size.x, size.y]
				var view := Rect2((node.get_parent() as Control).global_position, size)
				for err in ClipCheck.text_overlaps(node, view):
					errors.append("%s: %s" % [where, err])
				errors.append_array(ClipCheck.check_tree(node, where, locale, view))
				var headings := ClipCheck.visible_texts(node).filter(
						func(n: Node) -> bool: return String(n.get("text")) == HEADLINES[locale]["won" if won else "lost"])
				check_eq(headings.size(), 1, "one headline %s" % where)
				node.get_parent().queue_free()
				await frames(1)
	check_eq(errors, [] as Array[String], "overlap or clip problems")


func test_text_overlaps_flags_overlap() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_node(host)
	for i in 2:
		var label := Label.new()
		label.text = "Level complete!"
		label.position = Vector2(100 + i * 20, 100)
		host.add_child(label)
	var button := Button.new()
	button.text = "Retry"
	button.position = Vector2(600, 300)
	host.add_child(button)
	await frames(1)
	var errors := ClipCheck.text_overlaps(host, Rect2(Vector2.ZERO, host.size))
	check_eq(errors.size(), 1, "one overlapping pair: %s" % str(errors))
