# Backlog – Release 1.2.0

Release 1.2.0 "Finished Look" plans BI-19, BI-18, BI-20, BI-21, BI-22 and BI-23; BI-26 (export smoke check), QA-1, QA-2 and BI-27 (release preparation) ride along. Difficulty, timers, tasks, events and layout stay unchanged. BI-24 stays open and out of scope; BI-25 is superseded by BI-27. Items done in 1.1.0 and 1.0.0 follow with unchanged sections.

| Prio | ID | Title | Size | Clarity | Novel | UX | Status |
|---|---|---|---|---|---|---|---|
| 1 | BI-15 | Readable display font with full EN/DE glyphs and one-line HUD task names | small | clear | no | yes | done in 1.1.0 |
| 2 | BI-16 | Result screen with one headline and one star animation | small | clear | no | yes | done in 1.1.0 |
| 3 | BI-17 | Clear HUD 3-star target with live reachability | small | clear | no | yes | done in 1.1.0 |
| 1 | BI-19 | Textured ground with edge tiles and no flat placeholder shapes in any level | large | clear | no | yes | planned for 1.2.0 |
| 2 | BI-26 | Export smoke check catches missing sprites and resources in the built exe | small | clear | no | no | planned for 1.2.0 |
| 3 | BI-18 | Live island scene behind title, level select and settings | large | clear | yes | yes | delivered (feature/BI-18) |
| 4 | BI-20 | Themed Beach Camp and Farm Meadow | large | clear | no | yes | planned for 1.2.0 |
| 5 | BI-21 | Themed Jungle with dense vegetation | large | clear | no | yes | planned for 1.2.0 |
| 6 | BI-22 | Themed Lagoon with huts, boats and docks | large | clear | no | yes | planned for 1.2.0 |
| 7 | BI-23 | Themed Volcano Cliffs with dark rock, cliff edges and lava glow | large | clear | no | yes | planned for 1.2.0 |
| 8 | QA-1 | One 'GO!' cue at level start instead of chip plus giant text | small | clear | no | yes | planned for 1.2.0 |
| 9 | QA-2 | No leftover popup behind the credits panel | small | clear | no | yes | delivered with BI-18 |
| 10 | BI-27 | Release 1.2.0: full visual pass, tag and fresh verified export | small | clear | no | no | planned for 1.2.0 |
| 11 | BI-24 | Clean exit without leaked-instance warnings | small | unclear | no | no | open |
| 12 | BI-25 | Release 1.1.0: full visual pass, tag and fresh export | small | clear | no | no | superseded by BI-27 |
| 1 | BI-1 | Project foundation, reused tooling and core autoloads | large | clear | no | no | done in 1.0.0 |
| 2 | BI-13 | Asset import, SOURCES.md and asset validator | small | clear | no | no | done in 1.0.0 |
| 3 | BI-3 | Data-driven level, task, event, timer and star rules engine | large | clear | no | no | done in 1.0.0 |
| 4 | BI-2 | Castaway real-time controller: move, dash, grab, carry, throw, use, dizzy | large | clear | yes | yes | done in 1.0.0 |
| 5 | BI-5 | Level scene framework, camera and polished environment art | large | clear | yes | yes | done in 1.0.0 |
| 6 | BI-4 | Animals and items: behaviours, herding, hit reactions and respawn | large | clear | no | yes | done in 1.0.0 |
| 7 | BI-8 | Slapstick juice and feedback system | large | clear | yes | yes | done in 1.0.0 |
| 8 | BI-9 | Audio: music, sound effects, jingles, announcer and buses | large | clear | no | yes | done in 1.0.0 |
| 9 | BI-6 | HUD, contextual prompts, hints and failure cues | large | clear | no | yes | done in 1.0.0 |
| 10 | BI-7 | Game flow, menus, progression and saved settings | large | clear | no | yes | done in 1.0.0 |
| 11 | BI-10 | Levels 1–2: Beach Camp and Farm Meadow | large | clear | no | yes | done in 1.0.0 |
| 12 | BI-11 | Levels 3–5: Jungle, Lagoon and Volcano Cliffs | large | clear | no | yes | done in 1.0.0 |
| 13 | BI-12 | Bot playthrough of all levels under worst-case event timing | large | clear | no | no | done in 1.0.0 |
| 14 | BI-14 | Windowed smoke run, performance, German clip check, content review and export | large | clear | no | no | done in 1.0.0 |

### BI-15 – Readable display font with full EN/DE glyphs and one-line HUD task names

- Status: done in 1.1.0
- Priority: 1
- Size: small
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As a player I want every text in the game to be readable with even letter spacing and correct glyphs, so that I never misread 'NEXT', a percentage or a task name.

**Acceptance criteria:**

1. The UI theme uses one display font (an existing Kenney font variant or a derived/fixed version of kenpixel) that renders A–Z, a–z, 0–9, %, X, ★, ✓ and ä ö ü Ä Ö Ü ß correctly; a headless test renders these glyphs and fails if any falls back to a missing-glyph box or wrong character.
2. 'NEXT' reads as NEXT, '100 %' shows a percent sign, and 'COCONUTS'/'SANDCASTLE' show no visible gap inside the word in playtest screenshots.
3. Every HUD task title fits on one line in EN and DE at 1280x720 and 1920x1080; titles that do not fit are shortened in the i18n files (EN and DE), and validate_i18n or a new check fails if a task title exceeds the measured one-line width.
4. tools/playtest.py screenshots of title, level select, settings, intro card, HUD, pause, result and credits in EN and DE show no clipped or overlapping text; the windowed clip stage of run_tests.py passes.
5. The font source is listed in assets/SOURCES.md and credits; run_tests.py default stages stay green.

