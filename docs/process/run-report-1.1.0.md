# Run report – Release 1.1.0

## Wishes of this round

Make the game look and read like a finished game without touching gameplay: readable font, clean result screen, clear HUD 3-star target, live menu backdrop, no flat placeholder shapes and themed levels. Difficulty, timers, tasks and events stay unchanged. The six wishes were split into backlog items BI-15 to BI-25; the six-item cap deferred the per-theme level items BI-20 to BI-23.

## Release goal

Finished-look release 1.1.0 with a fresh export. Achieved in part: BI-15, BI-16 and BI-17 shipped, BI-19, BI-18 and BI-25 did not, so wishes 4, 5 and 6 are still open. The export `build/TerralonsFunnyIsle.exe` was built on 2026-11-22 15:42 (version 1.1.0.0, 136.0 MB, export smoke OK).

## Items

| ID | Title | Path through the process | Rework rounds | Status |
|---|---|---|---|---|
| BI-15 | Readable display font, one-line HUD task names | UX, prototype, develop, review, rework, merge (9550aca) | 1 | done in 1.1.0 |
| BI-16 | Result screen with one headline and one star animation | UX, develop, review, merge (e3fc9f3) | 0 | done in 1.1.0 |
| BI-17 | Clear HUD 3-star target with live reachability | UX, develop, review, rework, merge (a4c8e9f) | 1 | done in 1.1.0 |
| BI-19 | Textured ground, no flat placeholder shapes | UX, develop, merge attempt failed | 0 | open (merge failed) |
| BI-18 | Live island scene behind menus | skipped, depends on BI-19 | 0 | open |
| BI-25 | Full visual pass, tag and fresh export | skipped, depends on BI-19 and BI-18 | 0 | open (export and visual pass done in the release step) |
| QA-1 | One 'GO!' cue at level start | found in release QA | 0 | open |
| QA-2 | No leftover popup behind the credits | found in release QA | 0 | open |

## Rework rounds

- BI-15: the wider HUD task column ran under the world prompt at the cage gate in L1; fixed in round 1.
- BI-17: the TimerPanel grew past the right screen edge when the tick appeared after a 3-star win; fixed by refitting the panel and adding a gap between stars and label.

## Open points

- BI-19: the --no-ff merge into main turned run_tests.py red in the hygiene check ("the real user folder changed" under the Godot app_userdata folder); main was reset. Cause not verified; the branch `feature/BI-19` is kept, its worktree was removed in the release step. Next step: re-run the merge and find which test touches the real user folder.
- BI-18 and BI-25 depend on BI-19. BI-20 to BI-24 stay open.
- QA-1 and QA-2 (see backlog).
- Seen in review, not filed: the BONUS tag sits close to the title in EN rows; a typed `EventActor` parameter in `event_effects.gd::_launch_nut` can log "Cannot convert argument 1 from Object to Object" when the nut is freed before the timer fires (did not appear in the release playtest logs).
- Visual check of the release playtest (EN and DE, 49 shots each): fonts, umlauts, '%' and one-line HUD titles read correctly, the result screen has one headline and three stars, the 3-star goal is clear. Still visible: flat green rectangles in L1, L3, L4 and L5, plain light-blue menu backdrop, double 'GO!' at level start.
- The windowed game was not played by hand; the bot-driven playtest covered title, level select, settings, all five levels, pause, win, loss and credits.

## Deviations from the requirements

- The release goal "no flat placeholder shapes, live backdrop" is not met; the changelog lists this under known limitations.

## Process observations

- The hygiene check fires on a merge that passes in its own worktree; running the full test suite in the worktree after merging main in would not have caught it, so the failure only shows on main.
- A dependent item chain (BI-19 to BI-18 to BI-25) lets one failed merge skip half of the round; independent items (BI-15 to BI-17) were unaffected.
- Reviews caught two real layout regressions (BI-15, BI-17) that the clip stage missed, because it does not check world prompts or the live tick switch.
