# Terralon's Funny Isle 2

A hectic, single-player, keyboard-first slapstick action game for Windows (Godot 4.7.2, GDScript, offline, English and German). A castaway runs, dashes, grabs, carries and throws animals and items across five handcrafted tropical island levels against a 3–5 minute timer while funny tasks and slapstick events keep going wrong. Version 2 replaces the turn-based survival game of v1 with real-time action, polished CC0 art and full audio.

## Start

    python tools/play.py

Godot 4.7.2 is found in the WinGet folder or via the environment variable `GODOT_BIN`.

## Check (build, lint, tests)

    python tools/run_tests.py

Runs the syntax check, the headless Godot import, all GDScript and Python tests, the headless smoke start and the validators. Exit code is non-zero on any failure. Test data goes to `<repo>.testdata/`, never to the real user folder.

## Docs

Vision, backlog, requirements, market and personas are in `docs/process/`.