### BI-16 – Result screen with one headline and one star animation

- Status: done in 1.1.0
- Priority: 2
- Size: small
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As a player finishing a level I want one clear headline and my stars shown once, so that the result screen reads cleanly instead of three overlapping 'LEVEL COMPLETE!' texts.

**Acceptance criteria:**

1. After a win exactly one headline node is visible (e.g. 'LEVEL COMPLETE!' / German equivalent); the banner and the giant text behind the panel are removed or merged, verified by a scene test that counts visible headline labels = 1.
2. After a loss exactly one loss headline is visible, with the same layout rules.
3. Earned stars animate in once (one after another) and then stay; no second star row is shown.
4. No two visible text nodes on the result screen overlap (test compares global rects), for win and loss in EN and DE.
5. tools/playtest.py result screenshots for win and loss in EN and DE at 1920x1080 and 1280x720 show the clean layout; scoring, retry and next-level buttons work as before.

### BI-17 – Clear HUD 3-star target with live reachability

- Status: done in 1.1.0
- Priority: 3
- Size: small
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As a player I want to see at a glance how much time must remain for 3 stars and whether that is still possible, so that I know if I should hurry.

**Acceptance criteria:**

1. The HUD shows the 3-star condition as a self-explaining label next to the timer, e.g. '★★★ if ≥ 1:00 left' / 'DE: ★★★ bei ≥ 1:00 Rest', using the existing 3-star threshold from the level data; wording is in both i18n files.
2. The state is shown as 'reachable' (normal colour, no tick at level start) while time left is above the threshold and all tasks can still be done; it switches to 'missed' (greyed or struck through, no tick) as soon as the timer drops below the threshold; a tick appears only once 3 stars are actually secured at level end.
3. A unit test drives the HUD with time-left values above, at and below the threshold and asserts the three states.
4. Star thresholds, timers and scoring are unchanged (existing balance tests stay green).
5. tools/playtest.py HUD screenshots in EN and DE show the label on one line without overlapping the timer at 1280x720 and 1920x1080.

### BI-19 – Textured ground with edge tiles and no flat placeholder shapes in any level

- Status: planned for 1.2.0
- Priority: 1
- Size: large
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As a player I want grass, sand and zones in every level to look like real terrain, so that the levels look finished instead of showing flat coloured rectangles.

**Acceptance criteria:**

1. The existing branch feature/BI-19 is reviewed and reused if sound (rebased or merged with current main, including the ResourceLoader.exists sprite fix); otherwise the item is redone on a fresh branch and the reason is recorded.
2. The run_tests.py hygiene check ('the real user folder changed') is investigated: either a test that writes to the real Godot app_userdata folder is identified and redirected to D:\projects2\fdp-runs\terralons_funny_isle.testdata, or two clean consecutive full run_tests.py runs on the merged state show the check green and the finding (parallel play by the user) is recorded in the run report.
3. The flat green rectangles (L1, L3, L4, L5) and the flat orange sandcastle-zone square (L4) are replaced by tiles or sprites with textured fill and visible edges/transitions.
4. Grass in all five levels uses a textured tile with grass-to-sand edge tiles (existing pirate-pack or derived tiles, generated by a tool script if needed).
5. Task zones (sandcastle zone, pens, drop-offs) use a sprite-based marker (border/decal) that stays clearly recognisable as a zone.
6. A validator fails if any level scene or level_base draws a flat single-colour ColorRect/Polygon2D/draw_rect as ground or zone; it passes for all five levels.
7. Gameplay positions, collision shapes and zone areas are unchanged: layout/collision tests green, bot playthrough wins every level.
8. tools/playtest.py screenshots of all five levels show no flat single-colour rectangle; any derived asset is recorded in assets/SOURCES.md.

### BI-26 – Export smoke check catches missing sprites and resources in the built exe

- Status: planned for 1.2.0
- Priority: 2
- Size: small
- Clarity: clear
- Novel: no
- UX-relevant: no

**User story:** As the user I want the release export to fail when the built exe misses animals, items or other resources, so that a broken build like the 1.1.0 exe with invisible animals can never ship again.

**Acceptance criteria:**

1. tools/export.py runs the freshly built exe in a smoke mode that loads every level (L1–L5) and the menus once and then quits, with its data folder redirected below D:\projects2\fdp-runs\terralons_funny_isle.testdata.
2. The smoke step fails (non-zero exit, clear message naming level and resource) on any 'unknown kind' warning, missing-resource/failed-load warning, script error, or a level whose spawned animal/item count with a valid texture is lower than the level data expects.
3. A regression test proves the check: re-introducing the FileAccess.file_exists sprite lookup (or an equivalent forced missing sprite) in a test build makes the smoke step fail; the current main passes.
4. The check uses only the Python standard library and the installed Godot; run_tests.py stays green.
5. docs (README or docs/process) describe the smoke check and how to read its output.

### BI-18 – Live island scene behind title, level select and settings

- Status: delivered (feature/BI-18)
- Priority: 3
- Size: large
- Clarity: clear
- Novel: yes
- UX-relevant: yes

**User story:** As a player opening the game I want to see a living island behind the menus, so that the game feels inviting from the first second instead of showing plain light blue.

**Acceptance criteria:**

