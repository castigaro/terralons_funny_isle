# Personas and support/sales – Terralon's Funny Isle 2

Stage: discovery. Results taken over from the discovery roles, only structured.

## Personas

Inferred, not researched; traits marked "Assumption:" are not stated by the idea or constraints.

Comparable products by fit: Overcooked (time-pressure chaos, carry and throw), Moving Out, Untitled Goose Game (slapstick, animal reactions), Diner Dash and Crazy Taxi (level timers, star ratings), Stardew-style cozy games as a counter-example only (not the target).

### Persona 1 – "Lena", 34, casual PC gamer

German (Assumption: German by default). Plays 20–30 minute sessions on a Windows laptop.

- Goals: instant fun, funny reactions, clear tasks, a first run through all five levels in about 20–30 minutes.
- Pain points: the old game felt like a boring chess game; unclear objectives; unfair deaths; clipped German text.
- Wants: tasks shown on screen at all times, a visible timer, fast retry, a language switch in-game.
- Typical flaws in comparable products: tutorial walls, hidden goals, overlong result screens, German strings overflowing buttons.

### Persona 2 – "Max", 10, plays with a parent nearby

Family-friendly constraint. Assumption: keyboard-first, mouse only in menus, so he needs simple controls.

- Goals: laugh at BONK, dizzy stars and fleeing animals; earn 3 stars.
- Pain points: failing without knowing why; text-heavy menus; scary or violent content; harming animals.
- Wants: large readable sprites, announcer lines, forgiving but funny failures, unlockable levels in order.
- Typical flaws: tiny hit areas for grab and throw, camera jerking, chaos so dense the player cannot read the screen, Shift-dash overshoot.

### Persona 3 – "Tom", 28, completionist and speedrunner

Assumption: he replays levels for 3 stars and notices bugs.

- Goals: master the levels, optimise time, replay at any time.
- Pain points: random events that make a 3-star run luck-dependent; unwinnable states (a carried item is lost, the pig stuck behind a wall); no feedback on star thresholds.
- Wants: visible star thresholds, deterministic task logic, a stable framerate at 1920x1080 and 1280x720, saved progress and settings.
- Typical flaws: soft-locks after throws, physics jitter, audio spam from repeated sound effects, volume sliders that don't persist, the timer running during pause or menus.

### Cross-cutting must-haves

- Input and rules: grab, throw and use must be reliable. Every task must be completable even after the worst random event. Events must be funny, not punishing.
- Presentation and audio: clean music and effects mix with separate sliders.

Objections: none. Assumption for confirmation: the target age range is roughly 8 and up, family co-play included.

## Support+Sales

Prioritized requirements (Support+Sales). Personas are inferred; no counts used.

### MUST

1. Real-time controls that feel reliable: continuous movement, Shift-dash, Space/E grab/throw/use, forgiving grab and throw hit areas, no dash overshoot into water or walls. Source: user (controls); inferred (hit-area and overshoot tuning).
2. No soft-locks: every task stays completable after the worst random event. Carried or thrown items, and animals, must never get stuck behind walls or lost. Respawn or reset items that become unreachable. Bot playthrough covers the worst-case events. Source: user (testing constraint); inferred (soft-lock cases).
3. Always-visible HUD: task list, level timer, task progress. Timer stops during pause and menus. Source: inferred (HUD visibility, timer pause).
4. Readable chaos: large sprites (castaway at least 64 px tall at 1920x1080), clear silhouettes, effects capped so the screen stays legible. Smooth camera with no jerk. Source: user (sprites, camera); inferred (effect density cap).
5. Events are funny, not punishing: they add chaos but never decide the stars alone. Fixed per-level event schedules or seeded randomness, so 3-star runs are deterministic. Source: user (events); inferred (fairness, seeding).
6. Failure feedback: every failure shows a funny reaction and a short cue saying why. Fast one-key retry. Source: user (reactions, retry); inferred (the "why" cue).
7. Persistence: progress, settings and volume sliders saved locally and reloaded. Source: user.

### SHOULD

8. Result screen: short, with visible star thresholds (tasks done, time left) shown before and during play. Source: user (stars); inferred (visible thresholds, short screen).
9. German text never clips: layout tested in both languages at 1280x720 and 1920x1080, in-game switch. Source: user (languages); inferred (clip test).
10. Audio quality: no sound spam. Cap or throttle repeated effects. Balanced mix, separate music and effects sliders, announcer lines that do not overlap. Source: user (audio); inferred (throttling).
11. Stable framerate at 1920x1080 and 1280x720, with no physics jitter. Source: inferred.
12. Minimal onboarding: no tutorial wall. Teach through level 1 and short contextual prompts. Source: inferred.
13. Family-safe content: slapstick only, animals never harmed, nothing scary. Source: user.
14. Menus: simple, icon-first, mouse-friendly, levels unlock in order. Source: user (unlock order); inferred (icon-first menus).

### COULD

15. Replay value: best time and best stars per level shown. Source: inferred.

Assumption for confirmation: target age is roughly 8 and up, family co-play included. Objections: none.
