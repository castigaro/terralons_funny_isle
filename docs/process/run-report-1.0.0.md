# Run report – Release 1.0.0

## Wishes of this round

Finish release 1.0.0: the earlier develop run was cut off by a Windows reboot after 8 of 14 items. This run developed exactly the open items BI-6, BI-7, BI-10, BI-11, BI-12 and BI-14 with unchanged IDs and kept the version 1.0.0. The eight items BI-1 to BI-5, BI-8, BI-9 and BI-13 were merged by the interrupted run; their status is taken from `git log` (merge commits of feature/BI-1 to BI-5, BI-8, BI-9, BI-13).

## Release goal

A complete, playable five-level slapstick game for Windows with menus, saved progress, English and German texts, audio and an exported exe, verified by tests, a bot playthrough and an opt-in windowed smoke run.

## Items

| ID | Title | Path through the process | Rework rounds | Status |
|---|---|---|---|---|
| BI-1 | Project foundation | earlier run, merged (git log) | n/a | done in 1.0.0 |
| BI-13 | Asset import and validator | earlier run, merged (git log) | n/a | done in 1.0.0 |
| BI-3 | Rules engine | earlier run, merged (git log) | n/a | done in 1.0.0 |
| BI-2 | Castaway controller | earlier run, merged (git log) | n/a | done in 1.0.0 |
| BI-4 | Animals and items | earlier run, merged (git log) | n/a | done in 1.0.0 |
| BI-9 | Audio | earlier run, merged (git log) | n/a | done in 1.0.0 |
| BI-8 | Slapstick feedback | earlier run, merged (git log) | n/a | done in 1.0.0 |
| BI-5 | Level framework and art | earlier run, merged (git log) | n/a | done in 1.0.0 |
| BI-6 | HUD, prompts, hints, failure cues | UX guidelines, develop, review, merge cb3846b | 0 | done in 1.0.0 |
| BI-7 | Game flow, menus, progression, settings | UX guidelines, develop, review with rework, merge 83e46df | 1 | done in 1.0.0 |
| BI-10 | Levels 1–2 | UX guidelines, develop, two review rounds, merge 7cdf4c6 | 2 | done in 1.0.0 |
| BI-11 | Levels 3–5 | UX guidelines, develop, review, merge c482ba4 | 0 | done in 1.0.0 |
| BI-12 | Bot playthrough | develop, review, merge b0c76fb | 0 | done in 1.0.0 |
| BI-14 | Windowed smoke, performance, clip check, content review, export | develop, review, merge e82cc3c | 0 | done in 1.0.0 |

Continuous QA after each merge found no regressions, so there are no new backlog items.

## Rework rounds

- BI-7: slider focus ring did not render, the intro card auto-closed after 6 s, and wording and layout points; reworked and merged.
- BI-10, round 1: the parrot could never steal the worn hat, the use prompt sat 300 px from the cage gate, and an audio test and text nits were missing.
- BI-10, round 2: integration with BI-7 (conflict in `scripts/main.gd`, level ids, `Campaign` as the single level source).

## Open points

- The human first run (20–30 minutes) and a listening pass for the sounds are open (no human in the autonomous run); see `docs/playtest.md` and `docs/content_review.md`.
- Exit-time warnings about leaked ObjectDB instances and resources in headless starts were seen once and not reproduced; not analysed.
- This release step started the game with `tools/play.py --sandbox` for 25 s without errors, but nobody played it through; interactive full play is part of the open human run.
- The exe is not code-signed.

## Deviations from the requirements

None known: no must requirement was reported as not done, and nothing was built against a binding constraint or a non-goal. The not-yet-performed human first run (20–30 minutes) and the sound listening pass are verification gaps, not built deviations.

## Process observations

- The run was interrupted by a Windows reboot after 8 of 14 items; resuming from `git log` and the backlog worked, the worktrees were already gone and the main checkout was on main.
- The backlog status stayed "planned for 1.0.0" through all merges and was only updated at release preparation.
- Parallel items touching shared files (`main.gd`, level ids) caused the BI-7/BI-10 conflict; the later item has to reconcile, which cost a rework round.
- Several commits use Conventional Commits prefixes against the repo's usual style.
- Release checks on main: `python tools/run_tests.py` all green (syntax 37, import 1, gdscript 126, bot 1, python 227, smoke 1, validators 8, hygiene 2); `python tools/export.py` built `build/TerralonsFunnyIsle.exe` (136 MB, version 1.0.0.0) and its smoke start printed SMOKE OK.
