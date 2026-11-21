extends "res://tests/support/level_case.gd"
## Contextual key prompts from level data: spawn per anchor type, vanish for the run once their action was used
## (all prompts of that action), stay gone after a restart; an unresolved anchor is skipped without an error panel.

const UNRESOLVED := "res://tests/fixtures/levels/valid_prompt_unresolved_anchor.json"
const PROMPT_SCENE := preload("res://scenes/ui/context_prompt.tscn")


func before_each() -> void:
	PromptMemory.reset()


func _ids() -> Array:
	var out: Array = []
	for p in level.prompts():
		out.append((p as ContextPrompt).prompt_id)
	out.sort()
	return out


func test_prompts_spawn_per_anchor_type() -> void:
	await open_level()
	await frames(1)
	check_eq(_ids(), ["pr_grab_chicken", "pr_move", "pr_use_zone"], "one prompt per level entry")
	var expect := {"pr_move": level.castaway(), "pr_grab_chicken": level.entity_registry().find_uid("chicken_1"),
			"pr_use_zone": level.zone("zone_a")}
	var offset := float(Balance.get_value("hud", "prompt_offset_px"))
	for p in level.prompts():
		var prompt := p as ContextPrompt
		check(prompt.anchor() == expect[prompt.prompt_id], "%s anchor" % prompt.prompt_id)
		check_eq(prompt.label().text, level.text(prompt.text_key), "%s text" % prompt.prompt_id)
		check(prompt.key_cap().label_text() != "", "%s key cap" % prompt.prompt_id)
		check(prompt.global_position.distance_to(prompt.anchor().global_position + Vector2(0, -offset)) < 0.5,
				"%s follows its anchor" % prompt.prompt_id)
		check(prompt.visible, "%s visible" % prompt.prompt_id)
	var move := level.get_node("Prompts/Prompt_pr_move") as ContextPrompt
	check_eq(move.key_cap().label_text(), "WASD", "move prompt shows the move keys")


func test_used_action_removes_only_its_prompts_for_the_run() -> void:
	await open_level()
	await frames(1)
	var extra := PROMPT_SCENE.instantiate() as ContextPrompt
	extra.setup({"id": "pr_grab_extra", "anchor": "entity:coconut_1", "action": "grab",
			"text_key": "fixture.prompt_grab"}, level.entity_registry().find_uid("coconut_1"), level)
	level.get_node("Prompts").add_child(extra)
	await frames(1)
	check_eq(_ids().size(), 4, "extra grab prompt added")
	EventBus.object_grabbed.emit("coconut")
	await frames(1)
	check_eq(_ids(), ["pr_move", "pr_use_zone"], "every grab prompt vanished, others stay")
	check(PromptMemory.is_used("grab"), "grab remembered")
	# real movement emits castaway_step and removes the move prompt
	move = Vector2.RIGHT
	await physics_frames(40)
	move = Vector2.ZERO
	await frames(1)
	check_eq(_ids(), ["pr_use_zone"], "walking removed the move prompt")
	level.restart_level()
	await frames(1)
	check_eq(_ids(), ["pr_use_zone"], "used prompts stay gone after restart, unused ones return")
	EventBus.object_used.emit("coconut", "zone")
	await frames(1)
	check_eq(_ids(), [], "use removes the last prompt")
	level.restart_level()
	await frames(1)
	check_eq(_ids(), [], "nothing comes back")


func test_dash_and_throw_map_to_their_actions() -> void:
	check_eq(HudModel.prompt_dismiss_action("castaway_dashed"), "dash", "dash")
	check_eq(HudModel.prompt_dismiss_action("object_thrown"), "throw", "throw")
	check_eq(HudModel.prompt_dismiss_action("castaway_step"), "move", "move")
	check_eq(HudModel.prompt_dismiss_action("object_bonked"), "", "unrelated signal")
	await open_level()
	await frames(1)
	for action in ["dash", "throw"]:
		var p := PROMPT_SCENE.instantiate() as ContextPrompt
		p.setup({"id": "pr_" + action, "anchor": "player", "action": action, "text_key": "fixture.prompt_" + action},
				level.castaway(), level)
		level.get_node("Prompts").add_child(p)
	await frames(1)
	EventBus.castaway_dashed.emit(Vector2.ZERO, Vector2.RIGHT)
	await frames(1)
	check_false(_ids().has("pr_dash"), "dash prompt gone")
	check(_ids().has("pr_throw"), "throw prompt stays")
	EventBus.object_thrown.emit("coconut")
	await frames(1)
	check_false(_ids().has("pr_throw"), "throw prompt gone")


func test_unresolved_anchor_is_skipped_without_error_panel() -> void:
	await open_level(SAMPLE_LEVEL, {"level_json_path": UNRESOLVED})
	await frames(1)
	check_false(level.is_failed(), "level keeps running")
	check_false((level.get_node("Overlay/LevelErrorPanel") as CanvasLayer).visible, "no error panel")
	check_eq(level.level_session().get_state(), LevelSession.State.RUNNING, "session running")
	check_eq(_ids(), [], "prompt skipped")
	var problems := level.prompt_problems()
	check_eq(problems.size(), 1, "one problem recorded")
	check(String(problems[0]).contains("unicorn_9"), "problem names the anchor")
	level.restart_level()
	await frames(1)
	check_eq(level.prompt_problems().size(), 1, "recorded once")
