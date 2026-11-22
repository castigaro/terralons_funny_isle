# Changelog

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Beach Camp reads as a camp (tent, crates, barrels, campfire, driftwood, dune grass) and Farm Meadow as a farm (fenced pig pen, barn, ploughed field with crops); gameplay positions and collision are unchanged (BI-20).

### Changed

- The credits list the pack names in the smallest menu font, so the added theme props row still fits at 1280x720.

## [1.1.0] – 2026-11-22

Readability pass: font, result screen and HUD 3-star target. Gameplay, tasks, timers and difficulty are unchanged.

### Added

- HUD 3-star goal next to the timer: three stars plus a line such as 'needs 1:00 left' that shows whether the 3-star time is still reachable, with a tick once it is secured (BI-17).

### Changed

- New readable display font with full glyphs (%, X, umlauts) and even letter spacing; HUD task names fit on one line in EN and DE (BI-15).
- The result screen shows one headline and the earned stars once, animated, for win and loss (BI-16).
- Version raised to 1.1.0 in `project.godot` and `export_presets.cfg`.

### Known limitations

- Not part of this release and moved to later rounds: textured ground and no flat placeholder rectangles (BI-19, merge failed on the hygiene check, branch `feature/BI-19` kept), live menu backdrop (BI-18), themed levels (BI-20 to BI-23), clean exit (BI-24).
- Flat green rectangles are still visible in levels 1, 3, 4 and 5, and the menus still sit on plain light blue.
- The level start shows the 'GO!' cue twice and the credits can show a leftover popup behind the panel (QA-1, QA-2).

## [1.0.0] – 2026-11-22

First release of Terralon's Funny Isle 2: a real-time slapstick action game in five levels (Godot 4.7.2, GDScript, English and German, offline).

### Added

- Project foundation with the autoloads EventBus, DataDir, Balance, I18n, Audio, Settings and Progress, the test runner `tools/run_tests.py` and the validators (BI-1).
- CC0 asset packs with `assets/SOURCES.md`, asset map and asset validator (BI-13).
- Data-driven rules engine for levels, tasks, events, timers and stars (BI-3).
- Castaway controller: move, dash, grab, carry, throw, use and dizzy (BI-2).
- Level scene framework, smooth camera and polished island art (BI-5).
- Animals and items with herding, hit reactions and respawn (BI-4).
- Slapstick feedback director with pooled effects, screen shake and hit-stop (BI-8).
- Audio buses, music, sound effects, jingles and announcer (BI-9).
- HUD with contextual prompts, hints and failure cues (BI-6).
- Game flow: title, level select, intro card, pause, result screens, settings, credits, progression and saved settings and progress (BI-7).
- Levels 1–2, Beach Camp and Farm Meadow, with events such as the parrot stealing the hat (BI-10).
- Levels 3–5, Jungle, Lagoon and Volcano Cliffs (BI-11).
- Bot playthrough of all levels under earliest and latest event timing and with water injection (BI-12).
- Opt-in windowed smoke, performance and German clip checks, content review and Windows export `build/TerralonsFunnyIsle.exe` (BI-14).

### Known limitations

- The human first run (20–30 minutes) and a listening pass for the sounds have not happened; see `docs/playtest.md`.
- The export is not code-signed.
