# Animals and items

Animals and items live in `scripts/gameplay/entities/` and `scenes/entities/`. Every animal kind uses the same scene (`animal.tscn`) and the same state machine. Every item kind uses `item.tscn`. All differences between kinds are data: there is no species subclass and no `match kind` (checked by `tests/gameplay/entities/test_entities_generic.py`). Nothing is ever harmed: there is no damage, no death and no blood state. `tools/validate_code.py` check (h) rejects such names.

| File | Class | Role |
|---|---|---|
| `entity_defs.gd` | `EntityDefs` | Loads and validates `data/animals.json` and `data/items.json` (same rules as `tools/validate_entities.py`, without the deny-list and size checks). Has a static cache with `get_animal`, `get_item`, `kinds`, `animal_kinds`, `item_kinds` and `clear_cache`, plus `LOST_CUE_KEYS`. |
| `entity_config.gd` | `EntityConfig` | Typed values of `data/balance/entities.json`. |
| `animal_brain.gd` | `AnimalBrain` | Pure state machine (no scene, no autoload). |
| `animal.gd`, `animal_visual.gd`, `dizzy_stars.gd` | `Animal`, `AnimalVisual`, `DizzyStars` | Scene shell, look and dizzy stars. |
| `item.gd` | `Item` | Item scene shell: idle bob, wearing, hop-away. |
| `respawn_guard.gd` | `RespawnGuard` | Pure respawn timer. |
| `flight_watch.gd` | `FlightWatch` | Notices the castaway's `ThrowFlight` child and samples it. |
| `respawn_puff.gd` | `RespawnPuff` | White smoke puff that frees itself. |
| `zone.gd` | `Zone` | Named level zone, containment from the shape geometry. |
| `entity_registry.gd` | `EntityRegistry` | Per-level hub: perception, queries, impacts, snapshot, event effects, restart. |
| `entity_protection.gd` | `EntityProtection` | Keeps entities that count for a finished task safe. |

## Animal states

`IDLE`, `WANDER`, `FLEE`, `PANIC`, `LURED`, `SETTLED`, `BONKED`, `CARRIED`, `FLIGHT` and `RESPAWNING`. Priority from high to low: `CARRIED`/`FLIGHT` > `RESPAWNING` > `BONKED` > `PANIC` > `FLEE` > `LURED` > `SETTLED`/`WANDER`/`IDLE`. The normal states are `IDLE`, `WANDER`, `SETTLED` and `LURED`.

- **Wander:** the animal pauses for `wander_pause_min..max`, then walks to a seeded point within `wander_radius` of home. It picks a new target after `wander_retarget_seconds` when blocked. `SETTLED` is wandering inside a zone that confines it.
- **Flee:** the castaway moving towards the animal within `flee_radius` starts a flee. A dash towards it within `dash_scare_radius` and `dash_scare_degrees` scares it, and a dash through it (within `dash_bump_radius`) also pushes it by `dash_bump_distance`. The flee ends when the castaway is farther than `flee_radius × flee_exit_factor` and `flee_min_seconds` have passed. Herdable animals flee straight away from the castaway, so they can be pushed into zones. Animals with `herdable = false` (monkey, parrot) flee sideways at a seeded angle (D7).
- **Lure:** while the castaway carries the animal's `lure_item` within `lure_radius`, the animal follows at `follow_distance`, and walking towards it does not scare it (a dash still does, D6). A lure item lying on the ground draws the animal to `lure_arrive_distance`.
- **Panic:** `panic(seconds)` makes the animal run in a seeded direction that changes every `panic_turn_interval`. The time is clamped to `reaction_max_seconds`; a repeated call only extends a running panic.
- **Bonk:** the animal is pushed `knockback_distance` in `knockback_seconds` (stopped by walls) and is dizzy with stars for `bonk_seconds`. Then it flees for `min(panic_duration, reaction_max_seconds − bonk_seconds)` and returns to normal (D8). Bonks are ignored while bonked; a panic during a bonk starts after it.
- **Carried and flight:** a grab disables the body's collision. A throw is noticed through the `ThrowFlight` child (D1). After the landing the animal wanders on at once.
- **Respawning:** an unreachable animal stands still with a bob until it respawns or is grabbed.

Each reaction emits once per state entry. Every timer uses the physics delta, so a paused tree freezes everything. Steering adds wall slide with a corner escape (a turn of at most `corner_escape_degrees`, away from the castaway), separation within `separation_radius`, and acceleration `accel`. Speed is never above `speed × flee_speed_factor`, except during a knockback burst.

## Data

