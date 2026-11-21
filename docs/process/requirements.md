# Requirements – Terralon's Funny Isle 2

Stage: spec. Sources: idea.md (binding), vision.md, market.md, personas.md, assumptions.md (all rows decided: 22 confirmed, 1 rejected and corrected), reference.md.

## Vision

Terralon's Funny Isle 2 is a hectic, single-player, keyboard-first slapstick action game for Windows, playable offline in English and German. A castaway runs, dashes, grabs, carries and throws animals and items across five handcrafted tropical island levels, each fully visible and racing a 3–5 minute timer, while absurd tasks pile up and funny events keep derailing the plan. Every action and every failure produces a visible, funny reaction – BONK!, dizzy stars, smoke puffs, splats, squash and stretch, screen shake – backed by music and sound effects from the first release.

It targets players aged 8 and up including teens and adults who like hectic party chaos (Overcooked, Untitled Goose Game, Moving Out). Families are welcome, but difficulty and pace target action fans, not cozy players (correction of assumption 4). It is family-friendly slapstick without violence, without harm to animals and without any survival mechanics.

It keeps the island, the castaway, the funny tasks and the EN/DE support of version 1 and replaces its slow turn-based, fog-covered, placeholder-art loop with real-time action, polished CC0 art and full audio. Replay value comes from star goals, deterministic event schedules and instant retries; polish (juice, sound, comic timing) matters more than feature count.

## Binding constraints

Verbatim from idea.md:

- **Real-time action, not turn-based.** Continuous movement (WASD/arrow keys, Shift to dash, Space/E to grab, throw and use), lots of motion on screen: running, dashing, throwing, animals reacting and fleeing, knockback, squash and stretch, screen shake, hit-stop, particles.
- **Character: hectic slapstick comedy, not cozy.** Time pressure through a level timer; things going wrong is part of the fun. Every action and every failure produces a visible, funny reaction (BONK!, dizzy stars, smoke puffs, splats, emotes).
- **No survival mechanics at all:** no hunger, energy, health, food, resting or fainting.
- **Five complete, handcrafted levels**, each a distinct island area with its own theme and layout. The whole level is always visible and explorable – no fog of war, no tile-by-tile reveal. The camera follows the player smoothly if a level is larger than the screen.
- **Level structure:** each level has 3–5 funny tasks and at least 2 funny random events, a timer of about 3–5 minutes, and a result screen with 1–3 stars (tasks done, time left). A level is won when its required tasks are done; levels unlock in order; retry at any time. Level progress and settings are saved locally.
- **Graphics:** a polished 2D top-down look in the style of GDQuest demos and Kenney top-down games – clean vector art, bold outlines, large readable sprites (the castaway at least 64 px tall at 1920×1080), soft drop shadows, animated water, swaying foliage. Use the provided CC0 asset packs in `<spec folder>/assets/` (island tiles, top-down characters, animals, foliage, items, particles, smoke, splats, emotes, UI, fonts). No tiny tiles and no procedural placeholder boxes.
- **Sound from the first release:** music on the title screen and in every level (the provided chiptunes), a sound effect for every action and event (steps, grab, throw, splash, bonk, animal reactions, task done), jingles for task done, level won and level lost, announcer lines where they fit ("Go!", "Level complete" …), separate volume sliders for music and effects.
- **Assets:** setup copies `<spec folder>/assets/` into the repo (`assets/`), keeps `SOURCES.md` with source and licence of every pack, and imports only what the game uses. No sprites with weapons or violence; animals are never harmed.
- **Family-friendly:** slapstick only, no violence, nothing scary.
- **Languages:** English (default) and German, switchable in-game; every player-facing text is a translation key, German text must not clip.
- **Platform and stack:** Windows desktop, offline, Godot 4.7.2 with GDScript, Python (standard library) for tooling and tests. Starts with `python tools/play.py`; a Windows export preset and build script are kept.
- **Reuse from the reference product** where the code would otherwise be rewritten identically: test runner and `tools/run_tests.py`, `tools/play.py`, the i18n loader and validator, the data-folder override for tests, the Balance autoload pattern (tuning numbers in `data/balance/*.json`), the Windows export preset and build script. Gameplay, levels, presentation and audio are new.
- **Audience:** players aged 8 and up including teens and adults who like hectic party chaos (Overcooked, Untitled Goose Game, Moving Out); difficulty and pace target action fans, not cozy players.
- **Quality:** headless automated tests for the game rules; a scripted or bot playthrough proves that every task of every level can be completed; a windowed smoke run checks rendering and audio start without errors.

