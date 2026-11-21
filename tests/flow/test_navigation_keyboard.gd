extends "res://tests/support/flow_case.gd"
## Keyboard navigation: title -> level select -> intro -> running level with two confirmations, initial focus on
## every screen, arrows reach every button, Esc as Back, locked and coming-soon tiles start nothing.


func _buttons(node: Node) -> Array:
	var out: Array = []
	if node is BaseButton and (node as Control).is_visible_in_tree():
		out.append(node)
	for child in node.get_children():
		out.append_array(_buttons(child))
	return out


func test_title_to_running_level_with_two_confirmations() -> void:
	await open_flow("nav_keys_start")
	check_eq(screen(), FlowRules.Screen.TITLE, "title first")
	check_eq(focused(), screen_node().get("play_button"), "Play focused")
	await key(KEY_ENTER)
	check_eq(screen(), FlowRules.Screen.LEVEL_SELECT, "level select")
	check_eq(focused(), screen_node().call("tile_button", SAMPLE), "first open level focused")
	await key(KEY_ENTER)
	check_eq(screen(), FlowRules.Screen.INTRO, "intro card after two confirmations")
	check_eq(session().get_state(), LevelSession.State.READY, "timer not running yet")
	await wait_guard()
	await key(KEY_SPACE)
	check_eq(screen(), FlowRules.Screen.PLAYING, "playing")
	check_eq(session().get_state(), LevelSession.State.RUNNING, "running")


func test_every_screen_has_focus_and_arrows_reach_every_button() -> void:
	await open_flow("nav_keys_focus")
	for s in [FlowRules.Screen.TITLE, FlowRules.Screen.LEVEL_SELECT, FlowRules.Screen.SETTINGS]:
		var node: MenuScreen = flow.call("show_screen", s, FlowRules.Screen.TITLE)
		await frames(1)
		check_ne(focused(), null, "initial focus on screen %d" % s)
		var buttons := _buttons(node)
		var by_tab := {}
		for i in buttons.size() * 2 + 2:
			by_tab[focused()] = true
			await key(KEY_TAB)
		for b in buttons:
			check_true(by_tab.has(b), "Tab on screen %d reaches %s" % [s, b.name])
	var title: MenuScreen = flow.call("show_screen", FlowRules.Screen.TITLE)
	await frames(1)
	var by_arrow := {}
	for i in 6:
		by_arrow[focused()] = true
		await key(KEY_DOWN)
	for b in _buttons(title):
		check_true(by_arrow.has(b), "arrows on the title reach %s" % b.name)


func test_escape_is_back() -> void:
	await open_flow("nav_keys_back")
	await key(KEY_ESCAPE)
	check_eq(screen(), FlowRules.Screen.TITLE, "Esc does nothing on the title")
	check_eq(quit_calls, 0, "no quit")
	for s in [FlowRules.Screen.LEVEL_SELECT, FlowRules.Screen.SETTINGS, FlowRules.Screen.CREDITS]:
		flow.call("show_screen", s, FlowRules.Screen.TITLE)
		await frames(1)
		await wait_guard()
		await key(KEY_ESCAPE)
		check_eq(screen(), FlowRules.Screen.TITLE, "Esc back from %d" % s)


func test_locked_and_coming_soon_tiles_start_nothing() -> void:
	await open_flow("nav_keys_locked")
	var select: MenuScreen = flow.call("show_screen", FlowRules.Screen.LEVEL_SELECT, FlowRules.Screen.TITLE)
	await frames(1)
	check_eq(select.call("tile_state", SMALL), "locked", "second level locked")
	check_eq(select.call("tile_state", MISSING), "soon", "missing scene coming soon")
	(select.call("tile_button", SMALL) as Button).grab_focus()
	await key(KEY_ENTER)
	check_eq(screen(), FlowRules.Screen.LEVEL_SELECT, "locked tile ignored")
	check_true(select.call("is_flashing"), "Locked note pulses")
	check_eq(((select.get("tiles") as Dictionary)[SMALL]["note"] as Label).text, "Locked", "Locked shown")
	(select.call("tile_button", MISSING) as Button).grab_focus()
	await key(KEY_ENTER)
	check_eq(screen(), FlowRules.Screen.LEVEL_SELECT, "coming soon ignored")
	check_null_level()


func check_null_level() -> void:
	check_eq(level(), null, "no level loaded")


func _ring(slider: Control) -> Panel:
	return slider.get_node_or_null("FocusRing") as Panel


func _down_until(target: Control, limit: int = 8) -> void:
	for i in limit:
		if focused() == target:
			return
		await key(KEY_DOWN)


func _check_ring_drawn(slider: HSlider, label: String) -> void:
	var ring := _ring(slider)
	check_ne(ring, null, "%s has a focus ring" % label)
	if ring == null:
		return
	check_true(ring.is_visible_in_tree(), "%s ring visible while focused" % label)
	var style := ring.get_theme_stylebox("panel") as StyleBoxFlat
	check_ne(style, null, "%s ring is a flat outline" % label)
	if style == null:
		return
	var px := Balance.get_int("flow", "focus_outline_px")
	check(px > 0, "outline width above 0")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		check_eq(style.get_border_width(side), px, "%s border width on side %d" % [label, side])
	check_eq(style.border_color.a, 1.0, "%s opaque border" % label)
	check_false(style.draw_center, "%s outline only" % label)
	var grow := Balance.get_float("flow", "focus_expand_px")
	check_true(ring.get_global_rect().encloses(slider.get_global_rect().grow(grow)),
			"%s ring encloses the slider plus %s px" % [label, grow])
	check(ring.modulate.a > 0.0 and ring.self_modulate.a > 0.0, "%s ring not transparent" % label)


func test_slider_focus_ring_renders() -> void:
	await open_flow("nav_keys_slider_ring")
	var settings: MenuScreen = flow.call("show_screen", FlowRules.Screen.SETTINGS, FlowRules.Screen.TITLE)
	await frames(1)
	var music: HSlider = settings.get("music_slider")
	var effects: HSlider = settings.get("effects_slider")
	check_false(_ring(music).visible, "music ring hidden before focus")
	await _down_until(music)
	check_eq(focused(), music, "arrows reach the music slider")
	_check_ring_drawn(music, "music")
	check_false(_ring(effects).visible, "effects ring hidden")
	var before := music.value
	await key(KEY_LEFT)
	check_eq(music.value, maxf(before - Balance.get_float("flow", "slider_step_percent"), 0.0), "Left steps down")
	await _down_until(effects)
	check_eq(focused(), effects, "arrows reach the effects slider")
	_check_ring_drawn(effects, "effects")
	check_false(_ring(music).visible, "music ring hidden after focus moved on")
	await _down_until(settings.get("reduce_toggle"))
	check_eq(focused(), settings.get("reduce_toggle"), "arrows reach the checkbox")
	check_false(_ring(effects).visible, "effects ring hidden on the checkbox")
