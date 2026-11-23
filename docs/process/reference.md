# Reference product – Terralon's Funny Isle 0.1.0

Path: `<reference repo>` (read only – never change, build, install or write anything there; carry its behaviour over, do not copy its code verbatim).

## Purpose and users

Offline, turn-based Windows desktop game (Godot 4.7.2 GDScript, Python stdlib tooling). A hapless castaway explores a seeded procedural 24x24 island and completes absurd daily task cards (e.g. two chickens into a cage). Target: cozy/casual strategy players, 20–40 min runs, no game over. Personas are inferred; no real playtesters ever.

## Features

C = core for v2 idea, O = optional/drop.

| Feature | Details | Verdict |
|---|---|---|
| Turn loop | 8 turns/day, 4 action points, End Turn (Space), tile-by-tile click/WASD movement with path preview | DROP (replaced by real-time) |
| Procedural map | 24x24 (water/beach/grass/forest/rocks), connectivity-checked over 200 seeds | O (v2 has handcrafted levels) |
| Fog of war | Chebyshev radius 2 | DROP |
| Survival | hunger, energy, rest, forage, funny faint | DROP (forbidden) |
| Task engine | JSON pool of 40+ tasks, 6 categories (carry, lure, combine, deliver, explore, perform), declarative conditions (holding, wearing, held_in, entity_on, adjacent, player_on, explored, emote) and modifiers (wearing_hat, before_turn, at_camp); dealing with solvability gating; skip, hint, fail-forward texts, task log/tracker UI | C (engine and data-driven JSON schema, retargeted to real-time; hint is useful). Emote dance/sing/pose – O |
| Items/animals | chicken, goat, crab; stick, rope, corn, hat, bucket, cage; pick up, carry (6 slots), set down, wear hat, craft (recipes.json, e.g. cage = 2 sticks + rope), containers, luring with corn, wandering actors, headbutts | C for grab/carry/containers/lure/hat; inventory slots and crafting O |
| Comic presentation | theme, halftone shader, sound-word popups (BONK style), speech bubbles, day panels, pause menu, settings, confirm dialog | C for sound words, bubbles, pause, settings; halftone and day panels O |
| EN/DE | CSV i18n (key,en,de per area; 4 files, about 460 rows), live switch, stored in settings.json | C |
| Tooling | play.py, run_tests.py, export.py, validators (i18n, code rules, tasks, assets), capture_screenshot | C (explicitly to be reused) |
| Plugin architecture | `features/<id>/feature.gd`, Capabilities and Actions registries, EventBus, HUD slots | O (heavy for a real-time game; keep EventBus idea) |

## Main flows and screens

Main menu (New Game, Settings, Quit, language toggle) – game screen (map, HUD with day/turn/AP/energy/hunger, action bar with keys 1–9, task tracker side panel, Tab task log, I inventory) – pause (Esc) – settings (language, halftone) – leave confirm. Day caption panel at day start. No level select, result screen, scoring, stars, audio, or save/load.

## Data model and storage

- GameState (seed, RNG state, map, explored/depleted tiles, player stats, day/turn, entities with id/type/cell/holder_id/flags), JSON-serialisable with format_version (round-trip tested) – but no save slots (BI-5 open); only settings.json persists.
- Data files: `data/entities.json`, `recipes.json`, `tasks.json`, `palette.json`, `data/balance/{core,tasks,actors}.json` merged by Balance autoload; `i18n/*.csv`.
- Data dir is `user://` overridable via `-- --data-dir=` or `TFI_DATA_DIR` (CLI wins); tests redirect APPDATA/LOCALAPPDATA/TFI_DATA_DIR under testdata.

## Platform and interfaces

Windows, offline, no network. Godot found via `GODOT_BIN` or WinGet default; GL Compatibility renderer, 1280x720 canvas_items stretch. Export preset "Windows Desktop" -> `build/TerralonsFunnyIsle.exe` (single file, include_filter json/csv; CSVs use importer "keep" and are read raw by I18n). `tools/export.py` also smoke-tests the exe. Input map predefined in `project.godot` (move_*, end_turn, task_log, inventory, fast_forward, undo, pause, help, emote).

## Quality notes

- Strong: about 70 headless GDScript test files (custom runner.gd, one process per file, 60 s watchdog) plus about 87 Python tests; run_tests.py stages (syntax, import, gd tests, py tests, smoke, validators, hygiene); solvability oracle over 200 seeds; overflow tests for German clipping; tests never touch user folders; Windows exe previously built (build/ contains an exe even though the report says no preset existed – CHANGELOG and README disagree, README is newer).
- Weaknesses: all art is procedural placeholder shapes, no third-party assets, no audio at all; felt like a slow chess game (core UX complaint); tile-based 1280x720 baseline too small for large sprites; 40 of the tasks are mostly trivial "stand on terrain / hold item" checks; windowed bugs (z-order, focus, layout jumps) were found only by manual windowed probes; known nits: stale HUD message, path label covering castaway, calm chickens not marked, `--smoke` fails for 8+ turns, no tutorial, no save slots, no undo, no accessibility/help overlay, no key rebinding.
- Code rules enforced by validate_code.py (comments English, en dash); no-task-specific-code test keeps the task engine generic.

## Reuse recommendation

Reuse verbatim-in-behaviour: `tools/play.py`, `run_tests.py`, `export.py`, `common.py`, `validate_i18n`/assets, `tests/runner.gd` + `test_case.gd`, Balance and I18n autoloads, data-dir override, export preset. Rewrite: GameState, map, fog, turn rules, pathing, UI, rendering, all gameplay. Port the task schema (conditions/modifiers/fail-forward, JSON-driven) to real-time objectives and keep the comic sound-word concept (BONK, SPLAT).

## Objections

None to the binding constraints. Note: the old project has no audio or save system at all, so v2 settings/progress persistence is new work beyond the reusable settings.json pattern.
