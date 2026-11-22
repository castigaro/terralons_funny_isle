# HUD, contextual prompts, hints and failure cues (BI-6)

The in-level HUD always shows what to do, how much time is left and why something went wrong. It reads the `LevelSession` every frame, reacts to EventBus signals and never changes the session (the finish key goes through `LevelBase.finish_level()`).

## Files

| File | Class | Purpose |
|---|---|---|
| `scripts/ui/hud.gd`, `scenes/ui/hud.tscn` | `Hud` | CanvasLayer under `LevelBase/Overlay/Hud`: task list, timer with warning, 3-star goal line, hint button and panel, failure cue, "Finish!" banner, interact prompt, occlusion fade. |
| `scripts/ui/hud_model.gd` | `HudModel` | Pure logic: `m:ss` format, warning check, hint order, failure classification from `data/hud.json`, cue throttle, prompt dismiss actions. |
| `scripts/ui/context_prompt.gd`, `scenes/ui/context_prompt.tscn` | `ContextPrompt` | World-space key prompt bubble from level data, follows its anchor. |
| `scripts/ui/prompt_memory.gd` | `PromptMemory` | Prompt actions used in this game process (never saved). |
| `scripts/ui/key_cap.gd`, `scenes/ui/key_cap.tscn` | `KeyCap` | Key cap showing the first key of input actions from the InputMap. |
| `data/hud.json` | – | Failure types (key, icon, triggering signals), priority list, interact verbs. |
| `data/balance/hud.json` | – | Layout, font sizes, durations, pulse, occlusion and prompt tuning (namespace `hud`). |
| `i18n/hud.csv` | – | All HUD texts (`hud.*`) in EN and DE. |

## Layout

Logical 1920x1080 coordinates, scaled uniformly to the visible area: task panel and hint row top-left, timer with the 3-star goal line top-right, failure cue below the timer, "Finish!" banner and interact prompt bottom-centre. The `LevelCue` ("Go!", "Restarted!") stays top-centre on its own layer. Panels the castaway walks under fade to `occlude_alpha` within `occlude_fade_seconds`. The HUD layer (80) lies between the feedback screen layer and the `LevelCue` layer. No survival stats.

- Task rows: required/optional star, translated tag (`hud.required`/`hud.optional`), title (`title_key`, else `hint_key`) on one line in a column as wide as the widest current title, capped at `task_name_width_px` (440 logical px, `task_name_max_lines` 1; the column follows level and locale, an ellipsis is only a safety net – `tests/ui/test_hud_task_title_width.gd` measures every EN and DE title against the 440 px budget and fails if the cap grows, so titles that do not fit are shortened in `i18n/level.csv`); the tag column is the widest tag plus `tag_gap_px` (14), so every title starts at the same x, `cur/target`, check or cross once done or missed.
- Timer: `m:ss`, rounded up; in the last `rules.timer_warning_seconds` it turns `ui_warning` and pulses; the reduce flashes setting keeps the colour without pulse.
- 3-star goal: three stars plus `hud.star_goal` ("needs m:ss left" / "braucht m:ss Rest") right of the timer, one line. The value is `LevelSession.three_star_time()` and follows the level's `three_star_share` override; the timer panel tooltip (`hud.star_goal_tip`) holds the long explanation. `HudModel.star_goal_state()` picks one of three states:
  - REACHABLE: time left at or above the threshold (inclusive, same EPSILON as `Stars.compute`), no task missed, not lost – full stars, normal colour, no tick.
  - MISSED: time left below the threshold, any task missed (optional ones too) or the level lost – outline stars and the label at `star_goal_missed_alpha` (0.6, still about 5:1 contrast on the panel); one-way, since time only goes down and missed and lost are final.
  - SECURED: only when the level is won with 3 stars – full stars plus a tick. The tick never shows while running or after the required tasks are done. When the tick appears or the label text changes, the HUD re-lays out the timer panel at once, so it stays inside the screen margin on the result screen, where the paused tree no longer runs `_process`.
  Layout keys in `data/balance/hud.json`: `star_goal_font_size` (28), `star_goal_icon_px` (28), `star_goal_gap_px` (8, space between the stars and the label), `star_goal_missed_alpha` (0.6).

## Hints

H (action `hint`) or the hint button shows the hint of the first open required task, then the first open optional one, else `hud.hint.none`, for `hint_seconds`. The timer keeps running. Nothing happens while the game is paused; restart, win and loss close the hint.

## Failure cues

`data/hud.json` maps each failure type to a text key, an icon and EventBus triggers:

| Type | Trigger |
|---|---|
| `animal_escaped` | `entity_lost` with an animal kind |
| `item_lost_sea` | `entity_lost` with an item kind and reason `water` or `bounds` |
| `time_up` | `level_lost` (priority: never replaced while visible) |
| `dizzy_hit` | `castaway_dizzy_started` |
| `event_stole` | `event_triggered` of a scheduled event whose type has `take_held` (castaway holds something), `take_worn` (castaway wears something) or `steal_wearable` (castaway wears something or holds a wearable item); a loose item stolen from the ground shows no cue (warning cue, actor, sound and popup tell it) |

An `event_warning` shows the cue `hud.cue.warn.<event_type>` (exclamation icon) for `cue_seconds` (2.5 s) through the same throttle; types without a key show nothing. The warning sound stays at the trigger (BI-9).

An open task whose conditions name the involved kind replaces the generic text with its `fail_key`. One cue shows at a time for `cue_seconds`; the same key within `cue_min_interval` only extends it. The funny reaction itself comes from the FeedbackDirector (BI-8).

## Contextual prompts

Level data may list prompts: `{"id": "pr_move", "anchor": "player" | "zone:<id>" | "entity:<uid>" | "target:<target_kind>", "action": "move" | "dash" | "grab" | "throw" | "use", "text_key": "..."}`. `LevelBase` spawns one `ContextPrompt` per entry under `Prompts`. Once the action is used (`castaway_step`, `castaway_dashed`, `object_grabbed`, `object_thrown`, `object_used`), every prompt with that action disappears for the rest of the game process, also after restarts. `target:<target_kind>` resolves to the first use target of the level (group `use_target`, tree order) with that `target_kind`. An anchor that does not exist in the scene is skipped, listed in `LevelBase.prompt_problems()` and printed once; the level keeps running. `tools/validate_levels.py` and `LevelDef` check the fields, ids, anchor pattern, action and EN/DE texts. The bubble sits `prompt_offset_px` above its anchor; when it would touch a visible HUD panel (grown by `prompt_hud_gap_px`) or leave the top edge, it flips `prompt_below_offset_px` below the anchor, unless that spot is blocked as well (then it stays above). Without a HUD it always sits above. `tests/support/clip_check.gd` `check_hud_prompts()` fails when a visible bubble overlaps a HUD panel (headless in `tests/ui/test_hud_prompt_overlap.gd`, windowed in the clip stage).

## Finish banner (D-3)

When the required tasks are done and optional ones are still open (`rules.auto_finish_when_all_done` only wins when all tasks are done), the banner `hud.banner.finish` shows with the finish key; the finish action ends the level as won. Before that the key does nothing. Restart, win and loss hide the banner.

## Tests

`tests/ui/test_hud_*.gd` and `tests/ui/test_context_prompts.gd` cover the model, rows, timer, warning, hint, banner, cues, prompts, layout at 1280x720 and 1920x1080, live language switch and a German overflow check with the longest fixture texts.