`data/animals.json`: `{"format_version": 1, "animals": {<kind>: {sprite, sprite_scale, speed, wander_radius, flee_radius, flee_speed_factor, panic_duration, lure_item, lure_radius, follow_distance, herdable, swims, carry_weight, pitch, name_key}}}`. Kinds: chicken, duck, goat, pig, monkey, parrot, penguin (round animal sprites with outline). Ducks and penguins swim. The lure items are coconut (monkey), hat (goat) and bucket (pig, penguin).

`data/items.json`: `{"format_version": 1, "items": {<kind>: {sprite, sprite_scale, carry_weight, wearable, swims, name_key}}}`. Kinds: coconut, hat (wearable), bucket, sand_pail (item-pack sprites, see `docs/asset_map.md`). Items never swim.

`name_key` points to `i18n/entities.csv` (`entities.name_<kind>`). The cue keys for respawns are `entities.lost_water`, `entities.lost_bounds` and `entities.lost_stuck` (`EntityDefs.LOST_CUE_KEYS`, A9).

`tools/validate_entities.py [--root DIR] [--animals FILE] [--items FILE] [--balance-dir DIR]` checks:

- exact keys, types and ranges, and the kind id format;
- that animal and item kinds are disjoint and every lure item exists;
- sprites: the file exists, is imported, its name is not on the deny list, and its smaller side is at least 24 px at 720p;
- that `name_key` has EN and DE text;
- that `carry_weight` lies within the castaway `carry_weight_min..carry_weight_max`;
- that `bonk_seconds + panic_duration ≤ reaction_max_seconds`.

Its fixtures are in `tests/fixtures/entities/`. Every file holds `{"animals": …, "items": …}`; `valid_*` files must pass and `invalid_*` files must fail.

## Balance: `data/balance/entities.json`

| Keys | Meaning |
|---|---|
| `respawn_delay` (2.0) | Continuous unreachable time before a respawn. |
| `reaction_max_seconds` (3.0), `bonk_seconds` (1.0) | Upper limit of every reaction; dizzy time after a bonk. |
| `bonk_radius`, `knockback_distance`, `knockback_seconds` | Impact radius of a thrown object and the push. |
| `item_knockback_distance`, `item_hop_height`, `item_hop_seconds` | Hop of an item next to a landing. |
| `skim_height`, `skim_min_progress` | A flight that is this low near its end already hits animals on the ground. |
| `dash_scare_radius`, `dash_scare_degrees`, `dash_bump_radius`, `dash_bump_distance` | Dash scare and bump. |
| `flee_exit_factor`, `flee_min_seconds` | Flee hysteresis. |
| `separation_radius`, `separation_strength`, `accel`, `corner_escape_degrees` | Steering. |
| `body_radius_factor` | Collision radius = smaller sprite side × `sprite_scale` × factor. |
| `wander_pause_min`, `wander_pause_max`, `wander_arrive_distance`, `wander_retarget_seconds` | Wandering. |
| `panic_turn_interval`, `lure_arrive_distance`, `settle_margin` | Panic turns, lure stop, how far inside a pen an animal must be to settle. |
| `waddle_*`, `hop_*`, `idle_hop_interval`, `panic_hop_interval`, `wiggle_*`, `star_*`, `speed_line_amount`, `emote_*`, `shadow_scale`, `item_bob_*`, `puff_*` | Look. |

The castaway balance has two more keys: `carry_weight_min` (0.5) and `carry_weight_max` (2.0).

## Contracts

- **Grabbable extras:** `get_carry_weight()`, `is_free()`, `held_by()` (`"player"` or `""`), `worn_by`, `relocate_to(pos)`, `reset_to_home()`, `get_state_name()`, `is_animal()` and `is_swimmer()`. Animals also have `bonk(from_dir, cause) -> bool` and `panic(seconds)`. Items also have `wear_on(wearer, wearer_kind)`, `take_off()` and `nudge(dir)`. A worn item follows its wearer and is not free.
- **Home point:** the optional export `home_marker` (a Node2D), otherwise the start position. `uid` is an optional export; the registry fills in `<kind>_<n>` in tree order.
- **Zone** (`Area2D`, layer zones, group `level_zone`): exports `zone_id` and `contains`. It has `contains_point(p)`, `contains_with_margin(p, margin)`, `clamp_inside(p, margin)`, `random_point(rng, margin)` and the static `area_contains(area, p)` (rectangle and circle shapes, global transform). `contains = true` marks a pen: an animal whose centre is `settle_margin` inside it stays inside on its own; only carrying takes it out (D5).
- **Level bounds:** a node in group `level_bounds` with `get_bounds_rect() -> Rect2`, plus static bodies on the bounds layer.
- **Closed pockets:** an `Area2D` in group `respawn_area` marks spots nobody can reach.
- **Castaway:** the registry uses `set_castaway(node)`, otherwise the first node in group `castaway`.