Confirmed assumptions from idea.md (verbatim):

- Single player only, keyboard first; mouse is used for menus.
- Baseline resolution 1920×1080 in a resizable window, still readable at 1280×720.
- A level takes about 3–5 minutes; the whole game about 20–30 minutes for a first run.
- Task and event content is data-driven (JSON), so levels can be tuned without code changes.
- Animals available in the asset pack (chicken, chick, goat, pig, duck, parrot, monkey, frog, penguin, cow …) replace the old crab.
- Example tasks: put two chickens in the cage, herd the ducks into the pond, put a hat on the goat, bring coconuts to the monkey, catch the runaway pig, deliver the lost penguin to the beach, build a sandcastle before the wave comes.
- Example events: a parrot steals the castaway's hat, a goat stampede crosses the level, a monkey throws coconuts (BONK – the castaway is dizzy for a moment), a sudden rain shower makes the chickens panic, a wave washes items around, the pig rolls in mud and leaves slippery tracks.

Confirmed during discovery (assumptions.md, binding from now on):

- A1 Stars: 1 star for the required tasks, 2 stars for all tasks, 3 stars for all tasks with generous time left; each level therefore has required and optional tasks.
- A2 Random events run on fixed or seeded per-level schedules with some timing variation, never truly random.
- A3 The castaway carries one item or animal at a time; no inventory slots, no crafting.
- A4 (rejected, corrected) Audience: players aged 8 and up including teens and adults who like hectic party chaos; families are welcome, but difficulty and pace target action fans, not cozy players.
- A5 Items and animals that become unreachable respawn or reset, so every task stays completable after the worst event.
- A6 Events add chaos but never decide the stars alone and never cause a level loss by themselves.
- A7 No tutorial: level 1 teaches the controls through its layout and short contextual prompts.
- A8 The level timer stops during pause and menus; one key restarts the level instantly.
- A9 Every failure shows a short cue saying why it happened, in addition to the funny reaction.
- A10 Star thresholds are visible before and during play; the result screen is short.
- A11 On-screen effects and repeated sound effects are capped or throttled; announcer lines never overlap.
- A12 Sessions are 5–10 minutes, with retries to earn 3 stars.
- A13 Each task keeps a hint.
- A14 Level progress (unlocks, best stars) is stored in a local JSON file next to settings.json in the overridable data folder.
- A15 Stable framerate (target 60 fps) at 1920×1080 and 1280×720 without physics jitter.
- A16 Menus are simple, icon-first and mouse-friendly.
- A17 The plugin architecture of v1 is dropped; only the EventBus idea is kept.
- A18 A gamepad is a nice-to-have and not in scope for the first release.
- A19 No leaderboards or online features.
- A20 Best time and best stars per level are shown (could-have).
- A21 Distribution is free or a small indie release outside any store; hobby scale.
- A22 A notable share of players play in German; English stays the default.
- A23 Personas include a completionist/speedrunner who replays levels for 3 stars and notices bugs.

## Personas

Inferred, not researched; consistent with the corrected audience (8+, teens and adults who like party chaos, action-fan pace).

