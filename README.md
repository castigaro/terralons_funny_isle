# Terralon's Funny Isle 2

A hectic, single-player, keyboard-first slapstick action game for Windows (Godot 4.7.2, GDScript, offline, English and German). A castaway runs, dashes, grabs, carries and throws animals and items across five handcrafted tropical island levels against a 3–5 minute timer while funny tasks and slapstick events keep going wrong. Version 2 replaces the turn-based survival game of v1 with real-time action, polished CC0 art and full audio.

## Start

    python tools/play.py              # windowed game
    python tools/play.py --sandbox    # same, but APPDATA and the data folder go to <testdata>/play

Godot 4.7.2 is found in the WinGet folder or via the environment variable `GODOT_BIN`. On the first start the project is imported headless. Arguments after `--` go to the game, for example `-- --data-dir=<path>`.

## Check (build, lint, tests)

    python tools/run_tests.py [-k <substring>]

Stages: syntax (Python), headless Godot import, GDScript tests (`tests/**/test_*.gd` through `tests/runner.gd`), Python tests (`tests/**/test_*.py`), headless smoke start (`-- --smoke` must print `SMOKE OK`), all `tools/validate_*.py`, and hygiene (git status and the real user folder must be unchanged). Exit code 0 means all green, 1 any failure, 2 Godot missing.

Test data never goes to user folders: every Godot process of a test run gets `APPDATA`, `LOCALAPPDATA` and `TFI_DATA_DIR` redirected below the testdata root – `<repo>.testdata/run_tests` for the main checkout, `<main>.testdata/<worktree>/run_tests` for a worktree, or `$TFI_TESTDATA/run_tests`. Folders below `tests/fixtures/` and `tests/support/` are not collected as tests; `tests/fixtures/runner/` holds deliberately failing files for the runner self-test.

GDScript tests run with `--fixed-fps 60` (deterministic physics ticks; a file whose first lines contain `## run-fps: 60,144` runs once per listed frame rate, and `TestCase.run_fps()` tells it which) and extend `TestCase` (`check`, `check_eq`, `check_has`, `fail`, `add_node`, `frames`, `physics_frames`); `before_each`/`after_each` hooks and coroutine tests are supported. Between tests `tests/support/test_env.gd` unpauses the tree, releases the castaway input actions, clears Balance overrides, switches I18n back to English and resets the Settings and Progress autoloads in memory. `tests/support/signal_recorder.gd` records the signals of any object.

## Autoloads

Order: EventBus, DataDir, Balance, I18n, Audio, Settings, Progress. There is no plugin or feature registry and no `features/` folder.

- **EventBus** (`scripts/autoload/event_bus.gd`): typed signals only – `level_started`, `level_timer_tick`, `task_completed`, `all_required_done`, `level_won`, `level_lost`, `event_triggered`, `object_grabbed`, `object_thrown`, `object_bonked`, `settings_changed`, `task_progress`, `timer_warning`, `event_ended`, plus the castaway signals listed in `docs/castaway.md`, the animal and item signals in `docs/entities.md` and the feedback signals `event_warning`, `fx_anchor` and `fx_anchor_node` (`docs/feedback.md`). Contract: signals are only added, never renamed or retyped; no `register()`, no lookup.
- **DataDir** (`scripts/autoload/data_dir.gd`): folder for settings and progress. `-- --data-dir=<path>` wins over `TFI_DATA_DIR`, default `user://`. API: `path()`, `file(rel)`, `ensure_dir(rel)`; statics `resolve(cli, env)`, `current_dir()`, `globalize(dir)` (usable from `--script` entries via `preload`).
- **Balance** (`scripts/autoload/balance.gd`): every tuning number lives in `data/balance/<ns>.json` and is read by namespace (file stem): `get_int`, `get_float`, `get_bool`, `get_value`, `get_section`, `has_value`. Tests override single values with `set_override(ns, key, value)`/`set_overrides`; `clear_overrides()` restores the files. Integral JSON floats read as ints.
- **I18n** (`scripts/autoload/i18n.gd`): loads `i18n/*.csv` (`key,en,de`, UTF-8 without BOM) into the TranslationServer; English is the default. `set_locale("de")` switches live and emits `locale_changed`; `t(key, args)` fills `{placeholders}`. Controls show keys directly (`text = "core.title"`) and auto-translate.
- **Settings** (`scripts/autoload/settings.gd`): `settings.json` in the DataDir folder (language, music and effects volume, reduce shake and flashes); applied at boot and live on `set_value(key, value, save_now)`; `flush()` writes debounced slider changes.
- **Progress** (`scripts/autoload/progress.gd`): the campaign of `data/campaign.json` and `progress.json` next to `settings.json` (wins, best stars, best time); `record_win()` saves at once.

Game flow, menus and both file schemas: `docs/flow.md`.

Castaway controller, controls, interact rules, contracts for grabbables and use targets, and physics layers: `docs/castaway.md`.

Animals and items (generic state machine, herding, luring, hit reactions, respawn, zones, entity registry and their signals): `docs/entities.md`.