## Respawn (A5)

`EntityRegistry.unreachable_reason(entity)` returns one of these reasons, checked in this order:

- `bounds`: outside a `level_bounds` rectangle or on a bounds body;
- `stuck`: on a world-solid body or inside a `respawn_area`;
- `water`: water surface or water body, for non-swimmers only;
- `""` when the entity can be reached.

An entity that is free (not carried, flying or worn) and unreachable for `respawn_delay` seconds without a break respawns. In one tick it emits `entity_lost(kind, reason)`, shows a smoke puff where it was and at home, returns home with every state cleared, and emits `entity_respawned(kind, home)` (D4). Grabbing it before the delay cancels the respawn without a signal. Non-swimmers have water in their collision mask, so they only get into water by a throw or a relocation.

**Protection:** `EntityProtection.new(session, def)` decides which entities count towards a finished task. An entity is protected when a done task has an `in_zone` condition with the entity's kind and a zone the entity is in, or a `worn` condition with this worn item. Hand it to the registry with `set_protection(protection.is_protected, protection.confine_zone)`. A protected entity is never respawned or relocated, and the animal stays inside its zone.

## Registry API

- **Setup:** `set_castaway`, `set_protection`, `refresh`, `track`.
- **Lists:** `entities`, `animals`, `items`.
- **Queries:** `perception_for`, `confine_for`, `zones_of`, `unreachable_reason`, `is_protected`.
- **Impacts:** `impact(source, ground_pos, cause, hits)` bonks free animals within `bonk_radius` (away from the impact) and lets free items hop. The thrown entity calls it once per flight and per target for a low skim, and on landing.
- **Snapshot:** `snapshot_entities() -> [{uid, kind, zones, held_by, worn_by}]` (the rules snapshot, `docs/rules.md`).
- **Event effects:** `panic_kind(kind, seconds)`, `panic_all(seconds)` and `relocate(kind_or_uid, pos)` (skips carried, flying, worn and protected entities). `reset_all()` is the level restart (A8).

## Signals

`animal_fled(kind)`, `animal_bonked(kind, cause)` (the cause is the thrown kind), `animal_panicked(kind)`, `animal_caught(kind)`, `animal_lured(kind)`, `entity_lost(kind, reason)` and `entity_respawned(kind, position)`. Animals do not use `object_bonked`, which stays the castaway's BONK hook (D9).

## Test arena

`tests/scenes/entity_arena.tscn` (tests only) has:

- level bounds, a rock and a water strip with a surface provider;
- a closed pocket behind a wall;
- a cage pen and a pond pen on the water;
- one entity per kind at its home, the castaway and the registry.

Run it windowed with `Godot_v4.7.2-stable_win64.exe --path . res://tests/scenes/entity_arena.tscn -- --arena-demo`. In the demo, coconuts fly onto animals and every animal panics now and then. `tests/support/entity_scene_case.gd` builds it with chosen kinds and scripted input.

## Assumptions

- D1: `ThrowFlight` stays unchanged. Entities notice the flight through `child_entered_tree` and read `t`, `from`, `landing` and `height_at`.
- D2: zone containment comes from the shape geometry, so it is valid without a physics frame.
- D3: non-swimmers never walk into water. An unreachable entity stands still and stays grabbable.
- D4: `entity_lost` fires only when the respawn is committed.
- D5: animals in pens or counted for a done task stay inside; only carrying moves them out.
- D6: a carried lure switches off the approach flee.
- D7: non-herdable animals flee sideways and are moved by luring or carrying.
- D8: the bonk reaction is dizzy, then flee, then normal, at most `reaction_max_seconds`.
- D9: animals use `animal_bonked`, never `object_bonked`.
- D10: i18n keys use the `entities.` prefix (the CSV stem).
- D11: the class `EntityRegistry` has no `register()` method; entities join group `level_entity`.
- D12: the castaway joins group `castaway`.
- Carry weight: heavier loads slow the castaway (`carry_speed_factor / weight`) and fly shorter (`throw_range / weight`). Weight 1.0 keeps the BI-2 numbers.
- The coconut, hat, bucket and sand pail sprites are the closest item-pack shapes (the pack has no real coconut or hat).
- The emotes come straight from the emote pack. A later feedback item may route them through its own data.