- **"Lena", 34, German casual-to-action PC gamer.** Plays 20–30 minute sessions on a Windows laptop, likes Overcooked-style chaos. Wants instant fun, tasks and timer on screen at all times, fast retry, an in-game language switch and German text that never clips. Hates hidden goals, tutorial walls and long result screens.
- **"Max", 10, action-loving kid.** Laughs at BONK, dizzy stars and fleeing animals and wants 3 stars. Needs large readable sprites, forgiving grab and throw hit areas, a clear "why did I fail" cue, icon-first menus and nothing scary or violent; animals must never be harmed. A parent may watch, but the game does not slow down for cozy play.
- **"Tom", 28, completionist and speedrunner.** Replays levels for 3 stars and best times, notices bugs. Needs deterministic events, visible star thresholds, no soft-locks, stable 60 fps without physics jitter, a timer that stops in pause, persistent progress and volume settings.

## Requirements

Priority: must / should / could. Source: user = idea.md binding constraints or idea.md confirmed assumptions; confirmed = assumptions.md rows confirmed (or corrected) by the user; inferred = derived by this catalogue or the discovery roles and not yet confirmed.

### Controls and core loop

| ID | Requirement | Priority | Source | Rough acceptance criteria |
|---|---|---|---|---|
| R-1 | Real-time continuous movement of the castaway with WASD and arrow keys, including diagonals | must | user | Holding a direction moves the castaway smoothly every frame; diagonal speed is normalised; no tile snapping, no turns or action points exist anywhere in the code or UI |
| R-2 | Shift triggers a dash: a short speed burst with a cooldown | must | user | Pressing Shift while moving produces a visible dash (dust, stretch) and a sound; dash distance and cooldown come from `data/balance/*.json`; dash stops at walls and shorelines and never carries the castaway into water or through solid objects |
| R-3 | Space or E grabs the nearest grabbable item or animal in front of the castaway; pressing again while carrying throws it in the facing direction; context "use" (put into cage, put hat on, deliver) happens on the same keys when a target is in range | must | user | Both keys behave identically; grab works within a forgiving radius set in balance data; a contextual prompt shows what Space/E will do; headless tests cover grab, throw, use and no-target cases |
| R-4 | The castaway carries exactly one item or animal at a time; no inventory slots and no crafting | must | confirmed | Grabbing while carrying is impossible (the key throws instead); no inventory UI or recipe data exists |
| R-5 | Thrown items and animals fly in an arc, land with squash and stretch, can knock other objects and animals back and cause slapstick reactions | must | user | Throw shows a trajectory and a shadow; landing triggers particles and a sound; hitting an animal makes it bounce and show dizzy stars or flee, never a damage or death state |
| R-6 | Animals have simple real-time behaviours: wander, react to the castaway (flee, follow, panic) and to events; they can be herded, lured, carried and thrown | must | user | Each animal type has data-driven behaviour parameters; animals visibly flee when the castaway dashes towards them; tests check herding into a zone and luring |
| R-7 | Animals are never harmed: no damage, no death, no blood; reactions are bounce, dizzy stars, emotes and running away | must | user | Code review and asset check find no harm states; every hit reaction resolves within a few seconds back to normal behaviour |
| R-8 | No survival mechanics: no hunger, energy, health, food, resting or fainting | must | user | No such stats exist in game state, HUD, balance data or translation keys; a validator or test asserts their absence |
| R-9 | Being hit (coconut, stampede, collision) makes the castaway briefly dizzy or knocked back instead of losing health | must | user | Dizzy state lasts a balance-configured short time with stars above the head and a BONK popup; input resumes afterwards; there is no health value |
| R-10 | Controls feel reliable: input latency of at most one frame, forgiving hit areas, no stuck states | must | inferred | Manual playtest and bot run show no stuck castaway; grab radius and throw aim tolerances live in balance data |
| R-11 | Input map is defined in `project.godot` with the bindings above plus pause (Esc) and instant restart (one key, e.g. R) | must | confirmed | All actions are input-map actions; restart key restarts the current level within 1 second |