Helpers: `CliArgs` (`scripts/core/cli_args.gd`) parses user arguments; `SeededRng` (`scripts/core/seeded_rng.gd`) is the only allowed source of randomness (event schedules are seeded, never truly random).

## Validators

- `tools/validate_i18n.py`: CSV format (BOM, header, 3 columns, key prefix = file stem, duplicates, empty EN/DE, equal placeholders) and code usage: unknown keys in `tr()`/`I18n.t()`, unknown key-like literals, hard-coded literals assigned to `.text`/`.tooltip_text`/`.placeholder_text`/`.title`, and `.tscn` text properties that are not keys.
- `tools/validate_code.py`:
  - comments in English, en dash instead of em dash (.gd and .py);
  - no magic numbers in `scripts/gameplay/`, `scripts/levels/`, `scripts/feedback/`, `scripts/rules/`, `scripts/audio/`, `scripts/flow/`, `scripts/ui/menus/` and the Audio, Settings and Progress autoloads – only 0, 0.5, 1 and 2 are allowed, everything else comes from Balance; a line may opt out with `# balance-exempt: <reason>`;
  - no networking classes or modules, Python standard library only;
  - no survival stats: no hunger, energy, health, food, rest, faint or stamina in identifiers, node names, balance keys or i18n keys (the game has none of these mechanics);
  - no global randomness outside `SeededRng`, no `get_meta(key, null)`, every tracked `.gd` has a tracked `.gd.uid`.
  - no turn-based, grid or inventory mechanics: no `action_point(s)`, `end_turn`, `turn_count`, `turn_based`, `snap_to_grid`, `tile_step`, `grid_move` and no inventory/recipe/crafting in identifiers and node names below `scripts/` and `scenes/` or in input actions.
  - no harm: no damage, death, dead, die, kill, blood, hurt, wound, injur… or hp in identifiers, node names, balance keys, animal/item data keys or i18n keys (Tween `.kill()` stays allowed).
  - `Engine.time_scale` is assigned only by `scripts/feedback/feedback_director.gd` (hit-stop owner; tests are exempt).
- `tools/validate_assets.py`: every file below `assets/` lies in a pack listed in `assets/SOURCES.md` (pack, author, licence, source per row); every media file referenced by a `.tscn`, `.tres`, `.gd`, `project.godot` or `data/**/*.json` lies in such a pack, every referenced file exists with the exact letter case, and no used asset name matches the deny list `data/assets/deny_list.json` (weapons, violence, scary content). Unused imported files and imported deny-list names are listed as warnings. Format placeholders (`%s`, `{name}`) make a reference a pattern.
- `tools/validate_basics.py`: required top-level files exist.
- `tools/validate_credits.py`: `data/credits.json` matches `assets/SOURCES.md` (regenerate with `python tools/build_credits.py`), and the limits of `data/balance/flow.json` (result input delay in (0, 2] s, guards not negative, font sizes at least `font_size_min`).
- `tools/validate_entities.py`: `data/animals.json` and `data/items.json` – structure, lure items, sprites (exist, imported, not deny-listed, at least 24 px at 720p), EN/DE names, carry weights and the reaction time limit (see `docs/entities.md`).
- `tools/validate_levels.py`: `data/events.json` and every `data/levels/*.json` against the level schema, with limits from `data/balance/rules.json` (see `docs/rules.md`).
- `tools/validate_feedback.py`: `data/feedback.json` and `data/balance/feedback.json` – every EventBus signal mapped or listed in `no_visual`, required visuals, event warnings, strength keys, sound words (EN/DE, at most 8 characters plus "!"), assets (exist, imported, not deny-listed, folder in `docs/asset_map.md`), family-friendly materials and the balance limits (hit-stop ≤ 80 ms, flash alpha ≤ 0.4, at most 3 flashes per second, reduce factor ≤ 25 %; see `docs/feedback.md`).

## Assets

The CC0 packs live in `assets/` (copied unchanged from the spec folder), with sources and licences in `assets/SOURCES.md`. `docs/asset_map.md` names the chosen sprites, fonts and sounds; folders the game does not use carry a `.gdignore` so Godot skips them on import.

## Conventions

- Every `i18n/<area>.csv` needs a committed sibling `i18n/<area>.csv.import` containing `importer="keep"`, so Godot does not generate `.translation` files.
- After adding a `.gd` or `.gdshader` file, run the import (any `run_tests.py` run does it) and commit the generated `.uid` file.
- Level scenes, the camera, the layout builder and the opt-in windowed capture (`python tools/capture_level.py`) are described in `docs/levels.md`; art rules in `docs/art_treatment.md`.
- Error fixtures for loaders are written at test time below the redirected data folder, never under `res://`.

## Docs

Vision, backlog, requirements, market and personas are in `docs/process/`.

`docs/feedback.md` describes the slapstick feedback director (effects, data schema, anchors, caps, hit-stop and the reduce toggle).

`docs/rules.md` describes the data-driven rules engine in `scripts/rules/`: level schema, conditions, events, snapshot contract, tick order, signals and stars.
