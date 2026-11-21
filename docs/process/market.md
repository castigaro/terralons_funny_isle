# Market and product management – Terralon's Funny Isle 2

Stage: discovery. Results taken over from the discovery roles, only structured.

## Market

Without research – from model knowledge, status unchecked.

### Does this already exist?

The core loop does, in the hectic-comedy genre: [Overcooked](https://www.team17.com/games/overcooked/) (chaotic co-op, timers, things going wrong), [Moving Out](https://www.team17.com/games/moving-out/) (throwing, slapstick physics), [Untitled Goose Game](https://goose.game/) (comic mischief, but calm and not timed), and Stardew-style farm-animal games ([Stardew Valley](https://www.stardewvalley.net/); cozy, so not a fit). Close in spirit are Overcooked-like time-pressure games and old top-down party/arcade games. No title I know combines a castaway, a tropical island, animal herding and throwing, five handcrafted levels and a comic look in a single-player Godot game. Nothing in the idea is novel on its own, but the combination is a fairly open niche.

Note: the links are the products' official pages, added for orientation; the statements were not checked against them.

### Trends

- Short, replayable "chaos" games with a star rating do well, and so do slapstick throw-and-carry mechanics.
- Godot top-down games with CC0 art are common, so the look will not stand out by itself.
- Audience reaction to polish (juice, sound, comic timing) matters more than feature count.

### Opportunities

- A single-player, keyboard-first Overcooked feel. Most competitors push co-op, which leaves solo players underserved.
- Family-friendly, offline, free of survival stress and monetisation.
- English and German from the start.
- Data-driven tasks and events make tuning cheap.

### Risks

- Five levels in 20–30 minutes is short, so replay value depends on star goals and the quality of the chaos.
- Frustration if timer pressure and random events feel unfair. Events need to be fun rather than punishing, and retry has to be instant.
- CC0 packs from different authors can look inconsistent, so the art direction needs a unifying treatment (outlines, shadows, palette).
- Animal handling (grab, carry, throw) must stay clearly harmless: animals are never harmed, which means reactions like dizzy stars and bounce.
- Without co-op or online features, discoverability is limited. This is a hobby-scale product.

### Assumptions

- Assumption: the audience is casual players aged 8 and up, plus families, on Windows PC.
- Assumption: distribution is free or a small indie release, outside any store.
- Assumption: sessions are 5–10 minutes, with retries to earn 3 stars.
- Assumption: a gamepad is a nice-to-have, not required.
- Assumption: no leaderboards or online features are wanted.

### Objections

None. The constraints are consistent with each other.

## Product management/BD

### Product vision

Terralon's Funny Isle 2 is a hectic, single-player, keyboard-first slapstick action game. A castaway sprints, dashes, grabs, carries and throws animals and items across five handcrafted tropical island levels, racing a 3–5 minute timer while absurd tasks pile up and random events (parrot hat theft, goat stampede, coconut-throwing monkey) keep derailing the plan. Every action and every failure triggers a visible, funny reaction (BONK!, dizzy stars, splats, squash and stretch, screen shake) with music and sound effects from day one. It is family-friendly, offline, free of survival stress, and available in English and German. It keeps the island, castaway, funny tasks and EN/DE support of version 1, and replaces the slow chess-like turn loop and placeholder art with real-time action, polished CC0 art and full audio.

### Differentiation

Market names Overcooked, Moving Out, Untitled Goose Game, which cover parts of the idea.

Overcooked and Moving Out push co-op; Goose Game is calm and untimed. A solo, timed, castaway-and-animal slapstick game in Godot is a fairly open niche. It is built anyway because the combination is open, the reference product already gives the island, tasks, i18n and tooling, and polish (juice, sound, comic timing) matters more than feature count.

### Features (with reasons)

1. Real-time movement: WASD/arrows, Shift dash, Space/E grab/throw/use. Reason: fixes the core complaint about v1.
2. Grab, carry, throw with knockback; animals react and flee harmlessly (dizzy stars, bounce). Reason: core slapstick loop.
3. Five handcrafted, fully visible levels with a smooth-follow camera. Reason: binding constraint, and it replaces the procedural map and fog of war.
4. Data-driven task engine in JSON, ported from v1's schema (conditions, modifiers, fail-forward) and retargeted to real-time objectives, with a hint. Reason: cheap tuning and reuse.
5. Data-driven random events, at least 2 per level. Reason: the chaos the idea asks for. They must be fun, not punishing.
6. Level timer, result screen with 1–3 stars (tasks done, time left), in-order unlocks, instant retry. Reason: replay value and fairness.
7. Comic feedback layer: sound-word popups, emotes, particles, hit-stop, screen shake. Reason: it is the core appeal.
8. Art direction: CC0 packs with a unifying treatment (outlines, soft shadows, palette), castaway at least 64 px tall at 1080p, animated water and foliage. Reason: avoids inconsistent packs.
9. Audio: title and level music, an SFX per action and event, jingles, announcer lines, separate music and effects sliders. Reason: required from the first release.
10. EN/DE CSV i18n loader and validator, with a German no-clip check. Reason: reuse and a binding constraint.
11. Local save of level progress and settings. Reason: new work, because v1 only saved settings.
12. Tooling reuse: play.py, run_tests.py, export.py, Balance autoload, data-dir override, export preset. Add headless rule tests, a bot playthrough proving every task is completable, and a windowed smoke run.

### Dropped

Turn loop, fog of war, survival, procedural map, crafting and inventory slots, plugin architecture (keep the EventBus idea), halftone shader, day panels.

### Risks

- Unfair timer or events: keep retry instant and events funny.
- Mixed art styles: enforce the unifying treatment.
- Short game: depend on star goals for replay.
- Animal handling must stay clearly harmless.

### Assumptions to confirm

- Audience is casual players aged 8 and up, plus families, on Windows PC.
- Free or small indie distribution outside stores.
- Sessions are 5–10 minutes with retries for 3 stars.
- Gamepad is a nice-to-have, not in scope.
- No leaderboards or online features.
- Star thresholds are tasks done plus time left: 1 star for the required tasks, 2 for all tasks, 3 for all tasks with generous time left.
- Random events are scripted and deterministic per level, with timing variation, so the bot playthrough stays reliable.
- Level progress persists in a local JSON file next to settings.

### Objections

None.
