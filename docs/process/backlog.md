# Backlog – Release 1.0.0

| Prio | ID | Title | Size | Clarity | Novel | UX | Status |
|---|---|---|---|---|---|---|---|
| 1 | BI-1 | Project foundation, reused tooling and core autoloads | large | clear | no | no | planned for 1.0.0 |
| 2 | BI-13 | Asset import, SOURCES.md and asset validator | small | clear | no | no | planned for 1.0.0 |
| 3 | BI-3 | Data-driven level, task, event, timer and star rules engine | large | clear | no | no | planned for 1.0.0 |
| 4 | BI-2 | Castaway real-time controller: move, dash, grab, carry, throw, use, dizzy | large | clear | yes | yes | planned for 1.0.0 |
| 5 | BI-5 | Level scene framework, camera and polished environment art | large | clear | yes | yes | planned for 1.0.0 |
| 6 | BI-4 | Animals and items: behaviours, herding, hit reactions and respawn | large | clear | no | yes | planned for 1.0.0 |
| 7 | BI-8 | Slapstick juice and feedback system | large | clear | yes | yes | planned for 1.0.0 |
| 8 | BI-9 | Audio: music, sound effects, jingles, announcer and buses | large | clear | no | yes | planned for 1.0.0 |
| 9 | BI-6 | HUD, contextual prompts, hints and failure cues | large | clear | no | yes | planned for 1.0.0 |
| 10 | BI-7 | Game flow, menus, progression and saved settings | large | clear | no | yes | planned for 1.0.0 |
| 11 | BI-10 | Levels 1–2: Beach Camp and Farm Meadow | large | clear | no | yes | planned for 1.0.0 |
| 12 | BI-11 | Levels 3–5: Jungle, Lagoon and Volcano Cliffs | large | clear | no | yes | planned for 1.0.0 |
| 13 | BI-12 | Bot playthrough of all levels under worst-case event timing | large | clear | no | no | planned for 1.0.0 |
| 14 | BI-14 | Windowed smoke run, performance, German clip check, content review and export | large | clear | no | no | planned for 1.0.0 |

### BI-1 – Project foundation, reused tooling and core autoloads

- Status: planned for 1.0.0
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

- Status: planned for 1.0.0
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

- Status: planned for 1.0.0
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

- Status: planned for 1.0.0
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

- Status: planned for 1.0.0
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

- Status: planned for 1.0.0
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

- Status: planned for 1.0.0
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

- Status: planned for 1.0.0
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

- Status: planned for 1.0.0
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

- Status: planned for 1.0.0
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

- Status: planned for 1.0.0
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

- Status: planned for 1.0.0
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

- Status: planned for 1.0.0
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

- Status: planned for 1.0.0
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