1. Title, level select, settings and credits show an animated backdrop scene: animated water (existing water shader), beach and textured grass tiles from BI-19, a few palms and at least three animals from the existing sprites that wander and idle.
2. Menus stay readable: menu panels have a backing or the backdrop is dimmed so that text contrast is at least 4.5:1 against its immediate background in screenshots.
3. The backdrop persists across menu screens without restarting or flickering, is paused or removed while a level runs, and adds no errors or warnings in the headless and windowed smoke stages and the BI-26 export smoke.
4. Keyboard navigation is unchanged and the perf stage of run_tests.py --windowed still passes.
5. tools/playtest.py screenshots of title (EN/DE), level select, settings and credits at 1920x1080 and 1280x720 show the backdrop and readable menus.

### BI-20 – Themed Beach Camp and Farm Meadow

- Status: planned for 1.2.0
- Priority: 4
- Size: large
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As a player I want Beach Camp to read as a camp on the beach and Farm Meadow as a farm, so that each level has its own identity at first sight.

**Acceptance criteria:**

1. Farm Meadow shows fences around pens or fields, a barn (composed/derived from existing CC0 sprites if no pack contains one), a ploughed or crop field area and textured meadow grass.
2. Beach Camp shows camp decoration (e.g. tent, crates, campfire, driftwood from existing packs) distinct from the other levels.
3. Decoration is non-blocking or only placed where the layout already has obstacles: layout files, collision, task and spawn positions are unchanged (layout tests and bot playthrough green).
4. Every used or derived asset lies in a folder listed in assets/SOURCES.md and in the credits; validate_assets and validate_credits pass.
5. tools/playtest.py screenshots of L1 and L2 next to each other show clearly different themes; animals and items stay at least 24 px and visible against the new ground.

### BI-21 – Themed Jungle with dense vegetation

- Status: planned for 1.2.0
- Priority: 5
- Size: large
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As a player I want the Jungle level to feel dense and overgrown, so that it clearly differs from the open beach and meadow levels.

**Acceptance criteria:**

1. L3 shows dense vegetation from the foliage packs (layered bushes, large leaves, vines/palms) along borders and in non-play areas, plus a darker jungle ground tile with edges.
2. Vegetation never hides the castaway, animals, items or task zones in play areas (foreground foliage is semi-transparent or outside play paths); verified by playtest screenshots and the bot playthrough still winning L3.
3. Layout, collision, tasks and events are unchanged.
4. All assets are from listed CC0 packs; asset and credit validators pass.
5. tools/playtest.py L3 screenshots read as jungle at first sight and look clearly different from L2 (Farm Meadow) in a side-by-side comparison.

### BI-22 – Themed Lagoon with huts, boats and docks

- Status: planned for 1.2.0
- Priority: 6
- Size: large
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As a player I want the Lagoon level to show huts, boats and wooden docks on the water, so that it reads as a lagoon village.

**Acceptance criteria:**

1. L4 shows wooden docks/piers at the water edge, at least two boats (pirate-pack ships/boats) on the water and huts (composed/derived from existing sprites if needed).
2. Water areas use the animated water shader with shore edge tiles; no flat colour areas remain.
3. Layout, collision, tasks and events are unchanged; bot playthrough still wins L4.
4. All assets are from listed CC0 packs or derived ones recorded in SOURCES.md and credits; validators pass.
5. tools/playtest.py L4 screenshots read as a lagoon village at first sight.

### BI-23 – Themed Volcano Cliffs with dark rock, cliff edges and lava glow

- Status: planned for 1.2.0
- Priority: 7
- Size: large
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As a player I want Volcano Cliffs to look dangerous with dark rock, cliff edges and glowing lava, so that the final level feels like a climax.

**Acceptance criteria:**

1. L5 uses a dark rock ground (tinted or derived from existing tiles) with visible cliff edges around the island outline.
2. Lava or glowing cracks are shown in non-play areas using existing particle/smoke sprites and a shader or tint (no new pack download); purely decorative, no gameplay change.
3. Layout, collision, tasks and events are unchanged; bot playthrough still wins L5; the perf stage still passes with the added particles.
4. All assets are from listed CC0 packs or derived ones recorded in SOURCES.md; validators pass.
5. tools/playtest.py L5 screenshots read as a volcano at first sight; animals and items remain clearly visible against the dark ground.

### QA-1 – One 'GO!' cue at level start instead of chip plus giant text

- Status: planned for 1.2.0
- Priority: 8
- Size: small
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As a player I want the level start to show a single 'GO!' / 'LOS!' cue, so that the start looks clean like the result screen.

**Acceptance criteria:**

1. At level start in all five levels, EN and DE, exactly one start cue is visible (no dark chip with 'GO!' plus a giant outlined 'GO!' below it).
2. The cue does not overlap HUD panels or context prompts at 1280x720 and 1920x1080.
3. tools/playtest.py start screenshots of every level in EN and DE show one cue; run_tests.py stays green.
4. May ride along in a themed-level branch or the release branch; the backlog notes where it landed.

### QA-2 – No leftover popup behind the credits panel

- Status: delivered with BI-18 (cause: an announcer line queued by the level, for example the loss taunt, ticked out after the level was freed and showed its caption over the next menu; `_free_level` now calls `Audio.clear_announcer()`; level popups leave with the level and stay hidden behind the result screen)
- Priority: 9
- Size: small
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As a player I want the credits to show only the credits panel, so that no stray bubble shows through its title.

**Acceptance criteria:**

