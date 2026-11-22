# Playtest log (R-24, R-72)

Release 1.0.0 target: levels of about 3–5 minutes, a first run of about 20–30 minutes in total. The 3-star limit is the level timer × (1 − `three_star_time_share` 0.25), so a 3-star run has to finish within timer × 0.75.

## Per level (BI-11)

Bot times come from the headless completion tests (`tests/levels/test_complete_*.gd`, seeded schedule, events active, 60 fps fixed clock). "Bot, no wait" is the pure work time (`TFI_BOT_NO_HOLD=1`, measured for L3–L5; L1 and L2 from the BI-10 notes in `docs/levels.md`), "bot, held" is the test as committed, which holds the last task until every event has ended. First-run times are an estimate (bot, no wait × 3, assumption A-2), not a measurement with a human player.

| Level | Timer | 3-star: finish within | Bot, no wait | Bot, held | First run (source) |
|---|---|---|---|---|---|
| `l1_beach_camp` | 240 s | 180 s (3:00) | about 15 s | 90.8 s | about 45 s (estimate) |
| `l2_farm_meadow` | 210 s | 157 s (2:37) | about 30 s | 115.3 s | about 90 s (estimate) |
| `l3_jungle` | 200 s | 150 s (2:30) | 38.6 s | 131.2 s | about 116 s (estimate) |
| `l4_lagoon` | 260 s | 195 s (3:15) | 63.0 s | 191.4 s | about 189 s (estimate) |
| `l5_volcano_cliffs` | 250 s | 187 s (3:07) | 61.6 s | 114.2 s | about 185 s (estimate) |
| Total | 1160 s (19:20) | 870 s (14:30) | about 208 s | 642.9 s | about 625 s, 10:25 (estimate) |

## Reading

- The bot knows every target, never misses a grab and walks shortest paths, so the × 3 estimate is a lower bound. It puts L4 and L5 at about 3 minutes (inside the 3–5 minute range) and L1–L3 below it; the estimated total of about 10 minutes is below the 20–30 minute target.
- The upper bound of a first run without restarts is the sum of the timers, 19:20. Restarts for missed optional tasks (sandcastle, goat before the stampede, feeding before the rain) and replays for 3 stars add to it. Whether the real first run reaches 20–30 minutes needs a human run; it is handed to the windowed smoke run of BI-14 as an open point, and the timers (180–300 s rule) stay as they are until then.
- Escalation holds in the data: seconds per work unit fall from 48 (L1) to 35.7 (L5), L5 has four tasks and three events (L1: three and two), two of which always overlap (the bot test sees two active events at once), and the first event window of L4 and L5 opens at 20 s.

## Decision on the L1 and L2 event windows

Unchanged (25–45 s and 20–40 s first windows). With the estimated first runs of about 45 s and 90 s the first event of L1 and both events of L2 fire during a normal first run; only a very fast replay can finish L1 before its parrot raid, which is fine for a learning level.

## Windowed check

The three new levels were rendered with the windowed binary (`python tools/capture_level.py --level res://scenes/levels/<id>.tscn`, output in the testdata folder): castaway 98 px (L3, L5) and 146 px (L4) tall at 1080p, the theme mix (jungle grass and trees, sand ring and lagoon, rock clusters) reads as intended. An interactive play-through by a person was not possible in this autonomous run.

## Bot playthrough (BI-12)

`tests/bot/test_bot_<level>.gd` play every shipped level headless on the 60 fps fixed clock. The bot only feeds the real input actions: `tests/support/action_input.gd` presses `move_*` (analog per axis), `dash` and `interact` through `Input.action_press` before the castaway reads them and sends `finish` as an `InputEventAction`; it never sets an input source, moves an entity or calls the session (`tests/core/test_bot_input_only.py` scans for that). A press reaches the castaway one physics tick later, so the driver stands still for two ticks after a throw press. The level knowledge sits in `tests/support/bot_plans.gd` (steps per task: kinds, target zone, use target); `bot_planner.gd` turns it into goals for `level_driver.gd`, `bot_run.gd` runs one level and checks it.

