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

GDScript tests extend `TestCase` (`check`, `check_eq`, `check_has`, `fail`, `add_node`, `frames`); `before_each`/`after_each` hooks and coroutine tests are supported. Between tests `tests/support/test_env.gd` clears Balance overrides and switches I18n back to English. `tests/support/signal_recorder.gd` records the signals of any object.

## Autoloads

Order: EventBus, DataDir, Balance, I18n. There is no plugin or feature registry and no `features/` folder.

- **EventBus** (`scripts/autoload/event_bus.gd`): typed signals only – `level_started`, `level_timer_tick`, `task_completed`, `all_required_done`, `level_won`, `level_lost`, `event_triggered`, `object_grabbed`, `object_thrown`, `object_bonked`, `settings_changed`. Contract: signals are only added, never renamed or retyped; no `register()`, no lookup.
- **DataDir** (`scripts/autoload/data_dir.gd`): folder for settings and progress. `-- --data-dir=<path>` wins over `TFI_DATA_DIR`, default `user://`. API: `path()`, `file(rel)`, `ensure_dir(rel)`; statics `resolve(cli, env)`, `current_dir()`, `globalize(dir)` (usable from `--script` entries via `preload`).
- **Balance** (`scripts/autoload/balance.gd`): every tuning number lives in `data/balance/<ns>.json` and is read by namespace (file stem): `get_int`, `get_float`, `get_bool`, `get_value`, `get_section`, `has_value`. Tests override single values with `set_override(ns, key, value)`/`set_overrides`; `clear_overrides()` restores the files. Integral JSON floats read as ints.
- **I18n** (`scripts/autoload/i18n.gd`): loads `i18n/*.csv` (`key,en,de`, UTF-8 without BOM) into the TranslationServer; English is the default. `set_locale("de")` switches live and emits `locale_changed`; `t(key, args)` fills `{placeholders}`. Controls show keys directly (`text = "core.title"`) and auto-translate.

Helpers: `CliArgs` (`scripts/core/cli_args.gd`) parses user arguments; `SeededRng` (`scripts/core/seeded_rng.gd`) is the only allowed source of randomness (event schedules are seeded, never truly random).

## Validators

- `tools/validate_i18n.py`: CSV format (BOM, header, 3 columns, key prefix = file stem, duplicates, empty EN/DE, equal placeholders) and code usage: unknown keys in `tr()`/`I18n.t()`, unknown key-like literals, hard-coded literals assigned to `.text`/`.tooltip_text`/`.placeholder_text`/`.title`, and `.tscn` text properties that are not keys.
- `tools/validate_code.py`:
  - comments in English, en dash instead of em dash (.gd and .py);
  - no magic numbers in `scripts/gameplay/`, `scripts/levels/` and `scripts/feedback/` – only 0, 0.5, 1 and 2 are allowed, everything else comes from Balance; a line may opt out with `# balance-exempt: <reason>`;
  - no networking classes or modules, Python standard library only;
  - no survival stats: no hunger, energy, health, food, rest, faint or stamina in identifiers, node names, balance keys or i18n keys (the game has none of these mechanics);
  - no global randomness outside `SeededRng`, no `get_meta(key, null)`, every tracked `.gd` has a tracked `.gd.uid`.
- `tools/validate_basics.py`: required top-level files exist.

## Conventions

- Every `i18n/<area>.csv` needs a committed sibling `i18n/<area>.csv.import` containing `importer="keep"`, so Godot does not generate `.translation` files.
- After adding a `.gd` file, run the import (any `run_tests.py` run does it) and commit the generated `.gd.uid`.
- Error fixtures for loaders are written at test time below the redirected data folder, never under `res://`.

## Docs

Vision, backlog, requirements, market and personas are in `docs/process/`.