### Levels, tasks and events

| ID | Requirement | Priority | Source | Rough acceptance criteria |
|---|---|---|---|---|
| R-12 | Five complete, handcrafted levels, each a distinct island area with its own theme and layout (for example beach, farm meadow, jungle, lagoon, volcano or cliff top) | must | user | Five level scenes or data files exist; each has its own tileset mix, props and music assignment; no procedural map generation |
| R-13 | The whole level is always visible and explorable: no fog of war, no reveal | must | user | No fog, darkness or reveal logic exists; every area of every level can be reached by walking |
| R-14 | The camera follows the castaway smoothly with damping and limits when a level is larger than the screen; it never jerks | must | user | Camera uses smoothing and level bounds; no visible jump on dash, respawn or restart; levels that fit the screen use a fixed camera |
| R-15 | Each level has 3–5 funny tasks, split into required and optional tasks | must | user, confirmed | Level data lists 3–5 tasks with a required flag; at least one required and at least one optional task per level |
| R-16 | Task and event content is data-driven JSON, ported from the v1 task schema (conditions, modifiers, fail-forward, hint) and retargeted to real-time objectives (in zone, held, worn, delivered to, count reached, before time) | must | user, inferred | Levels can be tuned by editing JSON only; a validator checks the JSON schema; a test asserts there is no task-specific code in the engine (generic conditions only) |
| R-17 | Tasks use the example ideas as a pool: chickens in the cage, ducks into the pond, hat on the goat, coconuts to the monkey, catch the runaway pig, lost penguin to the beach, sandcastle before the wave | should | user | At least five of the seven example tasks appear across the levels, with no task repeated identically |
| R-18 | Each level has at least 2 funny random events from a data-driven pool (parrot steals hat, goat stampede, monkey throws coconuts, rain makes chickens panic, wave washes items around, pig leaves slippery mud) | must | user | Each level data file schedules at least two events; each event has a warning cue, an animation, a sound and a visible funny reaction |
| R-19 | Events run on fixed or seeded per-level schedules with timing variation, never truly random | must | confirmed | Same level seed gives the same event order; timing varies within configured windows; tests replay a level deterministically |
| R-20 | Events never decide the stars alone and never cause a level loss by themselves | must | confirmed | Bot playthrough reaches 3 stars on every level with all events active; no event ends a level or removes completed tasks permanently |
| R-21 | Soft-lock prevention: items and animals that become unreachable (in the sea, behind walls, outside bounds) respawn or reset after a short delay with a smoke puff | must | confirmed | Tests throw every task-relevant item and animal into water and out of bounds and verify respawn; bot playthrough under worst-case event timing completes every task |
| R-22 | Each task has a hint the player can show at any time | must | confirmed | Hint is a translation key per task; shown via a key or HUD button without pausing the timer unless the game is paused |
| R-23 | Level 1 teaches the controls through its layout and short contextual prompts; no tutorial screen | must | confirmed | Level 1 shows key prompts near the first item, animal and target; prompts disappear once the action is used; no separate tutorial scene |
| R-24 | Difficulty and pace target action fans: tight timers, overlapping tasks and events, rising difficulty from level 1 to level 5 | must | user, confirmed | Timers and event density come from balance data; level 5 has more simultaneous demands than level 1; a playtest note records the 3-star time per level |

### Timer, scoring, progression and persistence

