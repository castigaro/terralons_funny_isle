# Run report – Release 1.2.1

## Findings of this round

Stage fix for the two open findings of the 1.2.0 release QA: QA-3 (hard-edged rectangular grass patches in L1, L2 and L5) and QA-4 (leftover 'HA HA' popup beside the loss result panel). Gameplay, tasks, timers, layout and difficulty stay unchanged.

## Release goal

Not reached in full: QA-4 is fixed and on main, QA-3 is not. The release is therefore not marked ready (readyForRelease = false) and no tag is set. No push.

Build: `D:\projects2\fdp-runs\terralons_funny_isle\build\TerralonsFunnyIsle.exe`, version 1.2.1.0, 136.5 MB, built 2026-11-23 10:26 local time, started once by `tools/export.py` (`SMOKE OK`, content check over all sprites and levels clean).

## Packages

| ID | Title | Finding | Rework rounds | Status |
|---|---|---|---|---|
| FX-2 | No level effect beside the loss result panel | QA-4 | 1 (the fix had not been committed on its branch) | done in 1.2.1 (78268e1) |
| FX-1 | Soft-edged grass patches in L1, L2 and L5 | QA-3 | 2 (L2 straight runs, test gaps) | not accepted, not on main; branch `fix/FX-1` kept (last commit 24c7f08) |

Missing for a release: FX-1. Reason: after two rework rounds the review of the last state did not finish (tests, counter-check and L5 shots were still outstanding), so the merge never happened. Its last reviewer found no defect in the code and recommended a merge if the tests are green and the new tests go red against main's art and layouts. The leftover worktree was removed; the branch stays.

## Deferred findings

None.

## Release QA

- `python tools/run_tests.py` on main with version 1.2.1: ALL TESTS PASSED (syntax 51, import, gdscript 145, bot, python 296, smoke, validators 9, hygiene 2). The version assertions in `tests/core/test_export_tool.py` were raised to 1.2.1.
- Export: `python tools/export.py` built the exe and its smoke run reported `SMOKE OK`.
- Visual check (`python tools/playtest.py --out <testdata>/release`, 49 shots, all five levels won with 3 stars, bot times 14.4 / 36.0 / 38.4 / 62.4 / 66.0 s, loss run of L1 and credits). Looked at: title, L1 to L5 start shots, the loss result and credits. Title and credits are readable and not clipped; one 'GO!' cue per level start; L3 reads as jungle, L4 as lagoon, L5 as dark volcano ground. The loss result (shot 48) shows only the 'TIME'S UP!' panel, no popup or emote beside it (QA-4 fixed). QA-3 is still visible: L1 has plain rectangular grass patches (top left, bottom right, shot 05), L2 has the large flat bright-green area around the start with straight borders (shot 11), L5 has the grey rectangular pool patch in the centre (shot 38). This is the open finding QA-3, not a new one.
- The windowed game was not played by hand; the bot-driven playtest covers the real flow.
- No new QA items found.

## Open points

- QA-3 / FX-1: merge `fix/FX-1` after a complete review (tests, counter-check against main, L5 shots); then build again.
- BI-18, BI-20, BI-22, BI-23 (branches kept), BI-24, the difficulty curve, human playtest, listening pass, unsigned exe.
