# Game flow, menus, progress and settings (BI-7)

`scenes/main.tscn` with `scripts/main.gd` is the game flow root. It holds one level instance below `LevelHost` (pausable) and the current menu screen below `UiLayer` (CanvasLayer `ui_layer` = 110 from `data/balance/flow.json`; layer order: feedback screen 5 < HUD 80 < announcer caption 90 < level error panel 100 < menus 110). Screens live in `scenes/ui/menus/` and `scripts/ui/menus/`, extend `MenuScreen` and only emit signals; every transition, the pause and restart keys, the menu music and progress recording happen in `main.gd`. Pure decisions (screens, Next and Back targets, guards, `m:ss`) are in `scripts/flow/flow_rules.gd`.

## Screens and keys

| Screen | Reached from | Mouse / keyboard | Esc | Other keys |
|---|---|---|---|---|
| Title | start | Play, Settings, language toggle (shows the other language by its own name), Credits, Quit | nothing | arrows, Tab, Enter |
| Level select | Title Play; pause or result "Level select" | one row tile per level, Back | back (title) | Enter starts an open level |
| Settings | Title, pause | English / Deutsch, Music and Effects sliders (0-100 %, step 5, 0 mutes), "Reduce screen shake and flashes", Back | back (title or pause) | arrows change a focused slider |
| Intro card | a level start from the level select or Next | click after the guard | closes (after the guard) | any key after `intro_guard_s`; the card closes on the release of that key or button and never by itself |
| Playing | intro closed, resume, restart | – | pause | R restarts in place |
| Pause | Esc while playing | Resume, Restart (R), Settings, Level select, Quit | resume | R restarts |
| Result | level won or lost | Retry (R), Next level, Level select (enabled after `result_input_delay_s`, at most 2 s) | level select | R retry, Enter next (retry when Next is disabled) |
| Credits | Title Credits; Next after winning the last level | click after the guard | back | any key returns (title, or level select after the campaign) |

A level is loaded with its intro card two clicks after the title (Play, tile); the card waits as long as the player needs (D-9, no timeout), and any key or click is the deliberate "Go!". A press after the guard arms the card and the release of the same key or button closes it, so the dismiss key is already up when the timer starts and never moves the castaway; a press during the guard or from before the card (the held Enter from the level select) never arms it. F (finish) reaches the level only while the tree is not paused, so it does nothing during the intro card, pause and result. The world is paused while the intro card, the pause menu or the result is shown, and the level timer starts only when the card is gone (`LevelBase.autostart = false`, `start_level()` on dismissal; `level_started` then plays the level music and the "Go!" announcer). Restart and retry skip the intro card and reuse the same level instance (`LevelBase.restart_level()`, `handle_restart_key = false` because the flow owns R). "Level select" from pause or result abandons the run; nothing is recorded for losses or abandoned runs. Quit flushes the settings and calls `Audio.quit_game()`.

The result screen is the only headline while it is open: `GameFlow.show_screen(RESULT)` puts the level into result mode (`LevelBase.set_result_mode`: HUD and world prompts hidden and restored on retry, the level cue hidden until its next cue, FeedbackDirector popup words suppressed while particles and puffs keep playing) and suppresses the announcer caption (the voice line still plays). Retry, Next and Level select end it; a freed level always unsuppresses the caption. Earned stars pop in once, one after another (`result_star_interval_s`, `result_star_pop_s`, `result_star_pop_scale` in `flow.json`, curve in `FlowRules.star_pop`), and stay; the whole animation fits within `result_input_delay_max_s` (checked by `tools/validate_credits.py`), reduce motion shows them at once and any button or key snaps them to the final look.

Next after a result (`FlowRules.next_after_result`): a win of the last campaign level leads to the credits ("Ending" music, D-2); a win leads to the next level; a loss leads to the next level only when it is already unlocked and built, otherwise Next is disabled and Enter retries.

Music: "title" on the title, level select and settings (outside a level), the level's own music in play, "ending" on the credits; settings opened from pause keep the level music.

