extends "res://tests/support/level_case.gd"
## World key prompts stay clear of the HUD panels: in L1 (EN and DE, 1280x720 and 1920x1080) no visible bubble
## overlaps a panel, a bubble under the task panel flips below its anchor and back, and without a HUD it stays above.

const ClipCheck := preload("res://tests/support/clip_check.gd")
const L1 := "res://scenes/levels/l1_beach_camp.tscn"
const PROMPT_SCENE := preload("res://scenes/ui/context_prompt.tscn")
const SIZES := [Vector2(1280, 720), Vector2(1920, 1080)]


func before_each() -> void:
	PromptMemory.reset()


func after_each() -> void:
	super()
	I18n.set_locale("en")


func _prompt(id: String) -> ContextPrompt:
	for p in level.prompts():
		if (p as ContextPrompt).prompt_id == id:
			return p
	return null


func test_l1_prompts_clear_of_hud_panels() -> void:
	await open_level(L1, {"autostart": false})
	var hud := level.hud()
	for loc in ["en", "de"]:
		I18n.set_locale(loc)
		for view in SIZES:
			hud.set_layout_size(view)
			await frames(2)
			var tag := "L1 %s %dx%d" % [loc, view.x, view.y]
			var use := _prompt("pr_use")
			check(use != null and use.is_visible_in_tree(), "%s use prompt visible" % tag)
			var errors := ClipCheck.check_hud_prompts(hud, level.prompts(), tag)
			check(errors.is_empty(), "%s no prompt under a panel: %s" % [tag, "; ".join(errors)])
	hud.set_layout_size(Vector2.ZERO)


func _world_at(screen: Vector2) -> Vector2:
	return level.get_viewport().get_canvas_transform().affine_inverse() * screen


func test_prompt_flips_below_when_under_panel() -> void:
	await open_level()
	await frames(1)
	var hud := level.hud()
	var anchor := Node2D.new()
	anchor.name = "FlipAnchor"
	level.add_child(anchor)
	var prompt := PROMPT_SCENE.instantiate() as ContextPrompt
	prompt.setup({"id": "pr_flip", "anchor": "zone:none", "action": "grab", "text_key": "fixture.prompt_grab"},
			anchor, level)
	level.get_node("Prompts").add_child(prompt)
	var task_rect := hud.panel("TaskPanel").get_global_rect()
	anchor.global_position = _world_at(Vector2(task_rect.get_center().x, task_rect.end.y - 8.0))
	await frames(2)
	check(prompt.placed_below(), "bubble under the task panel flips below its anchor")
	var below := float(Balance.get_value("hud", "prompt_below_offset_px"))
	check(prompt.global_position.distance_to(anchor.global_position + Vector2(0, below)) < 0.5,
			"flipped bubble sits prompt_below_offset_px below the anchor")
	var errors := ClipCheck.check_hud_prompts(hud, [prompt], "flipped")
	check(errors.is_empty(), "flipped bubble clear of the panels: %s" % "; ".join(errors))
	var view := level.get_viewport().get_visible_rect().size
	anchor.global_position = _world_at(view / 2.0)
	await frames(2)
	check_false(prompt.placed_below(), "bubble in the open field sits above again")
	var above := float(Balance.get_value("hud", "prompt_offset_px"))
	check(prompt.global_position.distance_to(anchor.global_position + Vector2(0, -above)) < 0.5,
			"bubble back at prompt_offset_px above the anchor")


func test_prompt_without_hud_unchanged() -> void:
	var host := Node2D.new()
	add_node(host)
	var anchor := Node2D.new()
	anchor.position = Vector2(200, 20)
	host.add_child(anchor)
	var prompt := PROMPT_SCENE.instantiate() as ContextPrompt
	prompt.setup({"id": "pr_bare", "anchor": "player", "action": "grab", "text_key": "fixture.prompt_grab"}, anchor)
	host.add_child(prompt)
	await frames(2)
	var above := float(Balance.get_value("hud", "prompt_offset_px"))
	check_false(prompt.placed_below(), "no HUD: never flipped")
	check(prompt.global_position.distance_to(anchor.global_position + Vector2(0, -above)) < 0.5,
			"no HUD: bubble prompt_offset_px above the anchor")