| ID | Requirement | Priority | Source | Rough acceptance criteria |
|---|---|---|---|---|
| R-25 | Each level has a visible countdown timer of about 3–5 minutes | must | user | Timer value per level in balance or level data, between 180 and 300 seconds; HUD shows it at all times; last 10 seconds have an audible and visible warning |
| R-26 | The timer stops during pause and menus | must | confirmed | Test pauses for N seconds and checks the remaining time is unchanged |
| R-27 | A level is won as soon as all required tasks are done; it is lost when the timer runs out before that | must | user | Win and loss transitions are covered by headless tests; optional tasks can be finished until the timer ends or the player chooses to finish (decision D-3) |
| R-28 | Result screen with 1–3 stars: 1 for the required tasks, 2 for all tasks, 3 for all tasks with generous time left | must | user, confirmed | Star calculation is a pure, tested function; the time threshold for 3 stars is per level in data |
| R-29 | Star thresholds are visible before the level (level select or intro) and during play (HUD) | must | confirmed | Level intro and HUD show which tasks are required and the time goal for 3 stars |
| R-30 | The result screen is short and offers retry, next level and level select | must | confirmed | Result screen is dismissable within 2 seconds; retry and next are one click or one key |
| R-31 | Levels unlock in order; any unlocked level can be replayed at any time | must | user | Level select shows locked levels as locked; winning level N unlocks N+1; tests cover unlock logic |
| R-32 | Instant restart at any time with one key, also from pause | must | user, confirmed | Restart resets the level state, timer and event schedule within 1 second without a loading screen of more than 1 second |
| R-33 | Level progress (unlocks, best stars) and settings (language, music and effects volume) are saved locally in JSON files in the overridable data folder (`-- --data-dir=` or `TFI_DATA_DIR`, CLI wins) | must | user, confirmed | Progress file sits next to settings.json; values survive a restart; a corrupt or missing file falls back to defaults without a crash; tests never touch user folders |
| R-34 | Best time and best stars per level are shown on the level select | could | confirmed | Level select shows best stars and best completion time per level after a win |

### Feedback and presentation

| ID | Requirement | Priority | Source | Rough acceptance criteria |
|---|---|---|---|---|
| R-35 | Every action produces a visible, funny reaction: squash and stretch, particles, sound-word popups (BONK!, SPLAT!, WHOOSH!), emotes | must | user | Each of move, dash, grab, throw, land, use, task done has at least one visual and one sound reaction; a test or checklist maps every action to its feedback entries |
| R-36 | Every failure produces a visible funny reaction plus a short cue saying why it happened (for example "The pig slipped away!", "Time's up!") | must | user, confirmed | Each failure type has a translation key for the cue; result screen on loss names the missing required tasks |
| R-37 | Juice: screen shake, hit-stop on impacts, knockback, smoke puffs, splats, dust trails | must | user | Each effect is tunable in balance data and can be scaled down; effects visible in the windowed smoke run screenshots |
| R-38 | On-screen effects and repeated sound effects are capped or throttled so the chaos stays readable | must | confirmed | Caps per effect type in balance data; a stress test spawns 50 events and checks the active effect count stays under the cap |
| R-39 | Polished 2D top-down art from the provided CC0 packs with a unifying treatment: bold outlines, soft drop shadows, shared palette, clean vector look in the style of GDQuest demos and Kenney top-down games | must | user, inferred | No procedural placeholder boxes or tiny tiles; every visible sprite comes from `assets/`; all actors have drop shadows; a palette file documents the treatment |
| R-40 | Large readable sprites: the castaway at least 64 px tall at 1920×1080, animals and items readable at 1280×720 | must | user | Screenshot test at 1920×1080 measures the castaway bounding box at 64 px or more |
| R-41 | Animated water and swaying foliage | must | user | Water tiles or shader animate continuously; palm and bush sprites sway; visible in the smoke run screenshot sequence |
| R-42 | The castaway and animals have readable motion: walk bob, facing direction, carry pose, throw pose, dizzy pose | must | inferred | Each state has a distinct visual (frame, tween or transform) since the packs provide few animation frames |
| R-43 | No sprites with weapons, violence or scary content; slapstick only | must | user | Asset import list excludes weapon and violent sprites; asset validator flags file names from a deny list |
| R-44 | Always-visible HUD: task list with progress and required/optional marks, timer, star goal, current carry prompt | must | inferred | HUD visible at 1280×720 and 1920×1080 without covering the castaway; never shows survival stats |
| R-45 | Pause menu (Esc) with resume, restart, settings, level select and quit | must | inferred | Pause freezes gameplay and the timer; every entry reachable by mouse and keyboard |
| R-46 | Menus are simple, icon-first and mouse-friendly: title screen, level select, settings, pause, result | must | confirmed | Every menu works by mouse; main actions have icons from the UI pack; no menu needs more than two clicks to start a level |
| R-47 | Stable framerate of 60 fps at 1920×1080 and 1280×720 without physics jitter | must | confirmed | Smoke run logs average frame time; no frame-time spikes above 33 ms in a scripted 60-second run on the reference machine |
| R-48 | Baseline resolution 1920×1080 in a resizable window, still readable at 1280×720 | must | user | Window resizes with a canvas_items stretch or equivalent; UI scales; screenshots at both sizes pass the clip check |