## Campaign

`data/campaign.json` lists the level ids in unlock order: `l1_beach_camp`, `l2_farm_meadow`, `l3_jungle`, `l4_lagoon`, `l5_volcano_cliffs` (D-8). An id is the file stem of its level JSON with the `lN_` prefix, N being its 1-based position (checked by `tests/levels/test_level_data.py`). By convention level `<id>` is `scenes/levels/<id>.tscn` with `data/levels/<id>.json`; an entry may name other `scene` and `json` paths (test campaigns). The tile title is the `title_key` of the level JSON ("Level N" until the JSON exists); a level whose scene does not exist yet shows "Coming soon" and cannot be started. Music per D-2 is set in each level JSON: level_1, level_2, level_3, level_2, level_3.

`-- --campaign=<res path>` swaps the campaign file and `-- --level=<id>` boots straight into the intro card of an unlocked level (development and bot runs).

## Files

Both files live in the DataDir folder (`-- --data-dir=` beats `TFI_DATA_DIR` beats `user://`), are written atomically (`<file>.tmp`, then rename) by `JsonStore` and fall back to defaults when missing, empty or corrupt (a warning, never an error or crash). Every value is checked on its own; unknown keys are dropped; a newer `schema_version` gives the defaults.

`settings.json` (autoload `Settings`):

    {"schema_version": 1, "locale": "en", "music_volume": 1.0, "effects_volume": 1.0, "reduce_shake_flashes": false}

English on first start, volumes are linear 0..1 (0 mutes the bus; default `audio.default_volume`). Slider changes apply at once and are saved debounced (`settings_save_debounce_s`), flushed on drag end, when the settings close, on quit and on exit. The reduce toggle is written before `EventBus.settings_changed("reduce_shake_flashes")` is emitted, so the feedback director reads the new value.

`progress.json` (autoload `Progress`):

    {"schema_version": 1, "unlocked": ["l1_beach_camp", "l2_farm_meadow"],
     "levels": {"l1_beach_camp": {"won": true, "best_stars": 2, "best_time_s": 83.4}}}

Unlocks are derived from wins (the first level is always open, level N+1 opens when level N is won, a won level stays replayable); the stored `unlocked` list is informative only. Level i is unlocked only when level i-1 is won; wins are read in campaign order and stop at the first level that is not won, so a hand-edited file can never put stars on a locked level. Best stars (max) and best time (min completion time = timer length minus time left) are independent records. The result screen shows "New best!" only when an earlier record was beaten: a first win shows its stars and time without the mark.

## Layout and texts

The theme is built in code (`MenuTheme`) from `data/balance/flow.json` and the art palette: one display font for every text (`MenuTheme.FONT`, Kenney Future with fixed X, %, ß and en dash glyphs; headings and body differ only by size and colour), blue depth buttons, a 4 px high-contrast focus outline, buttons at least 64 px high; hovering a button focuses it. Vertical button stacks (title, pause) sit in one `MenuScreen.make_button_column()`, so every button takes the width of the widest one in the current language. Sliders draw no focus box of their own: `MenuScreen.add_focus_ring()` adds a `FocusRing` panel with the same outline that is visible while the slider has focus, and the hovered or focused grabber turns yellow as a second cue. Every menu text is an `i18n/menu.csv` key rendered with `I18n.t()` and re-rendered on `locale_changed`; an en dash renders as a hyphen. Pack and author names on the credits come from `data/credits.json`, generated from `assets/SOURCES.md` by `python tools/build_credits.py` (checked by `tools/validate_credits.py`, which also checks the flow balance limits).

`tests/support/clip_check.gd` is the reusable clip check (text width with stylebox margins and icon, wrapped height, trimming, viewport, clip ancestors, panel and enclosing button, sibling overlap); `tests/ui/test_menu_overflow.gd` runs it for every menu in English and German at 1280x720 and 1920x1080. Flow tests extend `tests/support/flow_case.gd` (per-test data folder below the test data root, fixture campaign, synthetic keys and clicks).