1. Opening the credits right after leaving a level (won or lost) shows no popup, cue chip or bubble behind or through the panel, EN and DE.
2. On the loss result screen, level popups (for example 'HA HA') are removed or hidden once the panel is shown, or documented as intended.
3. tools/playtest.py credits shot in EN and DE shows only the panel on the (BI-18) backdrop.
4. May ride along with BI-18 or the release branch; the backlog notes where it landed.

### BI-27 – Release 1.2.0: full visual pass, tag and fresh verified export

- Status: planned for 1.2.0
- Priority: 10
- Size: small
- Clarity: clear
- Novel: no
- UX-relevant: no

**User story:** As the user I want release 1.2.0 delivered as a fresh, verified Windows build with honest release notes, so that I can hand the finished-looking game to human players for feedback.

**Acceptance criteria:**

1. Version is 1.2.0 in project.godot and the game; CHANGELOG lists BI-18 to BI-23, BI-26, QA-1 and QA-2 and states that difficulty, timers, tasks, events and layout are unchanged.
2. run_tests.py (default and --windowed stages) pass; tools/playtest.py runs over all screens and levels in EN and DE at 1920x1080 plus a 1280x720 pass, with no clipped or overlapping text and no flat placeholder shapes; L2 and L3 clearly look different.
3. A fresh build/TerralonsFunnyIsle.exe is exported via tools/export.py and passes the extended BI-26 smoke check (all levels load, all animals and items present); the run report names its absolute path and build time.
4. docs/process/backlog.md shows each item's status; the superseded BI-25 is closed formally; the release commit gets a local tag v1.2.0 (no push).
5. The run report lists remaining open points (human playtest, listening pass, unsigned exe, BI-24, difficulty curve, EventActor conversion warning, BONUS tag spacing) as still open.

### BI-24 – Clean exit without leaked-instance warnings

- Status: open
- Priority: 11
- Size: small
- Clarity: unclear
- Novel: no
- UX-relevant: no

**User story:** As a player I want the game to close cleanly, so that no hidden resource leaks build up and logs stay free of noise.

**Acceptance criteria:**

1. A headless start-to-quit run (title, one level start, quit) is repeated 5 times and the output is checked for 'ObjectDB instances leaked' and 'resources still in use'.
2. If reproduced, the cause is fixed (e.g. freeing orphaned nodes or tweens at exit) and the 5 runs show no such warning; if not reproducible, the check is added to the smoke stage so a future regression fails.
3. The finding (reproduced or not, cause) is recorded in the release run report.

### BI-25 – Release 1.1.0: full visual pass, tag and fresh export

- Status: superseded by BI-27 (closed, not delivered as 1.1.0 release item)
- Priority: 12
- Size: small
- Clarity: clear
- Novel: no
- UX-relevant: no

**User story:** As the user I want release 1.1.0 delivered as a fresh, verified Windows build with honest release notes, so that I can hand it to human players for feedback.

**Acceptance criteria:**

1. Version is 1.1.0 in project.godot and the game; CHANGELOG lists BI-15 to BI-24 and states that difficulty, timers, tasks and events are unchanged.
2. run_tests.py (default and --windowed stages) pass; tools/playtest.py runs over all screens and levels in EN and DE at 1920x1080 and a 1280x720 pass, with no clipped or overlapping text and no flat placeholder shapes.
3. A fresh build/TerralonsFunnyIsle.exe is exported via tools/export.py and starts; the run report names its absolute path and build time.
4. The backlog status in docs/process/backlog.md is updated per item as it merges, and the release commit is tagged v1.1.0 (local tag only, no push).
5. The run report lists remaining open points (human playtest, listening pass, unsigned exe) as still open.

### BI-1 – Project foundation, reused tooling and core autoloads

- Status: done in 1.0.0
- Priority: 1
- Size: large
- Clarity: clear
- Novel: no
- UX-relevant: no

**User story:** As the development team, I want a working Godot 4.7.2 project skeleton with the reused v1 tooling and the core autoloads, so that every following feature branch can build, run and test the game from day one. Covers R-60, R-61, R-62, R-64, R-65 (validator), R-66 (infrastructure), R-69, R-70, R-56 (validator), R-33 (data-folder override), R-8 (absence validator). Per D-10 the listed v1 files may be copied verbatim from the reference product and adapted. Asset import moved to BI-13, export to BI-14.

**Acceptance criteria:**

