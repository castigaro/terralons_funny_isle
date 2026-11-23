# Run report – Release 1.2.1

## Findings of this round

Stage fix for the two open findings of the 1.2.0 release QA: QA-3 (hard-edged rectangular grass patches in L1, L2 and L5) and QA-4 (leftover 'HA HA' popup beside the loss result panel). Gameplay, tasks, timers, layout and difficulty stay unchanged.

## Release goal

Reached: QA-3 and QA-4 are fixed and on main, local tag `v1.2.1-rc1`. No push.

The workflow run itself ended without FX-1: after two rework rounds the review of the last state did not finish (tests, counter-check and L5 shots were still outstanding), so the run set no tag and reported the gap. The review was then completed outside the run and FX-1 merged (see Packages).

Build: `build\TerralonsFunnyIsle.exe`, version 1.2.1, 136.5 MB, built 2026-11-23 15:43 local time after the FX-1 merge, started once by `tools/export.py` (`SMOKE OK`, content check over all sprites and levels clean).

## Packages

| ID | Title | Finding | Rework rounds | Status |
|---|---|---|---|---|
| FX-2 | No level effect beside the loss result panel | QA-4 | 1 (the fix had not been committed on its branch) | done in 1.2.1 (78268e1) |
| FX-1 | Soft-edged grass patches in L1, L2 and L5 | QA-3 | 2 (L2 straight runs, test gaps) | done in 1.2.1 (merge ef0970f, after a completed review outside the run) |

Completed FX-1 review: counter-check with main's `grass_edges@2.png`, layouts and level scenes on the branch – `tests/levels/test_ground_texture.gd` fails (4 failures); with the branch state restored and merged, the full check run is green apart from the hygiene stage (see Release QA); playtest shots of L1, L2 and L5 show rounded grass outlines with outer and inner corners.

## Deferred findings

None.

## Release QA

- `python tools/run_tests.py` on main after the FX-1 merge: syntax 51, import, gdscript 145, bot, python 296, smoke, validators 9 all pass. The hygiene stage failed once because the game was played by hand at the same time (it wrote `progress.json` in the real user folder); that is the intended parallel-play warning, not a defect of the change.
- Export: `python tools/export.py` built the exe and its smoke run reported `SMOKE OK`.
- Visual check (`python tools/playtest.py --out <testdata>/pt-121`, all five levels won with 3 stars, bot times 14.4 / 36.7 / 37.8 / 62.2 / 63.9 s, loss run of L1 and credits). L1 (shot 05), L2 (shot 09) and L5 (shot 21) show soft, rounded grass and pool outlines, no straight rectangle borders (QA-3 fixed). The loss result (shot 24) shows only the 'TIME'S UP!' panel, no popup or emote beside it (QA-4 fixed).
- No new QA items found.

## Open points

- BI-24 clean exit, the difficulty curve, human playtest, listening pass, unsigned exe.
