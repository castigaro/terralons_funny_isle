# Vision – Terralon's Funny Isle 2

Terralon's Funny Isle 2 is a hectic, single-player, keyboard-first slapstick action game for Windows (Godot 4.7.2, offline, EN/DE). A castaway runs, dashes, grabs, carries and throws animals and items across five handcrafted, fully visible tropical island levels (1 Beach Camp, 2 Farm Meadow, 3 Jungle, 4 Lagoon, 5 Volcano Cliffs) against a 3–5 minute timer, while data-driven funny tasks and seeded slapstick events keep things going wrong. Every action and failure gets a visible, audible, funny reaction; stars, instant retries and deterministic events give replay value.

The backlog keeps v1's island, castaway, tasks, EN/DE support and proven tooling (test runner, play/export scripts, i18n, Balance autoload, data-folder override) and replaces turn-based survival, fog of war and placeholder art with real-time action, polished CC0 art and full audio.

Release 1 = all must requirements of R-1..R-72; the cheap should/could items R-17, R-34, R-58, R-69, R-70, R-72 are included; gamepad, key rebinding, extra levels and online features stay out (non-goals).

## Refinement changes

BI-1 split into foundation/tooling (BI-1) and asset import/validator (BI-13); BI-12 split into bot playthrough (BI-12) and windowed smoke, performance, clip check and export (BI-14); BI-10/BI-11 made clear with a default task/event allocation; vague criteria quantified with balance defaults; missing requirement details added (R-10 latency, R-54 sliders also in pause, R-55 language switch on title, R-41 screenshot sequence).

## PO assumptions

- The target repo may be empty, so BI-1 initialises Git on main if needed (done in project setup).
- Restart key R, hint key H, finish key Enter or F; announcer runs on the Effects bus; the bot drives the game through the same input actions as the player.
- "Reference machine" for performance means the development machine; "returns to normal within a few seconds" defaults to at most 3 s; "readable at 1280x720" means animals and items at least 24 px on their shorter side at that resolution.
- The concrete per-level task/event allocation in BI-10/BI-11 is a default the implementer may swap within the example pools if a sprite is missing, documented in the level JSON.

## Suggested build order (4 parallel worktrees)

BI-1 first; then BI-13, BI-3, BI-2 in parallel; then BI-5, BI-4, BI-8, BI-9; then BI-6, BI-7, BI-10; then BI-11, BI-12, BI-14.

## Release 1.1.0 – Finished-look release

Release 1.1.0 makes the game look and read finished without touching gameplay: a readable display font with full EN/DE glyphs, one clean result screen, a HUD 3-star target a player understands at a glance, a live island scene behind every menu, and textured ground without flat placeholder shapes. Difficulty, timers, tasks and events stay as in 1.0.0 until human player feedback is in. Per-theme level items BI-20 to BI-23 and BI-24 stay open (6-item cap).

PO assumptions: (1) no external services, so no new packs are downloaded; missing elements (barn, huts, lava) are composed or derived from existing CC0 sprites by a tool script and recorded in assets/SOURCES.md; (2) readability is verified by tools/playtest.py screenshots at 1920x1080 plus a 1280x720 pass and the windowed clip stage; (3) level scene files are per-level, so theme items can run in parallel after BI-19; (4) the release is 1.1.0 with a local v1.1.0 tag.
