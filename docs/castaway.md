# Castaway controller

The castaway is a real-time `CharacterBody2D` (`scenes/castaway/castaway.tscn`, `scripts/gameplay/castaway/`). There are no tiles, turns or action points: the body moves every physics tick (60 Hz).

## Controls

| Action | Keys (physical) | Input map action |
|---|---|---|
| Move | W A S D, arrow keys | `move_up`, `move_down`, `move_left`, `move_right` |
| Dash | left or right Shift | `dash` |
| Grab / throw / use | Space, E | `interact` |
| Pause | Esc | `pause` |
| Restart level | R | `restart` |
| Hint | H | `hint` |
| Finish (result screen) | Enter, keypad Enter, F | `finish` |

Only move, dash and interact are handled by the castaway; pause, restart, hint and finish belong to the level and menu items.

## Rules

- Input is read in the same physics frame it acts in (`CastawayInput.from_input()`); presses are never buffered.
- Movement accelerates with `move_accel`, slows down with `move_decel`, diagonals are normalised; carrying multiplies the speed by `carry_speed_factor / weight`. The facing turns towards the move direction at `turn_speed`.
- Slippery ground: where the surface is `mud` (an event surface override, `Grabbable.SURFACE_MUD`), walking uses `move_accel` times `slippery_accel_factor` (0.25) while steering and `move_decel` times `slippery_friction_factor` (0.12) while sliding out, so the castaway starts slowly and slides about eight times as far before stopping; top speed, dash and knockback are unchanged. Animals ignore mud. `Castaway.drop_carried()` drops the carried object at the feet without a bonk (event `take_held`).
- Carry weight: a carried object with `get_carry_weight()` (animals and items, see `docs/entities.md`) counts with its weight clamped to `carry_weight_min..carry_weight_max`, anything else with 1.0. Heavier loads walk slower and fly shorter (`throw_range / weight`, also the aim range); weight 1.0 keeps the plain numbers.
- Dash: `dash_distance` in `dash_duration`, in the move direction or, without input, in the facing direction. The cooldown `dash_cooldown` counts from the dash start. A dash stops at the first solid object, the shoreline or a level bound and never enters them.
- Interact priority: carrying – use on the nearest accepting use target within `use_radius`, otherwise throw; empty hands – grab, otherwise nothing. The verb the next press will perform is exposed as `Castaway.get_interact_verb()` and announced by `EventBus.interact_verb_changed(verb, target_kind)` whenever it changes (HUD prompt).
- Grab: nearest grabbable within `grab_radius` inside the grab cone, else the nearest one within `grab_touch_radius` in any direction. `grab_cone_degrees` is a half-angle: 75 means 150 degrees in total. Ties go to the smaller distance, then the smaller instance id.
- One carry slot: a second grab is impossible because interact throws or uses while carrying. There is no inventory and no recipe data.
- Throw: towards `throw_range` in the facing direction; an accepting target within `throw_aim_tolerance_degrees` of the facing and within range is aimed at directly. The flight (`ThrowFlight`) takes `throw_flight_time`, rises to `throw_arc_height` with a shrinking ground shadow, flies over water, stops `throw_wall_pad` in front of solid objects and bounds and lands with squash and stretch. Presses during the short throw pose (`throw_pose_seconds`) are dropped.
- Hit: `Castaway.bonk(cause, from_direction)` knocks the castaway `knockback_distance` towards `from_direction`, drops the carried thing at its feet and makes it dizzy for `dizzy_seconds` (stars, `bonked` signal as BONK popup hook). All input is ignored while dizzy; afterwards the castaway is immune for `dizzy_immunity_seconds`. There is no health value.
- Restart: `Castaway.reset_to(spawn_position, facing)` clears carry, dash, cooldown, dizzy, immunity, velocity, pose and tweens.
- All timers use the physics delta, so a paused tree freezes dash, cooldown, dizzy and throw flights.

Every tuning number lives in `data/balance/castaway.json` (namespace `castaway`).

## Contracts

Duck-typed, because animals and items use different base classes:

- Grabbable (`Grabbable`, group `grabbable`): `kind: String`, `can_grab() -> bool`, `on_grabbed(carrier)`, `on_released()`, optional `get_throw_visual() -> Node2D`. While carried the object keeps its parent; the castaway moves it to its hold point every tick, so `on_grabbed` should disable the object's own collision and behaviour. `on_released` is called after a drop, after a throw landing and before a use.
- Use target (`UseTarget`, group `use_target`; aim-snap-only targets in group `throw_target`): `target_kind: String`, `accepts(obj) -> bool`, `use(obj)`.
- Surface provider (group `surface_provider`): `get_surface_at(global_pos) -> String` returning `sand`, `grass`, `stone` or `water` (`LevelBase` in levels, see `docs/levels.md`); without a provider the surface is `sand`.

## EventBus signals

The castaway joins group `castaway` (used by the entity registry). Animal and item signals are listed in `docs/entities.md`.

`castaway_dashed(position, direction)`, `castaway_step(position, surface)` every `step_interval` while running, `object_grabbed(kind)`, `object_used(kind, target_kind)`, `object_thrown(kind)`, `object_landed(kind, position, surface)`, `object_bonked("castaway", cause)`, `castaway_dizzy_started(cause)`, `castaway_dizzy_ended()`, `interact_verb_changed(verb, target_kind)`. Right before `object_grabbed` it emits `fx_anchor_node(kind, thing)`, before `object_used` `fx_anchor_node(target_kind, target)` and before `object_thrown` and `object_bonked` `fx_anchor_node("castaway", self)` (feedback position, `docs/feedback.md`). `fx_squash` and `fx_recoil` on the castaway add a feedback squash and recoil on top of its own dash stretch and throw punch.

## Physics layers

`PhysicsLayers` (`scripts/core/physics_layers.gd`) mirrors `[layer_names]` in `project.godot`: 1 world_solid, 2 water, 3 bounds, 4 castaway, 5 animals, 6 items, 7 zones. The castaway collides with world_solid, water and bounds; throws stop at world_solid and bounds only. As a safety net the castaway returns to its last safe position if it ever ends up overlapping a blocker.

## Test arena

`tests/scenes/castaway_arena.tscn` (tests only) has bounds, a rock block, a water strip, a grass patch, three stub grabbables, a stub goat that accepts a hat and the castaway. Run it windowed with `Godot_v4.7.2-stable_win64.exe --path . res://tests/scenes/castaway_arena.tscn`.