Matrix per level (six runs, L1 eight):

| Run | Schedule | Check |
|---|---|---|
| `plain` × 3 | seeded: the level seed plus two extra seeds from `tests/fixtures/bot/seeds.json` (pairwise different schedules, checked in `test_bot_selftest.gd`) | won, every task done, 3 stars |
| `hold` earliest / latest | every event at the start or end of its window | as `plain`, and every scheduled event triggered and ended before the win |
| `inject` | level seed | every task entity the bot grabs is thrown into open water once; non-swimmers must be lost with reason `water` and respawn at a reachable point within throw flight + respawn delay + 1 s, swimmers must be free and grabbable again within 25 s; won with every task done |
| `finish_off` (L1) | level seed, `auto_finish_when_all_done` off | REQUIRED_DONE and not won while the bot keeps `finish` back, then the finish action wins with 3 stars |
| `determinism` (L1) | level seed twice | equal entries except `wall_seconds` |

Worst case: the `hold` runs keep the final unit of the last open task back until every scheduled event has ended ("staged" hold: the bot carries the unit to a waiting band of 1.5–2.5 × `use_radius` around the target, so it never sits inside the target zone, and delivers it right after the last event). Throw spots for the injection are found by ray and motion queries only: a reachable cell, a direction, the castaway walking on to the shore line, and a predicted landing on water inside the bounds and outside the thrown kind's own target zones (a throw never counts as a delivery). A kind with no water at all outside its target zones is recorded under `inject_skipped` (L3: the frogs, whose pond is the only water inside the bounds); a kind without a spot in a level that has such water fails the run.

Results of the BI-12 run (elapsed game seconds until the win, 3-star limit in brackets):

| Level | Plain (3 seeds) | Hold earliest | Hold latest | Inject (respawns) |
|---|---|---|---|---|
| `l1_beach_camp` (180 s) | 14.5 / 14.5 / 14.5 | 61.0 | 93.7 | 57.7 (5) |
| `l2_farm_meadow` (157 s) | 35.0 / 35.0 / 35.0 | 78.4 | 108.4 | 58.0 (2) |
| `l3_jungle` (150 s) | 38.0 / 37.2 / 37.9 | 98.4 | 118.4 | 53.5 (2, frogs skipped) |
| `l4_lagoon` (195 s) | 62.6 / 59.6 / 65.7 | 158.4 | 178.4 | 81.2 (3) |
| `l5_volcano_cliffs` (187 s) | 63.0 / 63.0 / 63.0 | 98.2 | 101.0 | 145.8 (6) |
| Total | – | – | – | about 3.5 min wall time for all 32 runs |

L4 latest is the tightest case: the big wave ends at 178 s, the staged hold wins at 178.4 s, 16.6 s inside the 3-star limit. L1 and L5 finish their plain runs before or between the events, so their seeds give the same times. All runs end with 3 stars, the injection runs included.

Each test writes its run to `<testdata>/run_tests/bot/<level>.json` (`TFI_BOT_REPORT_DIR`, set by `tools/common.py`): `{level, runs: [...]}`, one entry per (variant, mode, seed) with result, reason, state, tasks done/total, done ids, time left, elapsed, three-star time, stars, triggered, ended and scheduled event ids, respawns, throws, inject errors and skips, stuck task, last goal, carried kind, `wall_seconds` and `written_at`. `python tools/run_tests.py` prints the fresh runs as a table in its `bot` stage and fails on a missing level or a failed run; a failing test prints `BOT FAIL level=… mode=… seed=… variant=… reason=… stuck_task=… goal=… carried=… elapsed=… tasks=… time_left=…`. `TFI_BOT_TRACE=1` prints goals, throws, losses and respawns of every run.

## Windowed smoke and performance (BI-14)

