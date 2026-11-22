extends "res://tests/support/level_case.gd"
## HUD layout at 1280x720 and 1920x1080: every panel inside the screen, no two visible panels overlap with all
## panels shown, the hint button is at least 44 px, task titles fit on one line without ellipsis, the task panel
## keeps a gap to the timer, and panels under the castaway fade out and back in.

const SIZES := [Vector2(1280, 720), Vector2(1920, 1080)]
const MIN_TOUCH_PX := 44.0
const MIN_TIMER_GAP_PX := 16.0
const L1 := "res://scenes/levels/l1_beach_camp.tscn"


static func check_layout(t: TestCase, hud: Hud, view: Vector2, tag: String) -> void:
	var rects := hud.panel_rects()
	var screen := Rect2(Vector2.ZERO, view)
	for name in rects:
		var r: Rect2 = rects[name]
		t.check(screen.grow(0.5).encloses(r), "%s %s inside the screen: %s" % [tag, name, str(r)])
	var names := rects.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = rects[names[i]]
			var b: Rect2 = rects[names[j]]
			t.check(not a.grow(-0.5).intersects(b.grow(-0.5)), "%s %s overlaps %s" % [tag, names[i], names[j]])
	_check_star_goal(t, hud, tag)


## The 3-star goal line is one unclipped line inside the timer panel, right of the timer and clear of the cue slot.
static func _check_star_goal(t: TestCase, hud: Hud, tag: String) -> void:
	var label := hud.panel("StarGoalLabel") as Label
	if label == null or not label.is_visible_in_tree():
		return
	t.check_eq(label.get_line_count(), 1, "%s star goal one line" % tag)
	var font := label.get_theme_font("font")
	var w := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	t.check(w <= label.size.x + 1.0, "%s star goal fits: %.1f > %.1f" % [tag, w, label.size.x])
	var star_rect := label.get_global_rect()
	t.check(hud.panel("TimerPanel").get_global_rect().grow(0.5).encloses(star_rect), "%s star goal inside the timer panel" % tag)
	t.check(star_rect.position.x >= hud.timer_label().get_global_rect().end.x - 0.5, "%s star goal right of the timer" % tag)
	var cue := hud.panel("CueSlot")
	if cue != null and cue.is_visible_in_tree():
		t.check(not hud.panel("TimerPanel").get_global_rect().grow(-0.5).intersects(cue.get_global_rect().grow(-0.5)),
				"%s timer panel clear of the cue slot" % tag)


## Every task title is one line whose text fits the label (no ellipsis) and the task panel ends left of the timer.
static func check_task_titles(t: TestCase, hud: Hud, tag: String) -> void:
	var labels := hud.panel("TaskPanel").find_children("NameLabel", "Label", true, false)
	t.check(labels.size() > 0, "%s task titles found" % tag)
	for node in labels:
		var label := node as Label
		t.check_eq(label.get_line_count(), 1, "%s '%s' on one line" % [tag, label.text])
		var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				label.get_theme_font_size("font_size")).x
		t.check(width <= label.size.x, "%s '%s' fits without ellipsis: %.0f <= %.0f" % [tag, label.text, width,
				label.size.x])
	_check_columns(t, labels, tag)
	var gap := hud.panel("TimerPanel").get_global_rect().position.x - hud.panel("TaskPanel").get_global_rect().end.x
	t.check(gap >= MIN_TIMER_GAP_PX, "%s task panel %.0f px left of the timer" % [tag, gap])


## The name column is as wide as the widest title (capped) and every title keeps tag_gap_px from its tag.
static func _check_columns(t: TestCase, labels: Array, tag: String) -> void:
	var cap := float(Balance.get_value("hud", "task_name_width_px"))
	var tag_gap := float(Balance.get_value("hud", "tag_gap_px"))
	var widest := 0.0
	for node in labels:
		var label := node as Label
		var w := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				label.get_theme_font_size("font_size")).x
		widest = maxf(widest, ceilf(w) + 2.0)
	var expected := minf(cap, widest)
	for node in labels:
		var label := node as Label
		t.check(absf(label.size.x - expected) <= 1.0, "%s '%s' column width %.0f == %.0f" % [tag, label.text,
				label.size.x, expected])
		var tag_label := label.get_parent().get_node("TagLabel") as Label
		var tag_w := tag_label.get_theme_font("font").get_string_size(tag_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				tag_label.get_theme_font_size("font_size")).x
		var gap := label.position.x - (tag_label.position.x + tag_w)
		t.check(gap >= tag_gap - 0.5, "%s '%s' starts %.1f px after its tag (>= %.0f)" % [tag, label.text, gap, tag_gap])


