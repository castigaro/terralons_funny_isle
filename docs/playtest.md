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