### Audio

| ID | Requirement | Priority | Source | Rough acceptance criteria |
|---|---|---|---|---|
| R-49 | Music on the title screen and in every level from the provided chiptunes | must | user | Each scene has an assigned track; music loops seamlessly; the windowed smoke run confirms the audio stream starts without errors |
| R-50 | A sound effect for every action and event: steps, dash, grab, throw, land, splash, bonk, animal reactions per animal type, task done, event warnings | must | user | A data mapping lists every action and event with its sound; a test checks every entry points at an existing imported file |
| R-51 | Jingles for task done, level won and level lost | must | user | Each of the three jingles plays at the right moment and ducks the music briefly |
| R-52 | Announcer lines where they fit ("Go!", "Level complete", "Time's up", "Hurry up!") that never overlap | must | user, confirmed | Announcer is a single-voice queue; a test fires two lines at once and checks only one plays at a time |
| R-53 | Repeated sound effects are throttled (per-sound cooldown and voice limit) | must | confirmed | Rapid repeated steps or bonks never exceed the voice limit set in balance data |
| R-54 | Separate volume sliders for music and effects (announcer counts as effects unless decided otherwise), saved with the settings | must | user | Two sliders in settings and pause; values persist across restarts; 0 mutes the bus |

### Language

| ID | Requirement | Priority | Source | Rough acceptance criteria |
|---|---|---|---|---|
| R-55 | English (default) and German, switchable in-game from the title screen and settings; the choice is saved | must | user | Switching updates every visible text live without restart; first start shows English |
| R-56 | Every player-facing text is a translation key in the CSV i18n files (key,en,de); the i18n validator from the reference product checks completeness | must | user | Validator fails on any missing key, empty translation or hard-coded player-facing string |
| R-57 | German text must not clip at 1280×720 and 1920×1080 | must | user | Overflow tests or screenshot checks over all menus, HUD, prompts, cues and result screens in German at both sizes find no clipping |
| R-58 | Announcer voice lines are English-only audio from the voiceover pack; in German the matching on-screen text is shown in German | should | inferred | Every announcer line has a translated on-screen caption; see decision D-1 |

### Assets, platform, tooling and quality

