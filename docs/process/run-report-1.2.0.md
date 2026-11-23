# Run report – Release 1.2.0

## Wishes of this round

Finish the look that 1.1.0 left open: textured ground without placeholder shapes (BI-19), a live island scene behind the menus (BI-18) and five levels that each read as their theme (BI-20 to BI-23). Gameplay, tasks, timers and difficulty stay unchanged. Ride-along: QA-1 (one 'GO!' cue), QA-2 (no leftover popup behind the credits) and BI-26 (export smoke check that catches missing sprites).

## Release goal

"Finished Look" 1.2.0. Achieved in part: BI-19 and BI-21 are on main, together with the ride-alongs QA-1, BI-26 and most of QA-2. BI-18, BI-20, BI-22 and BI-23 are not on main (their merges were not completed), so wishes 2, 3, 5 and 6 are still open and levels 1, 2, 4 and 5 still look like plain sand and grass.

Build: `build\TerralonsFunnyIsle.exe`, version 1.2.0.0, 136.2 MB, built 2026-11-23 04:32 local time, export smoke OK including the new content check (all animal and item sprites, all five levels). Local tag: `v1.2.0-rc1` (no push).

## Items

| ID | Title | Path through the process | Rework rounds | Status |
|---|---|---|---|---|
| BI-19 | Textured ground with edge tiles, no flat placeholder shapes | UX, develop, merge failed in 1.1.0 on the hygiene check, merged again (eddc511) | 0 | done in 1.2.0 |
| BI-21 | Themed Jungle with dense vegetation | UX, develop, merge (13bf12f) | 0 | done in 1.2.0 |
| BI-26 | Export smoke check for missing sprites and resources | release preparation | 0 | done in 1.2.0 (no forced-failure test build) |
| QA-1 | One 'GO!' cue at level start | release preparation | 0 | done in 1.2.0 |
| QA-2 | No leftover popup behind the credits | release preparation | 0 | partly: credits clean, loss popup open (QA-4) |
| BI-27 | Release 1.2.0 | release preparation | 0 | done (rc1) |
| BI-18 | Live island scene behind the menus | prototype, UX, develop, merge not completed (tests unfinished) | 0 | open, branch kept |
| BI-20 | Themed Beach Camp and Farm Meadow | UX, develop, merge not completed (tests unfinished) | 0 | open, branch kept |
| BI-22 | Themed Lagoon | UX, develop, merged, red on the hygiene check, main reset | 0 | open, branch kept |
| BI-23 | Themed Volcano Cliffs | UX, develop, review, rework (corner gap), second review blocker, merge not completed | 2 | open, branch kept |
| QA-3 | Hard-edged rectangular grass patches | found in release QA | 0 | open |
| QA-4 | Leftover 'HA HA' popup beside the loss panel | found in release QA | 0 | open |

## Rework rounds

- BI-23: round 1 found light-blue water showing through the south inlet corners of the cliff face and a merge conflict with BI-21 (`sway_prop.gd` tint paths); round 2 still showed the corner patches and found two nearly tautological tests (they only checked the collision strip). The review also asked for a test that composites the shore tile and looks for blue pixels. Not resolved in this round.

## Release QA

- `python tools/run_tests.py` on main with 1.2.0: all stages green (syntax 49, import, gdscript 135, bot, python 276, smoke, validators 9, hygiene 2). After the QA-1 and QA-2 changes one existing test (`test_result_headline`) contradicted the new behaviour (it expected a caption for the 'go' line) and was adapted; the final full run is recorded in the commit step.
- The hygiene stage passed in every run of this round with no second Godot session running.
- Visual check (`tools/playtest.py --locale en`, 49 shots, all five levels won with 3 stars, bot times 14.5 / 35.6 / 38.1 / 62.3 / 62.9 s; timers and results match earlier baselines): the title, level select, settings and credits sit on plain light blue and are readable. One 'GO!' cue at the start of L1 and L5 (QA-1 verified). The credits show only their panel (QA-2 verified for the credits). L3 reads clearly as jungle (dense foliage, dark textured ground) and differs strongly from L2. L4 shows sand and flat-looking water only, L5 looks like a beach with grey rocks, not a volcano. L1, L2 and L5 still contain rectangular grass patches with straight borders (QA-3). The loss result shows a small 'HA HA' popup right of the panel (QA-4). No clipped text, no empty screens. The windowed game was not played by hand; the bot-driven playtest covered all screens.
- The exe smoke was run once after the build (`SMOKE OK`).

## Open points

- BI-18, BI-20, BI-22, BI-23: branches kept; the next round has to merge them one after another (BI-20 and BI-22 first; BI-23 contains both and needs its corner fix) and run the tests in each worktree without other Godot sessions running. BI-23's `sway_prop.gd` tint conflict is already resolved on its branch (`tint_key = "volcano_ash"`).
- QA-2 criterion 2 and 3, QA-3, QA-4, BI-24, the difficulty curve, human playtest, listening pass, unsigned exe, `EventActor` conversion warning, BONUS tag spacing.
- BI-26 criterion 3 (a test build with a forced missing sprite) is covered only by a unit test of the output filter; the exe smoke itself was verified on the good build.

## Deviations from the requirements

- The goal "five levels that each read as their theme" and the live backdrop are not met; the changelog lists this under known limitations.
- Assumption: QA-1 keeps the big popup and hides the chip of the 'go' voice line, because the feedback tests depend on the popup and the chip is a caption of the voice only.

## Process observations

- Four of six items ended as "merge not completed", three of them because the merge step's `run_tests.py` did not report back within the session (several Godot test suites ran at the same time on one machine) and not because of a red result. Parallel merge checks compete for the same CPU and the same real user folder; the hygiene stage is sensitive to that.
- The BI-22 hygiene failure and the 1.1.0 BI-19 failure were not reproduced when the suite ran alone, which supports the explanation that parallel sessions touch the real user folder rather than a test.
- The reset after a red main (BI-22) correctly protected main but left BI-23 branched from a state that contained BI-22; a dependency on "main as it was" should be recorded in the item.
- Reviews again found real visual defects (BI-23 corners) that the tests passed because the tests checked the same collision strip the fix painted.
- Release preparation changed code (smoke content check, QA-1, QA-2) because the ride-along items had not been implemented earlier; a full test run takes about 10 minutes, so edits had to wait for the running suite.
