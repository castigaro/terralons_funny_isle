# Changelog

All notable changes to this project are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.2.1] – 2026-11-23

Fix round for the findings of the 1.2.0 release QA. Gameplay, tasks, timers, layout and difficulty are unchanged.

### Fixed

- No leftover 'HA HA' emote or popup beside the loss result panel: result mode now clears and blocks emotes as well as popup words (QA-4).
- Version raised to 1.2.1 in `project.godot` and `export_presets.cfg`.

### Known limitations

- Hard-edged rectangular grass patches remain in L1, L2 and L5 (QA-3); the fix is not on main yet.
- Clean exit (BI-24) and the difficulty curve are still open.

## [1.2.0] – 2026-11-23

Finished-look pass: textured ground, five themed levels, a live island behind the menus and a stricter export check. Gameplay, tasks, timers, events, layout and difficulty are unchanged.

### Added

- Textured ground with edge tiles instead of flat single-colour rectangles in all levels (BI-19).
- Beach Camp reads as a camp (tent, crates, barrels, campfire, driftwood, dune grass) and Farm Meadow as a farm (fenced pig pen, barn, ploughed field with crops); gameplay positions and collision are unchanged (BI-20).
- The Lagoon reads as a lagoon village: four thatched stilt huts on the water, plank docks leading to them from the shore, two sailing boats plus a rowing dinghy that bob gently on the water (still with "reduce screen shake and flashes"); huts and boats cast a soft water reflection instead of a ground shadow. Gameplay positions, collision, tasks and events are unchanged (BI-22).
- Volcano Cliffs reads as a volcano: dark textured basalt ground with scorched ash instead of grass, cliff faces along the coast, glowing lava fissures on the rock clusters and three smoking vents; animals get a light halo and items a light outline there, drop shadows are tinted darker, and lava glow holds still under "reduce screen shake and flashes". Layout, collision, tasks and events are unchanged (BI-23).
- Themed Jungle (level 3) with dense layered vegetation, a darker jungle ground, a grass tint and semi-transparent canopy foliage that fades near the castaway (BI-21).
- Live island behind the title, level select, settings and credits: animated water, a textured beach with grass patches, palms and a chicken, pig, goat and parrot that wander and idle; the menus stay on their dark panels, the island is hidden and frozen while a level runs, and the critter hop stops with "Reduce screen shake and flashes" (BI-18).
- The smoke run of the exported exe loads every animal and item sprite and every level and fails on any unknown kind or missing resource; `tools/export.py` reports each problem line (BI-26).

### Changed

- The credits list the pack names in the smallest menu font, so the added theme props row still fits at 1280x720.

### Fixed

- Level start shows a single 'GO!' cue: the big popup stays, the caption chip of the 'go' voice line is hidden (QA-1).
- No leftover announcer caption over the level select or the credits after leaving a level: leaving a level now clears the queued announcer lines (QA-2).
- The exported exe shows all animals and items again; since 1.0.0 its sprite check missed the imported textures and dropped every kind.
- Version raised to 1.2.0 in `project.godot` and `export_presets.cfg`.

### Known limitations

- Hard-edged rectangular grass patches remain in L1, L2 and L5 (QA-3); a level popup ('HA HA') stays visible beside the loss panel (QA-4).
- Clean exit (BI-24) and the difficulty curve are still open.

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