func test_panels_inside_and_apart_at_both_sizes() -> void:
	await open_level()
	var hud := level.hud()
	for view in SIZES:
		hud.set_layout_size(view)
		hud.show_hint()
		hud.on_failure_signal("castaway_dizzy_started", ["coconut"])
		await frames(1)
		var tag := "%dx%d live" % [view.x, view.y]
		for name in ["TaskPanel", "HintButton", "HintPanel", "TimerPanel", "CueSlot"]:
			check(hud.panel_rects().has(name), "%s %s visible" % [tag, name])
		check_layout(self, hud, view, tag)
		var hb := hud.hint_button().get_global_rect().size
		check(hb.x >= MIN_TOUCH_PX and hb.y >= MIN_TOUCH_PX, "%s hint button %s >= 44 px" % [tag, str(hb)])
		check_task_titles(self, hud, tag)
	for view in SIZES:
		hud.set_layout_size(view)
		hud.overflow_sample()
		await frames(1)
		var tag := "%dx%d full" % [view.x, view.y]
		for name in ["TaskPanel", "HintPanel", "TimerPanel", "CueSlot", "FinishBanner", "InteractPrompt"]:
			check(hud.panel_rects().has(name), "%s %s visible" % [tag, name])
		check_layout(self, hud, view, tag)


func test_task_columns_in_both_locales_on_l1() -> void:
	await open_level(L1)
	var hud := level.hud()
	for loc in ["en", "de"]:
		I18n.set_locale(loc)
		for view in SIZES:
			hud.set_layout_size(view)
			await frames(1)
			check_task_titles(self, hud, "L1 %s %dx%d" % [loc, view.x, view.y])
	I18n.set_locale("en")


func test_panel_fades_under_the_castaway() -> void:
	await open_level()
	var hud := level.hud()
	await frames(2)
	check_eq(hud.panel_alpha("TaskPanel"), 1.0, "opaque while the castaway is away")
	var real := hud.castaway_screen_rect()
	check(real.size != Vector2.ZERO, "castaway rect from the sprite")
	check(_castaway_clear_of_panels(hud, real), "castaway clear of every panel at spawn")
	var task_rect := hud.panel("TaskPanel").get_global_rect()
	hud.force_castaway_rect(Rect2(task_rect.get_center() - real.size / 2.0, real.size))
	await frames(1)
	check(hud.castaway_safe_rect().intersects(task_rect), "castaway under the task panel")
	var fade := float(Balance.get_value("hud", "occlude_fade_seconds"))
	await frames(int(ceil(fade * 60.0)) + 2)
	check(absf(hud.panel_alpha("TaskPanel") - float(Balance.get_value("hud", "occlude_alpha"))) < 0.01,
			"faded to occlude_alpha: %f" % hud.panel_alpha("TaskPanel"))
	check_eq(hud.panel_alpha("TimerPanel"), 1.0, "other panels stay opaque")
	hud.force_castaway_rect(Rect2())
	await frames(int(ceil(fade * 60.0)) + 2)
	check_eq(hud.panel_alpha("TaskPanel"), 1.0, "opaque again after moving away")


## The real castaway rect does not touch any HUD panel at spawn.
func _castaway_clear_of_panels(hud: Hud, rect: Rect2) -> bool:
	for r in hud.visible_panel_rects():
		if (r as Rect2).intersects(hud.castaway_safe_rect()):
			return false
	return rect.size != Vector2.ZERO


func test_star_goal_tick_fits_when_paused() -> void:
	await open_level(L1)
	var hud := level.hud()
	var gap_px := float(Balance.get_value("hud", "star_goal_gap_px"))
	for loc in ["en", "de"]:
		for view in SIZES:
			var tag := "L1 %s %dx%d secured" % [loc, view.x, view.y]
			level.restart_level()
			await frames(2)
			I18n.set_locale(loc)
			hud.set_layout_size(view)
			hud.set_process(false)
			await _win_with_all_tasks(tag)
			check_eq(hud.star_goal_state(), HudModel.StarGoal.SECURED, "%s state" % tag)
			var tick := hud.panel("StarGoalState")
			check(tick.visible, "%s tick visible" % tag)
			check(hud.panel("TimerPanel").get_global_rect().grow(0.5).encloses(tick.get_global_rect()),
					"%s tick inside the timer panel" % tag)
			var last_star := hud.panel(Hud.STAR_GOAL_ICONS[-1]).get_global_rect()
			var gap := hud.panel("StarGoalLabel").get_global_rect().position.x - last_star.end.x
			check(gap >= gap_px * hud.root_control().scale.x - 0.5, "%s label %.1f px after the stars" % [tag, gap])
			check_layout(self, hud, view, tag)
			hud.set_process(true)
	I18n.set_locale("en")
	hud.set_layout_size(Vector2.ZERO)


## Marks every task done and finishes the level, so the session wins with 3 stars.
func _win_with_all_tasks(tag: String) -> void:
	var session := level.level_session()
	for st in session.get("_tasks"):
		st["done"] = true
	await physics_frames(2)
	await frames(1)
	if session.get_state() != LevelSession.State.WON:
		var ev := InputEventAction.new()
		ev.action = &"finish"
		ev.pressed = true
		root().push_input(ev)
		await frames(2)
	check_eq(session.get_state(), LevelSession.State.WON, "%s won" % tag)
	check_eq(int(session.result().get("stars", 0)), 3, "%s three stars" % tag)
