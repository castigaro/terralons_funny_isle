extends MenuScreen
## Short result screen: stars, time left, "New best!" and on a loss the missing required tasks. Input is accepted
## after result_input_delay_s (at most 2 s); then Retry (R), Next (Enter) and Level select (Esc) are one key or one
## click. Next is disabled when it would only retry (loss with the next level still locked); Retry gets the focus.
## One headline and one star row: earned stars pop in once, one after another (result_star_interval_s apart), and
## then stay; reduce motion, a second setup() or pressing a button snaps them to their final look.

signal retry_pressed
signal next_pressed
signal level_select_pressed

const ICON_RETRY := "res://assets/ui/ui-pack/PNG/Extra/Default/icon_repeat_light.png"
const ICON_NEXT := "res://assets/ui/ui-pack/PNG/Yellow/Default/arrow_basic_e.png"
const ICON_LEVELS := "res://assets/ui/ui-pack/PNG/Yellow/Default/arrow_basic_w.png"
const STAR_FULL := "res://assets/ui/ui-pack/PNG/Yellow/Default/star.png"
const STAR_EMPTY := "res://assets/ui/ui-pack/PNG/Yellow/Default/star_outline.png"

var heading: Label
var stars: Array = []
var time_label: Label
var best_label: Label
var missing_label: Label
var retry_button: Button
var next_button: Button
var level_select_button: Button
var _data := {}
var _open := false
var _anim_from := -1.0
var _earned := 0
var _stars_played := false
var _star_interval := 0.0
var _star_pop_s := 0.0
var _star_pop_scale := 1.0


func _build() -> void:
	guard_s = minf(float(cfg.get("result_input_delay_s", 0)), float(cfg.get("result_input_delay_max_s", 0)))
	var box := make_panel()
	heading = make_label("", {}, MenuTheme.VARIATION_HEADING)
	box.add_child(heading)
	var row := HBoxContainer.new()
	row.name = "Stars"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var px := float(cfg.get("result_star_px", 0))
	_star_interval = float(cfg.get("result_star_interval_s", 0))
	_star_pop_s = float(cfg.get("result_star_pop_s", 0))
	_star_pop_scale = float(cfg.get("result_star_pop_scale", 1))
	for i in Stars.MAX_STARS:
		var star := TextureRect.new()
		star.name = "Star%d" % i
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.custom_minimum_size = Vector2(px, px)
		star.texture = load(STAR_EMPTY)
		row.add_child(star)
		stars.append(star)
	box.add_child(row)
	time_label = make_label("")
	box.add_child(time_label)
	best_label = make_label("menu.result.new_best", {}, MenuTheme.VARIATION_ACCENT)
	best_label.visible = false
	box.add_child(best_label)
	missing_label = make_wrapping_label("")
	missing_label.visible = false
	box.add_child(missing_label)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	retry_button = _add(buttons, make_button("menu.retry", ICON_RETRY), retry_pressed)
	next_button = _add(buttons, make_button("menu.next", ICON_NEXT), next_pressed)
	box.add_child(buttons)
	level_select_button = _add(box, make_button("menu.level_select", ICON_LEVELS), level_select_pressed)
	level_select_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_set_buttons_enabled(false)


func _add(box: Control, button: Button, sig: Signal) -> Button:
	button.pressed.connect(func() -> void:
		_finish_stars()
		sig.emit())
	box.add_child(button)
	return button


## data: {won: bool, stars: int, time_left: float, new_best: bool, missing_keys: Array, next_enabled: bool}.
func setup(data: Dictionary) -> void:
	_data = data.duplicate()
	var won := bool(data.get("won", false))
	bind_text(heading, "menu.result.won" if won else "menu.result.lost")
	var count := int(data.get("stars", 0))
	for i in stars.size():
		(stars[i] as TextureRect).texture = load(STAR_FULL if i < count else STAR_EMPTY)
	_start_stars(count)
	bind_text(time_label, "menu.result.time_left",
			{"time": FlowRules.format_time(float(data.get("time_left", 0.0)), true)})
	best_label.visible = won and bool(data.get("new_best", false))
	var missing: Array = data.get("missing_keys", [])
	missing_label.visible = not won and not missing.is_empty()
	var refs: Array = []
	for key in missing:
		refs.append({"key": String(key)})
	bind_text(missing_label, "menu.result.missing", {"tasks": refs})
	next_button.disabled = true
	_set_buttons_enabled(_open)


func star_count() -> int:
	var n := 0
	for star in stars:
		if (star as TextureRect).texture.resource_path == STAR_FULL:
			n += 1
	return n


func accepts_input() -> bool:
	return _open


## Starts the one-time pop of the earned stars; no stars, reduce motion or an earlier run snap to the final look.
func _start_stars(count: int) -> void:
	_earned = clampi(count, 0, stars.size())
	var reduce := FxSettings.read_reduce(DataDir.file(FxSettings.FILE))
	if _earned == 0 or reduce or _stars_played:
		_finish_stars()
		return
	_stars_played = true
	_anim_from = age()
	for i in stars.size():
		var star := stars[i] as TextureRect
		star.scale = Vector2.ZERO if i < _earned else Vector2.ONE
		star.modulate.a = 0.0 if i < _earned else 1.0
	_update_stars()


func _update_stars() -> void:
	if _anim_from < 0.0:
		return
	var elapsed := age() - _anim_from
	if elapsed >= star_anim_total():
		_finish_stars()
		return
	for i in _earned:
		var star := stars[i] as TextureRect
		var v := FlowRules.star_pop(elapsed - float(i) * _star_interval, _star_pop_s, _star_pop_scale)
		star.pivot_offset = star.size / 2.0
		star.scale = Vector2.ONE * v.x
		star.modulate.a = v.y


func _finish_stars() -> void:
	_anim_from = -1.0
	for star in stars:
		(star as TextureRect).scale = Vector2.ONE
		(star as TextureRect).modulate.a = 1.0


func stars_animating() -> bool:
	return _anim_from >= 0.0


func star_anim_total() -> float:
	return FlowRules.star_anim_seconds(_earned, _star_interval, _star_pop_s)


func _tick(_delta: float) -> void:
	if not _open and guard_passed():
		_open = true
		_set_buttons_enabled(true)
		focus_first()
	_update_stars()


func _set_buttons_enabled(on: bool) -> void:
	retry_button.disabled = not on
	level_select_button.disabled = not on
	next_button.disabled = not on or not bool(_data.get("next_enabled", true))
	_first_focus = next_button if not next_button.disabled else retry_button


func handle_input(event: InputEvent) -> bool:
	if not is_key_press(event):
		return false
	if not _open:
		return true
	if event.is_action_pressed("restart"):
		_finish_stars()
		retry_pressed.emit()
		return true
	if is_back(event):
		_finish_stars()
		level_select_pressed.emit()
		return true
	if event.is_action_pressed("ui_accept"):
		_finish_stars()
		if next_button.disabled:
			retry_pressed.emit()
		else:
			next_pressed.emit()
		return true
	return false


func overflow_sample() -> void:
	var keys: Array = []
	for i in int(Balance.get_section("rules").get("tasks_max", 0)):
		keys.append("menu.result.lost")
	setup({"won": false, "stars": 0, "time_left": 0.0, "missing_keys": keys, "next_enabled": false})
	best_label.visible = true
	advance_time(guard_s)