1. The repo D:\projects2\fdp-runs\terralons_funny_isle is a Git repo on branch main; project.godot declares the 4.7 feature set, viewport 1920x1080, resizable window, stretch mode canvas_items, physics tick 60 Hz.
2. python tools/play.py from the repo root starts Godot (path from the stack, overridable via environment variable) and opens a title scene stub without any engine error in the log; the stub uses no ColorRect boxes and is replaced by BI-7.
3. python tools/run_tests.py runs the headless GDScript test runner (tests/runner.gd, tests/test_case.gd) and all Python validators and exits 0; a deliberately failing sample test (checked by a self-test of the runner) makes it exit non-zero.
4. Autoloads exist and are unit-tested: Balance (loads data/balance/*.json, tests can override single values), I18n (CSV key,en,de, English default, live switch signal), DataDir (CLI -- --data-dir= wins over TFI_DATA_DIR, default user:// folder), EventBus (typed signals, no plugin registry); no features/<id> folder or registry exists.
5. validate_i18n.py fails on a missing key, an empty translation or a hard-coded player-facing string in .gd/.tscn files (each case proven by a fixture).
6. validate_code.py fails on non-English or em-dash comments, magic tuning numbers in gameplay scripts (scripts outside an allow list must read tunables from Balance), networking/HTTP classes, third-party Python imports, and any hunger/energy/health/food/rest/faint stat, balance key or translation key (each case proven by a fixture).
7. run_tests.py redirects the data folder to D:\projects2\fdp-runs\terralons_funny_isle.testdata\<role> and a test asserts nothing is written to the real user data folder.

### BI-13 – Asset import, SOURCES.md and asset validator

- Status: done in 1.0.0
- Priority: 2
- Size: small
- Clarity: clear
- Novel: no
- UX-relevant: no

**User story:** As the development team and as a parent of a young player, I want the CC0 packs copied into the repo with documented sources and a validator that keeps unused, foreign and violent assets out, so that the art and audio are legal, family-friendly and lean. Covers R-59, R-43, R-39 (sprite origin rule), D-7.

**Acceptance criteria:**

1. assets/ contains the packs copied from the spec folder assets/ (the spec folder stays untouched); SOURCES.md lists pack name, source URL or origin, author and licence for every pack, including the sfx-digital row (D-7).
2. tools/validate_assets.py runs in run_tests.py and fails if a resource referenced by any .tscn, .tres, .gd or data JSON file lies outside assets/ or in a pack not listed in SOURCES.md.
3. The validator reports referenced-but-missing files as errors and unused imported files as warnings in a list, and fails if a used file name matches the weapon/violence/scary deny list (e.g. sword, gun, knife, blood, skull, zombie, bomb); the deny list lives in a data file.
4. Import settings exclude unused large folders (e.g. .gdignore) so the editor import of the project finishes headless without errors.
5. A short asset map in docs/ names the chosen sprites for castaway, animals, items, tiles, UI, fonts, particles, music and SFX used by later items.

### BI-3 – Data-driven level, task, event, timer and star rules engine

- Status: done in 1.0.0
- Priority: 3
- Size: large
- Clarity: clear
- Novel: no
- UX-relevant: no

**User story:** As a level designer and as the completionist Tom, I want levels, tasks, events, timer, win/loss and stars defined in JSON and evaluated by generic, deterministic rules, so that levels can be tuned without code changes and every run is fair and reproducible. Covers R-15, R-16, R-19, R-20 (rules), R-22 (hint data), R-25 (timer rules), R-26, R-27, R-28, R-32 (state reset), A1, A2, A6, D-3, D-4. Pure logic, testable without scenes.

**Acceptance criteria:**

1. A level JSON schema (ported from the v1 task schema: conditions, modifiers, fail-forward, hint) describes id, theme, music, timer (180–300 s), 3–5 tasks each with required flag, condition, progress target and hint key (at least one required and one optional), at least 2 events with schedule windows, and a seed; tools/validate_levels.py in run_tests.py rejects each invalid case (fixtures for wrong timer, too few tasks, no optional task, missing hint key, unknown condition).
2. Generic real-time conditions exist: in_zone, held, worn, delivered_to, count_reached, before_time; a test greps the engine for level or task ids and finds none.
3. The engine exposes per-task progress (e.g. 1/2) and emits EventBus signals task_progress, task_done, all_required_done, timer_warning, level_won, level_lost.
4. The event scheduler is seeded per level: the same seed yields identical event order and start times in two runs; start times stay inside the configured windows for 100 seeds (test); a worst-case mode forces every event to the earliest or latest end of its window.
5. Events can move items and animals but never end a level, change the timer or mark a completed task as undone (test with every event type).
6. The timer counts down only while gameplay runs; pausing for N seconds leaves the remaining time unchanged (test); the last 10 seconds emit timer_warning once.
7. Win flow per D-3: all required tasks done emits all_required_done, play continues until finish is pressed or time runs out, then level_won; loss: time reaches 0 with a required task open emits level_lost listing the open required tasks; both covered by headless tests.
8. Stars are a pure function: 1 = required done, 2 = all tasks, 3 = all tasks with at least the time share left (default 0.25 in data/balance, per-level override allowed); boundary tests at exactly 25 %; restart resets tasks, timer and schedule to the initial state in a test.

### BI-2 – Castaway real-time controller: move, dash, grab, carry, throw, use, dizzy

- Status: done in 1.0.0
- Priority: 4
- Size: large
- Clarity: clear
- Novel: yes
- UX-relevant: yes

**User story:** As a player who likes hectic action (Max, Lena), I want the castaway to run, dash, grab, carry, throw and use things instantly and reliably, so that the game feels like fast slapstick action instead of a turn-based chess game. Covers R-1, R-2, R-3, R-4, R-5 (throw arc and landing), R-9, R-10, R-11, R-42 (castaway poses), D-6.

**Acceptance criteria:**

1. The input map in project.godot defines move_up/down/left/right (WASD and arrows), dash (Shift), interact (Space and E), pause (Esc), restart (R), hint (H) and finish (Enter and F); no tile snapping, turns or action points exist (validate_code check).
2. Movement is continuous with acceleration and normalised diagonal speed; input is read in the same physics frame (at most one frame latency); speed, acceleration, dash distance, dash duration and cooldown come from data/balance.
3. Dash produces a stretch, a dust burst and an EventBus dash signal, respects its cooldown and stops at water, walls and level bounds (headless tests for each blocker).
4. Interact grabs the nearest grabbable in front within the balance grab radius; while carrying it uses a valid target in range (cage, goat, delivery zone) and otherwise throws in the facing direction; a second grab is impossible and no inventory UI or recipe data exists; the current interact verb (grab/throw/use/none) is exposed for the HUD prompt.
5. Throws fly in an arc with a ground shadow, land with squash and stretch and emit a landed signal with position and surface (sand, grass, water); range and aim tolerance are balance values.
6. A hit (coconut, stampede, collision) knocks the castaway back and makes it dizzy for a balance time (default 1.2 s) with stars and a BONK popup hook; a carried thing is dropped; input is ignored while dizzy and resumes afterwards; no health value exists.
7. The castaway uses the top-down character stand/hold poses with tweens: run bob, lean, facing, carry pose, throw pose, dizzy pose; it is at least 64 px tall at 1920x1080 and has a soft drop shadow.
8. Headless tests cover move, diagonal normalisation, dash cooldown and blocking, grab, interact while carrying (throws), throw, use, no-target interact and dizzy recovery; a randomised 1000-step input fuzz test never leaves the castaway in a state where no input has an effect after the dizzy time.

### BI-5 – Level scene framework, camera and polished environment art

- Status: done in 1.0.0
- Priority: 5
- Size: large
- Clarity: clear
- Novel: yes
- UX-relevant: yes

**User story:** As a player, I want each island area to look polished – bold outlines, soft shadows, animated water, swaying foliage – fully visible and followed by a smooth camera, so that the game looks like a GDQuest/Kenney top-down demo and not like placeholder boxes. Covers R-12 (level scene base), R-13, R-14, R-39, R-40, R-41, R-48, A15 (no physics jitter).

**Acceptance criteria:**

1. A reusable level scene base loads a level JSON (BI-3) plus a handcrafted TileMap layout from assets/ island tiles, with shoreline and solid collision, level bounds, spawn points, home points and named zones; no procedural map generation, fog, darkness or reveal logic exists (validate_code check).
2. Camera follows the castaway with smoothing and limits at the level bounds; on dash, respawn and restart the camera moves at most the smoothing speed per frame or snaps only during restart; levels that fit the screen use a fixed camera.
3. Water animates continuously (shader or tile animation); palms and bushes sway with per-instance phase offsets; all actors and props have soft drop shadows; docs/art_treatment.md documents outline, shadow and palette rules.
4. validate_assets/validate_code fail on ColorRect or Polygon2D placeholders in gameplay scenes and on sprites outside assets/.
5. Window resizes with canvas_items stretch; a headless or windowed capture confirms the castaway is at least 64 px tall at 1920x1080 and animals and items at least 24 px on their shorter side at 1280x720.
6. Physics runs at a fixed 60 Hz tick with physics interpolation enabled so movement shows no jitter; a sample test level (tests only, not shipped) is playable with the BI-2 castaway.

### BI-4 – Animals and items: behaviours, herding, hit reactions and respawn

- Status: done in 1.0.0
- Priority: 6
- Size: large
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As a player, I want lively animals and throwable items that wander, flee, panic, follow lures, can be herded, carried and thrown and always bounce back unharmed, so that the island is full of funny chaos and no task can ever become impossible. Covers R-5 (knockback on other objects), R-6, R-7, R-21, R-42 (animal motion), A5, D-6, and the pack animals used by the levels (at least chicken, duck, goat, pig, monkey, parrot, penguin).

**Acceptance criteria:**

1. Each animal type has behaviour parameters in data/animals.json (speed, flee radius, panic duration, lure item, herdable, carry weight); behaviours wander, flee from a dashing or approaching castaway, panic on events, follow a lure and be herded into zones are implemented as one generic state machine.
2. Animals use the round animal sprites with waddle tilt, hops, speed lines when fleeing, dizzy stars and drop shadows; items (at least coconut, hat, bucket, sand pail) use item-pack sprites.
3. A thrown item or animal hitting another animal makes it bounce with dizzy stars or flee; no damage, death or blood state exists (validate_code check); every reaction returns to normal behaviour within the balance time (default at most 3 s, test).
4. Items and animals in water, behind walls or outside bounds respawn at their home point after a balance delay (default 2 s) with a smoke puff; a test throws every task-relevant entity type into water and out of bounds and checks the respawn; an entity counted towards a finished task is never respawned away.
5. Headless tests cover herding an animal into a zone, luring with an item, carry and throw of an animal, knockback reaction and respawn.
6. Animal reactions emit EventBus signals with the animal type (animal_fled, animal_bonked, animal_panicked, animal_caught) so audio and feedback can subscribe.

### BI-8 – Slapstick juice and feedback system

- Status: done in 1.0.0
- Priority: 7
- Size: large
- Clarity: clear
- Novel: yes
- UX-relevant: yes

**User story:** As Max, I want every action and every mishap to explode into funny feedback – squash and stretch, BONK!/SPLAT!/WHOOSH! popups, smoke puffs, splats, emotes, screen shake and hit-stop – while the chaos stays readable, so that the game is as funny as it is fast. Covers R-35 (visual part), R-37, R-38 (visual caps), A11, D-5 (effect scaling).

**Acceptance criteria:**

1. A feedback director subscribes to EventBus and maps every action and event (step dust, dash, grab, throw, land, use, task done, bonk, splash, every animal reaction, every event warning, timer warning) to visual entries in data/feedback.json; a test checks every EventBus gameplay signal has at least one visual entry.
2. Effects available: squash and stretch, particles from the particle pack, smoke puffs, splats, emotes over animals and castaway, translated sound-word popups, screen shake, hit-stop (default at most 80 ms) and knockback impulse; each has strength values in data/balance and a global scale factor.
3. With 'reduce screen shake and flashes' on, shake amplitude and flash alpha are 0 or scaled to at most 25 % (test reads the effective values).
4. Caps per effect type live in data/balance; a stress test fires 50 events in one frame and checks the active count per type never exceeds its cap and no error is logged.
5. Effects are family-friendly (no blood, nothing scary; splats are mud, water or sand) and appear in windowed screenshots (checked in BI-14).

### BI-9 – Audio: music, sound effects, jingles, announcer and buses

- Status: done in 1.0.0
- Priority: 8
- Size: large
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As a player, I want chiptune music on every screen, a sound for every action and event, jingles for task done, win and loss and announcer lines that never overlap, with separate volume control, so that the game sounds as lively as it looks from the first release. Covers R-35 (sound part), R-49, R-50, R-51, R-52, R-53, R-54 (buses), R-58, D-1, D-2.

**Acceptance criteria:**

1. Audio buses Master, Music and Effects exist in default_bus_layout.tres (announcer on Effects); a volume API sets Music and Effects from 0 to 1 and 0 mutes the bus (test).
2. Music per D-2: 'Title Screen' on title and level select, 'Level 1'–'Level 3' for levels 1–3, level 4 reuses 'Level 2', level 5 reuses 'Level 3', 'Ending' on the credits screen; tracks loop without a gap (loop flag set on import, checked by a test).
3. data/audio.json maps every action and event (steps, dash, grab, throw, land, splash, bonk, per-animal reactions, task done, event warnings, timer warning) to a sound; a test checks every EventBus gameplay signal has an entry and every entry points to an existing imported file.
4. Jingles for task done, level won and level lost play on the matching signals and duck the music by a balance amount for their duration.
5. The announcer is a single-voice queue ('Go!', 'Hurry up!', 'Time's up!', 'Level complete!'), English audio in both languages; a test enqueues two lines at once and checks only one plays at a time; each line shows a translated caption (German in German mode).
6. Per-sound cooldown and voice limit come from data/balance; a test triggering 30 steps or bonks in one second never exceeds the voice limit.

### BI-6 – HUD, contextual prompts, hints and failure cues

- Status: done in 1.0.0
- Priority: 9
- Size: large
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As Lena and Max, I want tasks, timer, star goal and what Space/E will do always on screen, a hint per task and a short cue saying why something went wrong, so that I never wonder what to do or why I failed. Covers R-22, R-23 (prompt mechanism), R-25 (warning display), R-29 (HUD part), R-36, R-44, A9, A10, A13.

**Acceptance criteria:**

1. The HUD shows the task list with per-task progress (e.g. 1/2) and required/optional marks, the countdown timer (m:ss), the 3-star time goal and the current interact prompt (grab/throw/use with key icon); it sits at screen edges, never overlaps the castaway's screen position and shows no survival stats.
2. In the last 10 seconds the timer pulses and turns warning-coloured.
3. H or a HUD button shows the hint of the first unfinished task (required first) for a balance duration; the timer keeps running (test).
4. Contextual key prompts can be attached to items, animals and targets via level data and disappear permanently for the run once that action has been used (test).
5. Each failure type (animal escaped, item lost to the sea, time's up, dizzy hit, event stole something) has a translation key and shows a short cue next to the funny reaction; a 'Finish!' banner with the finish key appears when all required tasks are done.
6. All HUD texts are translation keys and update live on language switch; an automated overflow test finds no clipped German label at 1280x720 and 1920x1080.

### BI-7 – Game flow, menus, progression and saved settings

- Status: done in 1.0.0
- Priority: 10
- Size: large
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As a player, I want an icon-first title screen, level select with locked/unlocked levels and stars, a short intro card, pause menu, a short result screen and settings that are remembered, so that I can jump into a level in two clicks, retry instantly and keep my progress. Covers R-29 (intro and level select), R-30, R-31, R-32, R-33, R-34, R-45, R-46, R-54 (sliders), R-55, A8, A14, A16, A20, D-2 (credits screen), D-5, D-9.

**Acceptance criteria:**

1. Title screen (play, settings, language toggle, quit), level select, settings, pause, intro card, result screen and a credits screen (asset authors from SOURCES.md, shown after winning level 5 and from the title) exist; every menu works by mouse and keyboard, main actions use UI-pack icons, and a level starts in at most two clicks from the title.
2. Level select shows locked levels as locked; winning level N unlocks N+1; any unlocked level can be replayed; best stars and best time are shown per won level; unlock and best-value logic are covered by tests.
3. The intro card shows level title, tasks (required/optional) and the 3-star time goal before 'Go!', is skippable with any key, and the timer starts only after it.
4. Esc pauses gameplay and the timer and offers resume, restart, settings (with both sliders), level select and quit; R restarts from play or pause and gameplay is running again within 1 s (test measures it).
5. The result screen shows stars, time left and, on loss, the missing required tasks; input is accepted after at most 2 s; retry (R) and next level (Enter) are one key or one click.
6. Settings: language EN/DE (live switch, English on first start), music and effects sliders (0 mutes), 'reduce screen shake and flashes' toggle (off by default); all saved to settings.json.
7. progress.json (unlocks, best stars, best time per level) lies next to settings.json in the DataDir folder; values survive a restart; a corrupt or missing file falls back to defaults without a crash (tests run against the testdata folder).
8. All menu texts are translation keys; an overflow test finds no clipped German label at 1280x720 and 1920x1080.

### BI-10 – Levels 1–2: Beach Camp and Farm Meadow

- Status: done in 1.0.0
- Priority: 11
- Size: large
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As a new player, I want level 1 (Beach Camp) to teach the controls through its layout and prompts and level 2 (Farm Meadow) to ramp up the chaos, so that I learn by playing and immediately feel the slapstick pressure. Covers R-12, R-13, R-15, R-17, R-18, R-23, R-24, D-8 for levels 1–2.

**Acceptance criteria:**

1. Beach Camp and Farm Meadow are handcrafted level scenes with their own tile mix, props, theme and music (D-2); every area is reachable on foot (reachability test on the walkable grid).
2. Default allocation (documented in the level JSON; a swap within the example pools is allowed if a sprite is missing): level 1 – required: put two chickens in the cage, bring coconuts to the monkey; optional: put a hat on the goat; events: parrot steals the hat, monkey throws coconuts. Level 2 – required: herd the ducks into the pond, catch the runaway pig; optional: one farm task of the implementer's choice not used elsewhere; events: rain makes the chickens panic, pig leaves slippery mud (new mechanic: slippery ground).
3. Each event has a warning cue, an animation, a sound and a funny reaction; timers lie between 180 and 300 s with level 2 tighter relative to its workload than level 1.
4. Level 1 shows contextual key prompts (move, grab, throw, use) near the first item, animal and target that disappear once used; no tutorial screen or tutorial level exists.
5. Both levels pass validate_levels.py and a headless test completes all their tasks via the engine with events active.

### BI-11 – Levels 3–5: Jungle, Lagoon and Volcano Cliffs

- Status: done in 1.0.0
- Priority: 12
- Size: large
- Clarity: clear
- Novel: no
- UX-relevant: yes

**User story:** As an action fan and completionist, I want three more distinct, increasingly demanding levels (Jungle, Lagoon, Volcano Cliffs) with new animals, mechanics and overlapping events, so that the 20–30 minute first run keeps escalating and rewards replays for 3 stars. Covers R-12, R-13, R-15, R-17, R-18, R-24, R-72, D-8 for levels 3–5.

**Acceptance criteria:**

1. Jungle, Lagoon and Volcano Cliffs are handcrafted level scenes with their own tile mix, props, theme and music (D-2); every area is reachable on foot (reachability test).
2. Default allocation (documented in the level JSON, swaps within the pools allowed): level 3 Jungle – new animals frog and parrot, e.g. return the frogs to the pond and the parrot to its perch; events: goat stampede, monkey coconuts. Level 4 Lagoon – deliver the lost penguin to the beach, build a sandcastle before the wave comes; events: wave washes items around (new), parrot steals the hat. Level 5 Volcano Cliffs – 4–5 tasks mixing earlier animals in new combinations with at least 3 events, two of which can overlap.
3. Across all five levels at least five of the seven example tasks appear, none repeated identically (test over all level files).
4. Timers and event density come from data; level 5 has more tasks and events than level 1; docs/playtest.md records the 3-star time and first-run time per level (target 3–5 minutes each, 20–30 minutes in total).
5. All three levels pass validate_levels.py and a headless test completes all their tasks via the engine with events active.

### BI-12 – Bot playthrough of all levels under worst-case event timing

- Status: done in 1.0.0
- Priority: 13
- Size: large
- Clarity: clear
- Novel: no
- UX-relevant: no

**User story:** As the completionist Tom and as the team, I want automated proof that every task of every level can be completed with 3 stars even when events hit at the worst moment, so that the release has no soft-locks. Covers R-20 (proof), R-21 (worst case), R-67, R-66.

**Acceptance criteria:**

1. A bot drives the castaway only through the input actions (move, dash, interact, finish) in the real level scenes, headless, with a fixed timestep.
2. For each of the five levels the bot completes all tasks and ends with 3 stars for at least 3 fixed seeds plus the worst-case schedule (every event at the earliest and at the latest end of its window).
3. The bot run is part of python tools/run_tests.py, writes a per-level summary (seed, tasks done, time left, stars) below the testdata folder and fails with the level, seed and stuck task on failure.
4. A failure injection test (bot throws every task entity into water once) still completes the level, proving respawn under play conditions.

### BI-14 – Windowed smoke run, performance, German clip check, content review and export

- Status: done in 1.0.0
- Priority: 14
- Size: large
- Clarity: clear
- Novel: no
- UX-relevant: no

**User story:** As the team, I want a windowed smoke run that proves rendering, audio, 60 fps and non-clipping German texts, a documented content review and a working Windows build, so that the release looks, sounds and ships right. Covers R-40 (measure), R-41 (visible), R-47, R-48, R-57, R-63, R-68, R-71, R-37 (visible).

**Acceptance criteria:**

1. tools/smoke.py opens the game window (windowed exe), loads the title and each level for a few seconds, starts music and effects, captures a screenshot sequence at 1920x1080 and 1280x720 below the testdata folder and fails on any engine error or warning about audio or rendering in the log.
2. The smoke run logs average frame time over a scripted 60-second level run and fails on any frame time above 33 ms after the first second (reference machine = development machine).
3. A clip check in German at both resolutions over title, level select, settings, pause, intro card, HUD, prompts, cues, result and credits finds no overflowing label; the castaway bounding box measures at least 64 px at 1920x1080.
4. docs/content_review.md holds a checklist (no violence, weapons, scary images or sounds, no animal harm, slapstick only) with each item checked against assets, texts and screenshots.
5. export_presets.cfg contains a Windows preset; tools/export.py produces build/TerralonsFunnyIsle.exe and runs a headless smoke start of the exe, or reports clearly that export templates are missing; build/ is git-ignored.
6. run_tests.py can run the windowed stages via an opt-in flag so the default headless run stays window-free.
