# Changelog

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