| ID | Requirement | Priority | Source | Rough acceptance criteria |
|---|---|---|---|---|
| R-59 | Setup copies the spec folder `assets/` into the repo `assets/`, keeps `SOURCES.md` with source and licence of every pack, and imports only what the game uses | must | user | `SOURCES.md` present in the repo; an asset validator checks every used file belongs to a listed pack and flags unused imports |
| R-60 | Windows desktop, offline, no network access | must | user | No network APIs used; validator or test greps for HTTP and networking classes |
| R-61 | Godot 4.7.2 with GDScript; Python standard library only for tooling and tests | must | user | `project.godot` targets 4.7; no third-party Python packages imported |
| R-62 | The game starts with `python tools/play.py` | must | user | Running the command from the repo root opens the title screen |
| R-63 | A Windows export preset and build script are kept; the build produces a single exe and smoke-tests it | must | user | `tools/export.py` (or equivalent) produces `build/TerralonsFunnyIsle.exe` and runs a smoke check |
| R-64 | Reuse from the reference product in behaviour: test runner (`tests/runner.gd`, `test_case.gd`), `tools/run_tests.py`, `tools/play.py`, the i18n loader and validator, the data-folder override, the Balance autoload with `data/balance/*.json`, export preset and build script | must | user | These tools exist and behave like v1; copied verbatim or adapted (decision D-10) |
| R-65 | All tuning numbers (speeds, dash, throw, timers, star thresholds, effect caps, sound throttles) live in `data/balance/*.json` via the Balance autoload | must | user | A code-rules validator flags magic numbers for tuned values in gameplay scripts |
| R-66 | Headless automated tests for the game rules (movement rules, grab/throw/use, task conditions, events, timer, stars, unlocks, persistence, respawn) | must | user | `python tools/run_tests.py` runs them headless and passes; tests redirect the data folder below the testdata folder |
| R-67 | A scripted or bot playthrough proves that every task of every level can be completed, including under worst-case event timing | must | user, confirmed | Bot completes all tasks (3 stars) on all five levels for at least a fixed set of seeds; run is part of `run_tests.py` |
| R-68 | A windowed smoke run checks that rendering and audio start without errors | must | user | Smoke stage opens a window, loads each level briefly, plays audio, captures a screenshot and fails on any engine error in the log |
| R-69 | The v1 plugin architecture is dropped; a lightweight EventBus decouples gameplay, feedback, audio and HUD | should | confirmed | No `features/<id>` registry; gameplay emits EventBus signals that feedback and audio subscribe to |
| R-70 | Code rules from v1 are kept: comments in English, en dash instead of em dash, enforced by a validator | should | inferred | `validate_code.py` (or equivalent) runs in `run_tests.py` |
| R-71 | Family-friendly content throughout, in text, art and sound | must | user | Content review checklist passes; no scary sounds or images |
| R-72 | Total first-run playtime of about 20–30 minutes, levels of about 3–5 minutes | should | user | Playtest log records first-run time per level within range |

## Non-goals

- Turn-based play, action points, tile-by-tile movement or path preview.
- Fog of war or any reveal mechanic.
- Survival mechanics of any kind: hunger, energy, health, food, resting, fainting.
- Procedural map generation (levels are handcrafted).
- Inventory slots and crafting; recipes.
- The v1 plugin architecture, halftone shader and day panels.
- Co-op, local multiplayer, online features, leaderboards, accounts or telemetry.
- Gamepad support in the first release (nice-to-have later).
- More than five levels or a level editor in the first release.
- Platforms other than Windows desktop; store distribution, monetisation, marketing.
- Violence, weapons, scary content, harm to animals.
- A separate tutorial screen or tutorial level.
- Key rebinding and an accessibility options menu beyond volume and language (except the screen-shake toggle of decision D-5).

## Confirmed assumptions

All 23 rows of assumptions.md are decided. 22 are confirmed as written; row 4 (audience) was rejected and corrected. The confirmed set is listed under Binding constraints (A1–A23); the correction is:

- A4 corrected: players aged 8 and up including teens and adults who like hectic party chaos (Overcooked, Untitled Goose Game, Moving Out); families are welcome, but difficulty and pace target action fans, not cozy players.

Requirements marked "inferred" in the table (R-10, R-16 in part, R-39 in part, R-42, R-44, R-45, R-58, R-70) are derived by this catalogue from the vision, personas and reference analysis and are not separately confirmed by the user; they are listed here so they can be confirmed with the catalogue.

## Decisions on the open questions (binding, decided for the user)

