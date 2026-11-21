# Slapstick feedback (BI-8)

Every action and every mishap explodes into funny feedback: squash and stretch, translated sound-word popups (BONK!, SPLAT!, WHOOSH!), smoke puffs, splats, particles, emotes, flashes, screen shake, hit-stop and a visual recoil. The feedback is data-driven and capped, so the chaos stays readable.

## Files

| File | Class | Purpose |
|---|---|---|
| `scripts/feedback/feedback_director.gd` | `FeedbackDirector` | Node: listens to every EventBus signal, resolves anchors, plays pooled effects, owns shake and hit-stop. The only writer of `Engine.time_scale`. |
| `scripts/feedback/feedback_map.gd` | `FeedbackMap` | Pure model of `data/feedback.json`: entries per signal (with variants), per event warning and start, structural checks. |
| `scripts/feedback/fx_strengths.gd` | `FxStrengths` | Effective values from `data/balance/feedback.json`, `fx_scale` and the reduce toggle. |
| `scripts/feedback/fx_settings.gd` | `FxSettings` | Reads `reduce_shake_flashes` from `settings.json` in the DataDir folder (missing, corrupt or not a bool: off). |
| `scripts/feedback/fx_pool.gd` | `FxPool` | Fixed-size pool per effect type, preallocated to its cap, recycles the oldest. |
| `scripts/feedback/hit_stop.gd` | `HitStop` | Pure hit-stop state machine with an injected clock. |
| `scripts/feedback/shake.gd` | `FxShake` | Pure trauma model of the screen shake with seeded noise. |
| `data/feedback.json` | – | Which effects every signal and event plays. |
| `data/balance/feedback.json` | – | Strengths, timings, caps and limits (namespace `feedback`). |
| `i18n/fx.csv` | – | Sound words (`fx.*`), upper case, at most 8 characters plus "!" in EN and DE. |

## Placement (D1)

The director is level-scoped, not an autoload. Every level scene adds one `FeedbackDirector` node (BI-10). Test arenas add one too: `tests/scenes/fx_arena.tscn`, and `tests/support/entity_scene_case.gd` puts one into the entity arena with `hitstop_scale` 0. Scene tests without a director keep exact frame timing. Freeing the director (level unload) restores `Engine.time_scale` and the camera offset.

The director builds four layers as children: `GroundLayer` (splats, `z.splat`, below actors), `FxLayer` (puffs, particles, emotes, flashes, `z.fx`), `PopupLayer` (`z.popup`) and the CanvasLayer `ScreenLayer` (`screen_layer`) for screen-anchored effects. The HUD (BI-6) should use a higher CanvasLayer. None of the layers y-sorts. The director runs with `PROCESS_MODE_ALWAYS` and does not animate effects while the tree is paused.

## Data: `data/feedback.json`

```
{format_version: 1,
 materials: {mud, water, sand: "#rrggbb"},
 no_visual: {<signal>: "<reason>"},
 signals: {<signal>: {variant_arg?: <argument name>, default: [entries], variants?: {<value>: [entries]}}},
 events: {<event type>: {warning: [entries], start: [entries]}}}
```

An entry is `{effect, anchor?, strength, asset?, frames?, frame_count?, word?, material?, offset?}`:

- `effect`: `popup`, `splat`, `puff`, `particles`, `emote`, `shake`, `flash`, `hitstop`, `squash` or `recoil`;
- `anchor`: `auto` (default), `screen`, `follow` (emote follows the anchor node) or `event_zone`;
- `strength`: a key under `strengths.<effect>` in the balance file;
- `asset` (particles, emote) or `frames` + `frame_count` (puff, splat, flash; a `%02d` pattern);
- `word`: an `fx.*` i18n key (popup); `material`: `mud`, `water` or `sand` (splats need one, particles may use one as tint).

`variant_arg` picks the variant by an argument value, for example `object_landed` by `surface` (water: splat, droplets and SPLASH!; sand: splat, puff and PLOP!; mud: splat and SPLAT!; others: puff and BOING!). Every custom EventBus signal is either in `signals` or in `no_visual` with a reason. `event_warning` and `event_triggered` also play the `events.<type>.warning` and `events.<type>.start` entries; `event_triggered` uses the type that the preceding `event_warning` with the same id announced. BI-9 (audio) can reuse the `no_visual` list for its own coverage test.

## Anchors

Gameplay emits `fx_anchor(kind, position)` or `fx_anchor_node(kind, node)` right before a signal that has no position argument. The director stores it and the next signal with visuals consumes it; signals in `no_visual` leave it alone, and a stale anchor is dropped at the end of the frame.

`auto` resolves to: the first `Vector2` argument of the signal, the pending anchor, the castaway (group `castaway`), the screen centre. `follow` uses the anchor node, else the castaway. `event_zone` uses a node in group `event_anchor` whose `event_id` matches the event (level scenes may place such markers), else the castaway's head. `screen` puts the effect on the ScreenLayer at the screen centre. World popups appear at `popup_face_offset` above the anchor, emotes at `emote_height`.

Emitters: animals before each reaction and before `animal_caught` (`fx_anchor_node(kind, self)`), animals and items before `entity_lost` (`fx_anchor(kind, lost_at)`), the castaway before `object_grabbed` (the grabbed thing), `object_used` (the target), `object_thrown` and `object_bonked` (itself).