`python tools/smoke.py` (also the opt-in stages of `python tools/run_tests.py --windowed`, see the README) ran the real game flow in a borderless window at 1920x1080 and 1280x720 on the development machine, which is the reference machine (Windows 11, NVIDIA GeForce RTX 3060 Laptop GPU, OpenGL 3.3 compatibility renderer, vsync on as in the project default).

- **Smoke:** title and all five levels at both sizes, three screenshots each plus one bonk frame per level; the music matched every screen (`title`, `level_1`–`level_3` as mapped in the level data), every level played a shake and a puff for `object_bonked`, and the picture outside the HUD changed by 2.0–7.6 % between the first and the third shot (animated water and foliage, castaway idle). No engine error and no audio or rendering warning in stdout or the log file.
- **Performance:** 60 s bot run (`hold`) on `l4_lagoon` with its first event window at 20 s, frame times taken from the first frame after the intro card:

  | Size | Frames after 1 s | Average | Maximum | Frames above 33 ms |
  |---|---|---|---|---|
  | 1920x1080 | 22089 | 2.67 ms | 12.51 ms | 0 |
  | 1280x720 | 34970 | 1.69 ms | 10.32 ms | 0 |

  Physics ran at 60 ticks per second throughout. The driver presents faster than the display refresh in the borderless window although vsync is reported on; the 33 ms limit holds with a wide margin either way, so no warm-up or other product change was needed.
- **German clip check:** title, level select (stars, open and locked tiles), settings, credits, the intro card of `l4_lagoon` (four tasks, the most of any level), HUD with four prompts, the "Neustart!" level cue and the "Kokosnüsse im Anflug!" HUD cue at once, pause, result win and result loss with every task missing: 0 problems at both sizes. The overlong German fixture text on the Play button was found (6 problems), so the check is live.
- **Castaway size:** 98 px at 1080p in every level (`l1_beach_camp` to `l5_volcano_cliffs`), minimum 64 px.
- **Observation, not changed:** in L1 the world prompt of the use target near the top edge can sit under the task panel, and right after a restart the "Neustart!" cue and the announcer caption ("Los!") stand on top of each other for about a second. Neither clips a text; both are left for a later layout round.
- **Export:** `python tools/export.py` built `build/TerralonsFunnyIsle.exe` (136 MB, pack embedded, version 1.0.0.0), and its headless smoke start printed `SMOKE OK`. With `APPDATA` pointed at an empty folder it exits with 3 and `export templates for 4.7.2 missing at <path>`.

## Lagoon village (BI-22)

- **Runs:** `python tools/playtest.py --levels l4` at 1920x1080 and 1280x720 (EN) and once in German, each with a progress file that unlocks L4 in the run's own data folder (a level-only run cannot start a locked level); the bot won L4 with 3 stars in all three runs (62.3 s bot time, 197.5 s left of 260 s, 24 % used – unchanged by the dressing). `tools/flat_area_check.py` found no flat window in the 21 in-level frames.
- **First sight:** the start frame already shows a stilt hut on the water, the dock leading to it from the south shore and the rowing dinghy; the timed frames add the west, east and north huts with their docks and the two sailing boats. Every actor (castaway, penguin, ducks, items) draws above the docks and stays visible; the huts sit on water where no actor walks, so the y-sort never hides one. The big wave (north-east beach) and the parrot raid (north-west) happen far from the decor.
- **L1 versus L4:** Beach Camp reads as a camp on sand (tent, campfire, crates, dune grass, no water in the middle), the Lagoon as a village on the water (thatched stilt huts, plank docks, boats on the animated water); they share no theme texture and are told apart at a glance.
- **Observation, not changed:** the start frame still shows the "GO!" chip and the big "GO!" text together (QA-1, release preparation); the pack dinghy is upscaled 4.5× and looks slightly soft next to the crisper huts.

The human first run (20–30 minutes, listening pass for the sounds) stays open: no human is available in this autonomous run.
