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

The theme is built in code (`MenuTheme`) from `data/balance/flow.json` and the art palette: Kenney Future for headings and buttons, Kenney Future Narrow for body text, blue depth buttons, a 4 px high-contrast focus outline, buttons at least 64 px high; hovering a button focuses it. Vertical button stacks (title, pause) sit in one `MenuScreen.make_button_column()`, so every button takes the width of the widest one in the current language. Sliders draw no focus box of their own: `MenuScreen.add_focus_ring()` adds a `FocusRing` panel with the same outline that is visible while the slider has focus, and the hovered or focused grabber turns yellow as a second cue. Every menu text is an `i18n/menu.csv` key rendered with `I18n.t()` and re-rendered on `locale_changed`; player-visible texts use a hyphen because the fonts have no en dash. Pack and author names on the credits come from `data/credits.json`, generated from `assets/SOURCES.md` by `python tools/build_credits.py` (checked by `tools/validate_credits.py`, which also checks the flow balance limits).

`tests/support/clip_check.gd` is the reusable clip check (text width with stylebox margins and icon, wrapped height, trimming, viewport, clip ancestors, panel and enclosing button, sibling overlap); `tests/ui/test_menu_overflow.gd` runs it for every menu in English and German at 1280x720 and 1920x1080. Flow tests extend `tests/support/flow_case.gd` (per-test data folder below the test data root, fixture campaign, synthetic keys and clicks).