- D-1 (Q-1): English voice lines in both languages, with German captions in German mode.
- D-2 (Q-2): "Title Screen" plays on the title and level select; levels 1–3 use "Level 1–3"; level 4 reuses "Level 2", level 5 reuses "Level 3"; "Ending" plays after level 5 on a short credits screen naming the asset authors from SOURCES.md.
- D-3 (Q-3): When the required tasks are done, the level keeps going: a "Finish!" banner appears, and the player ends the level with a key or keeps playing for optional tasks until the timer runs out.
- D-4 (Q-4): 3 stars need all tasks with at least 25 % of the timer left; the share lives in data/balance.
- D-5 (Q-5): Yes – a "reduce screen shake and flashes" toggle in the settings, off by default.
- D-6 (Q-6): Castaway from the top-down character poses (stand, hold) with tween-based motion: run bob, lean into the direction, squash and stretch on dash and landing, dust trail. Animals use the round sprites with waddle tilt, hops, speed lines when fleeing and dizzy stars when bonked. Drop shadows under everything. This counts as polished.
- D-7 (Q-7): The pack is now present as 62 mp3 files; keep the row.
- D-8 (Q-8): Themes in this order: 1 Beach Camp, 2 Farm Meadow, 3 Jungle, 4 Lagoon, 5 Volcano Cliffs. Each level introduces at least one new mechanic, animal or event.
- D-9 (Q-9): A short intro card (title, tasks, star goals) before "Go!", skippable with any key; the tasks then stay in the HUD.
- D-10 (reuse): The reference product is the user's own earlier version under the same ownership. Copying its files verbatim where they fit (tools/run_tests.py, tools/play.py, tools/common.py, tools/export.py, tests/runner.gd, tests/test_case.gd, the i18n autoload and validate_i18n.py, validate_code.py, the data-folder override, the Balance autoload, export_presets.cfg) is allowed and wanted; this overrides the general "do not copy the reference verbatim" rule for these files. Adapt them where the new game differs.
- D-11 (inferred requirements): R-10, R-16, R-39, R-42, R-44, R-45, R-58 and R-70 are confirmed.

## Open questions

All answered by the decisions above.

- Q-1 Announcer language: the voiceover pack is English only. Keep English voice lines in both languages with German captions (assumed in R-58), or drop voice lines in German mode?
- Q-2 Music coverage: the chiptune pack has five tracks (Title Screen, Level 1–3, Ending) for a title screen and five levels. Assumed: levels 4 and 5 reuse level tracks with variation in order or tempo, and "Ending" plays on the final result or credits. Is a credits screen wanted?
- Q-3 After the required tasks are done, does the level end immediately (stars count only what was done) or can the player keep going for optional tasks until a "finish" key or the timer ends? Star rule A1 suggests the latter.
- Q-4 What exactly counts as "generous time left" for 3 stars – a fixed share of the timer (for example 25 %) or a per-level target time from playtesting?
- Q-5 Accessibility: should there be an option to reduce screen shake and flashing effects (useful for some players and cheap to add), even though it was not requested?
- Q-6 Animal sprites: the animal pack provides round head-style icons without walk frames, and the top-down character pack is a shooter pack with weapons removed. Is a castaway built from the remaining character poses plus tween-based motion (squash, bob, tilt) acceptable as "polished", or should a different character treatment be chosen within the provided packs?
- Q-7 The `audio/sfx-digital/` folder in the provided assets is empty although `SOURCES.md` lists the pack. Remove the row from `SOURCES.md` in the repo, or is the pack expected to be added?
- Q-8 Level themes: five distinct areas are required, but their themes and the order of tasks per level are not fixed. Suggested: beach, farm meadow, jungle, lagoon, volcano cliffs – to be decided in the design stage.
- Q-9 Should the game show a short level intro card (title, tasks, star goals) before "Go!", or should tasks appear only in the HUD? R-29 assumes an intro card or level-select preview.