## Menu backdrop (BI-18)

Title, level select, settings and credits sit on a live island instead of the plain clear colour: `scenes/ui/backdrop/menu_island.tscn` (`MenuIsland`, `scripts/levels/menu_island.gd`) with the animated water (`water.gdshader` on `tile_73`, sized to cover the viewport in whole tiles), the textured beach and grass tiles of the levels (`island_tileset.tres`), decorative palms and four critters (chicken, pig, goat, parrot).

Ownership and lifecycle (`scripts/main.gd`):

| Moment | Backdrop |
|---|---|
| First menu screen without a level (`show_screen`) | created once (`_ensure_backdrop()`), child of the GameFlow root |
| Screen switch, Back, language toggle | untouched: same instance, critters keep walking, water time keeps running |
| `start_level_flow` (intro, play, pause, settings from pause, result) | hidden and `PROCESS_MODE_DISABLED` (frozen, never freed) |
| `_free_level` (level select, title, credits after the campaign) | visible and processing again |
| `-- --smoke` | never created |
| `-- --level=<id>` | not created while the CLI level runs; leaving it to the level select shows it like any menu |

`backdrop()` returns the instance (null before the first menu screen); tests set `cli_override` instead of real command-line arguments.

- Layers: `flow.backdrop_layer` (-10) is below the level canvas (0), the HUD, the announcer caption, the level error panel and the menus (`flow.ui_layer`). The menus keep their own transparent `Backdrop` panel when no level runs, so the island shows around the panel; the panel itself (`ui_panel` at `panel_alpha` 0.92) keeps ui_text and ui_accent above 4.5:1 even over white (`tests/ui/test_menu_contrast.gd`).
- Scale: the CanvasLayer is scaled by `flow.backdrop_scale` (0.5), so a 128 px tile shows as a 64 px cell and the 30 × 17 cell layout covers 1920 × 1080. Critter sprites are scaled by `flow.backdrop_critter_scale` on top of their kind's `sprite_scale` so they read at that size.
- Composition rule: the screen band x 420–1500 (the widest panel, the level select tiles) holds only water and plain sand; grass patches, palms and the critters' land rects stay in the left and right thirds (`tests/scenes/test_menu_island.gd`). Nothing takes input: the scene has no Control node, so clicks reach the menu buttons.
- Critters (`BackdropCritter`, `scripts/levels/backdrop_critter.gd`) tick the shared `AnimalBrain` with their position only (no castaway, no confine, so they wander and idle but never settle) and are clamped into their `land` rect by `LandRect`. They join no group, have no body, emit no EventBus signal and request no sound. Walking makes them hop (`backdrop_hop_hz`, `backdrop_hop_px`, above `backdrop_walk_min_speed`).
- Reduce motion: with "Reduce screen shake and flashes" (`reduce_shake_flashes`) on, the critter hop height is 0; walking and the slow water stay. The critters follow the setting live (`EventBus.settings_changed`).
- Palms are `palm.tscn` instances with `decorative = true`: they leave the `prop` group (declared statically in `palm.tscn`) and build no footprint, so tree-wide prop queries in flow tests never see them.
- Rebuild the tiles after editing `scenes/ui/backdrop/menu_island.layout.txt`:

```
godot --headless --path . --script res://tools/build_level_layout.gd -- --layout=res://scenes/ui/backdrop/menu_island.layout.txt --scene=res://scenes/ui/backdrop/menu_island.tscn
```

- Leaving a level clears the announcer queue (`Audio.clear_announcer()` in `_free_level`), so a line the level queued (for example the loss taunt behind the result screen) can no longer show its caption over the level select or the credits (QA-2).
- Perf: the windowed perf stage also records `perf_menu_seconds` on the title at 1920 × 1080 (`perf_title_1920x1080.json`, no frame above 33 ms after the first second). Visual check of menu shots: `python tools/flat_area_check.py <dir> --glob "*_title_*.png" --mask-x 0.21,0.79 --no-hud`.