Duck-typed body contract: an anchor node may implement `fx_squash(sx, sy, seconds)` and `fx_recoil(offset, seconds)`. Animals, items and the castaway compose them into their own sprite animation, so they never fight the waddle, bob, dash stretch or throw punch. Without these methods squash and recoil entries are skipped. Body-attached motion (dash stretch, throw landing squash, dizzy stars, speed lines, dust) stays in the gameplay visuals and is not doubled.

## Balance: `data/balance/feedback.json`

- `fx_scale` (0–1) scales the intensity fields (`amplitude`, `ms`, `px`, `amount`, `alpha`) and the deviation of size fields (`scale`, `x`, `y`) from 1; durations and speeds stay. 0 switches off shake, hit-stop, recoil, squash and particles, while popups and emotes still read.
- `reduce_motion_factor` (at most 0.25) multiplies shake amplitude and flash alpha while the player's "reduce screen shake and flashes" toggle is on.
- `hitstop_max_ms` (at most 80), `hitstop_scale` (0–1, tests use 0), `hitstop_time_scale`, `hitstop_cooldown_ms` (at least the longest hit-stop), `hitstop_safety_grace_ms`.
- `flash_min_interval_ms` (at least 334, so at most 3 flashes per second, WCAG 2.3.1); flash alpha at most 0.4, additive white or yellow frames only.
- Timings and looks: `shake_*`, `popup_*`, `emote_*`, `puff_*`, `splat_*`, `flash_*`, `particle_lifetime_margin`, `z`, `screen_layer`.
- `caps` per type: `popup`, `splat`, `puff`, `particles`, `emote`, `shake` (sources), `flash`, `squash`, `recoil`. Visual pools recycle the oldest effect when full; squash, recoil and flash requests are dropped when full; a new shake source replaces the weakest one if it is stronger.
- `strengths.<effect>.<key>`: shake `{amplitude, trauma}`, hitstop `{ms}`, squash `{x, y, seconds}`, particles `{amount, lifetime, speed, spread, scale}`, flash `{alpha}`, popup/puff/splat/emote `{scale}`, recoil `{px, seconds}`.

Gameplay knockback stays in `castaway.json` and `entities.json` and is never scaled by the feedback; `recoil` is a purely visual sprite offset.

## Hit-stop

`request_hitstop(ms)` asks the `HitStop` state machine with the director's clock (`Time.get_ticks_msec`; tests inject a frame clock). Requests while the tree is paused, during the cooldown or with 0 ms are dropped. The first accepted request sets `Engine.time_scale = hitstop_time_scale`. Overlapping requests move the end to the later one (max, not sum), and one freeze never lasts longer than `hitstop_max_ms` from its start. Every time the end moves, a new unscaled `SceneTreeTimer` is armed for that generation, and only the latest generation restores. `_restore_time_scale()` is the single restore path. It is called from the timer, `_exit_tree`, `reset_all` (on `level_started`), the pause check (the tree is paused during a freeze) and the safety check (end plus grace has passed, for example after a lost timer). `tools/validate_code.py` rule (i) allows `Engine.time_scale` assignments only in the director.

## Reduce toggle contract (BI-7)

The settings menu writes `"reduce_shake_flashes": true|false` to `settings.json` in the DataDir folder and emits `EventBus.settings_changed("reduce_shake_flashes")`; `settings_changed("")` re-reads everything. The director reads the value in `_ready` and on these signals. With the toggle on, shake amplitude and flash alpha drop to `reduce_motion_factor` (0 by default). Hit-stop is a short freeze, not a flash, and is not reduced; the toggle text should say "screen shake and flashes" only.

## Signals

- `event_warning(event_id, event_type, seconds_until)` – LevelSession, `event_warning_lead_seconds` before the event start (clamped at 0).
- `fx_anchor(kind, position)` and `fx_anchor_node(kind, node)` – position carriers for the next signal (listed in `no_visual`).

## Tests and windowed check

`tests/feedback/` covers coverage, mapping, events, scaling and the reduce toggle, the pure hit-stop and the hit-stop in the scene tree, the 50-events-in-one-frame stress test against the caps, i18n popups, family-friendly materials and flash limits, the feedback arena and the validator (`test_validate_feedback.py`, cases in `tests/fixtures/feedback/cases.json`).

Run the arena windowed with `Godot_v4.7.2-stable_win64.exe --path . res://tests/scenes/fx_arena.tscn -- --quit-when-done [--fx-shot=<png path>]`. It fires every mapped signal and ends with a burst of 20 bonks, then prints `FX ARENA OK`.

## Assumptions

- D1: the director is level-scoped (see above).
- D2: `fx_anchor_node` exists beside `fx_anchor`, so emotes can follow fleeing animals.
- D3: the event warning lead comes from `rules.json`, and LevelSession emits it as a third timeline point type.
- D4: `event_zone` uses optional `event_anchor` markers and falls back to the castaway's head.
- D5: flashes are rate limited to at most 3 per second with alpha at most 0.4; hit-stop is not reduced by the toggle.
- D6: the clock for cooldown, flash limit and safety check is injectable.
- D7: popups are world-space and not yet kept away from the HUD cue band; BI-6 should reserve the top-centre band and BI-14 checks it in screenshots.
- D8: the castaway anchors `object_grabbed` on the grabbed thing (the thing squashes and YOINK! appears above it) and `object_used` on the use target.
- D9: `fx_scale` moves popup, emote, puff and splat sizes towards their normal size instead of hiding them, so the feedback stays readable at any scale.
