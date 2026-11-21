# Level scenes

Every level is a scene that inherits `scenes/levels/level_base.tscn` (`LevelBase`, `scripts/levels/level_base.gd`). The base loads the level JSON (BI-3, `docs/rules.md`) into a `LevelSession`, owns the handcrafted tile layout, the bounds, the spawn, home points, zones, the `EntityRegistry` (BI-4) and the camera, feeds the session a world snapshot every physics tick and runs the instant restart. The whole level is always visible: no fog of war, darkness or reveal logic exists (`tools/validate_code.py` rule (i); placeholder graphics are rule (j)).

`python tools/play.py` opens the title stub; any key starts the first shipped level and `python tools/play.py -- --level=<id>` boots a level directly (BI-7 replaces the stub with the real menus). Art rules are in `docs/art_treatment.md`.

## Shipped levels (BI-10)

| Id | Theme, music | Tasks | Events |
|---|---|---|---|
| `l1_beach_camp` | `beach_camp`, `level_1`; sand island with palms, 240 s | required: two chickens in the cage, two coconuts to the monkey; optional: hat on the goat | `coconut_volley` (coconut_throw: the monkey at `monkey_perch` lobs coconuts, stun and drop), `parrot_raid` (parrot_steal_hat: takes an unprotected worn hat to `parrot_flee`) |
| `l2_farm_meadow` | `farm_meadow`, `level_2`; grass meadow with a pond and trees, 210 s | required: three ducks into the pond, catch the runaway pig; optional: feed bucket to the trough before the rain | `pig_mud` (mud_trail: slippery `mud_lane`), `rain_shower` (rain_panic: chickens panic and scatter) |

- Catalogue convention (`LevelCatalogue`, `scripts/levels/level_catalogue.gd`): every `data/levels/<id>.json` has the scene `scenes/levels/<id>.tscn`; the campaign order is the sorted file name (`l1_…`, `l2_…`). There is no index file. Each level JSON names its default allocation in the free-text field `notes`.
- Level 1 teaches the controls in place: move, grab, throw and use prompts at the castaway, the first chicken, the first coconut and the cage; there is no tutorial screen or level. Level 2 has no basic prompts.
- Workload: L1 5 units in 240 s (48 s per unit), L2 5 units in 210 s (42 s per unit). The headless bot (`tests/levels/test_complete_*.gd`) needs about 15 s of play for L1 and about 30 s for L2 without waiting; the tests hold the last task until every event has ended.
- Layout texts live in `scenes/levels/layouts/<id>.layout.txt` (painted with `tools/build_level_layout.gd`).

## Node layout

| Node | Type | Role |
|---|---|---|
| `WaterBackdrop` | `Sprite2D` | animated water under everything, sized at runtime to the bounds plus one viewport per side |
| `Sand`, `Grass`, `Shore`, `Details` | `TileMapLayer` | the layout, all with `scenes/levels/island_tileset.tres` |
| `Actors` | `Node2D`, y-sorted | castaway (`Actors/Castaway`, `castaway_path`), animals, items, props |
| `Markers/Spawn` | `Marker2D` | castaway start; its rotation is the start facing |
| `HomePoints/<uid>` | `Marker2D` | home of the level entity with that uid (reset after restart or when unreachable) |
| `Zones/<zone_id>` | `Area2D` with `Zone` (`scripts/gameplay/entities/zone.gd`) | task zones and pens (see Zone contract) |
| `Bounds` | `StaticBody2D` | four rectangles built at runtime around the bounds (layer `bounds`) |
| `EntityRegistry` | `Node` with `EntityRegistry` | owns the animals and items: perception, snapshot entities, protection, respawn, restart reset |
| `LevelCamera` | `Camera2D` with `LevelCamera` | the camera, a child of the level and never of the castaway |
| `Overlay/LevelCue`, `Overlay/LevelErrorPanel` | `CanvasLayer` | restart cue and load error panel |
| `FeedbackDirector` | `Node` with `FeedbackDirector` | shipped levels: slapstick feedback (index 5, before `Actors`) |
| `EventAnchors/<event_id>` | `Marker2D` with `EventAnchor` | shipped levels: where an event happens (feedback `event_zone`, actor start) |
| `EventEffects` | `Node2D` with `EventEffects` | shipped levels: applies the event effects to the world (see below) |

`FeedbackDirector`, `EventAnchors` and `EventEffects` are not in `REQUIRED_CHILDREN` (sample levels stay minimal); `tests/levels/test_shipped_levels.gd` requires them in every shipped level.

## Groups

- `actor` – castaway, animals and items (all need a `Shadow` child). `Animal` and `Item` join it in `_ready`.
- `prop` – palms, bushes, boulders (`PalmProp`, `SwayProp`, `boulder.tscn`; all need a `Shadow` child).
- `animal`, `item` – kind of a level entity (sprite size checks); joined by `Animal` and `Item` in `_ready`.
- `level_entity` – the BI-4 `Animal` and `Item` scenes (`scenes/entities/animal.tscn`, `item.tscn`); the `EntityRegistry` reads them (`docs/entities.md`).
- `level_zone` – the BI-4 `Zone` nodes.
- `level_bounds` – `LevelBase` itself once its bounds are known (`get_bounds_rect()`); the registry treats entities outside as unreachable (A5).
- `respawn_area` – optional `Area2D` pockets (see below).
- `surface_provider` – `LevelBase` itself (`get_surface_at`), used by `Grabbable.surface_at` for steps, landing sounds and water respawn.

## Zone contract

- Every child of `Zones` is a BI-4 `Zone` (group `level_zone`, layer `zones`, exports `zone_id` and `contains`).
- The node name equals `zone_id`. An empty `zone_id` is filled from the node name in `LevelBase._ready`; a different `zone_id` is a load error.
- Shapes: only `RectangleShape2D` or `CircleShape2D` in `CollisionShape2D` children (the shapes `Zone.area_contains` supports); a `CollisionPolygon2D` or other shape is a load error.
- `contains = true` marks a pen: an animal released inside stays inside on its own (BI-4 D5).
- `zones_at(pos)` is geometric (`Zone.contains_point`, sorted ids), the same rule as `EntityRegistry.zones_of`, so it is valid in the same frame without a physics query.

## Entities, home points and pockets

- Place `scenes/entities/animal.tscn` and `item.tscn` instances under `Actors`, set `kind`, an explicit `uid` (`^[a-z][a-z0-9_]*$`, unique per level) and `home_marker = ../../HomePoints/<uid>`. The entities read `home_marker` in their own `_ready`, which runs before `LevelBase._ready`, so the level cannot inject it.
- The contract test checks: uid set and unique, `home_marker` resolves to `HomePoints/<uid>`, and that marker is inside the bounds on a walkable cell reachable from the spawn.
- `LevelBase._ready` wires the `EntityRegistry` child after the session exists: `set_castaway(castaway)`, `refresh()`, then `EntityProtection.new(session, def)` and `set_protection(protection.is_protected, protection.confine_zone)`. The protection keeps the same session object across restarts. `entity_registry()` returns it.
- Closed pockets: an `Area2D` in group `respawn_area` (rectangle or circle shapes) marks spots nobody can reach; an entity inside respawns home. `walkable_cells()` skips cells whose centre lies in such an area, so the reachability contract ignores them.

## LevelBase API

Exports: `level_json_path`, `i18n_dirs` (catalogue folders for the level keys, default `["res://i18n"]`), `session_options` (default `{"schedule_mode": "seeded"}`), `autostart` (default true; the level flow sets false and calls `start_level()` after the intro), `handle_restart_key` (default true; a pause menu owner may switch it off), `bounds_override` (zero size = rectangle of all land cells), `castaway_path`, `push_errors`.

Signals: `level_ready(level_id)`, `level_load_failed(path, errors)`, `restarted(level_id)`, `exit_requested()`. `EventBus.level_restarted(level_id)` fires with `restarted`.

| Method | Returns |
|---|---|
| `start_level()`, `restart_level()` | start (from READY) or restart the attempt |
| `level_session()`, `level_def()`, `castaway()`, `camera()`, `entity_registry()` | the owned objects |
| `is_failed()`, `load_errors()` | load state |
| `get_bounds_rect()`, `backdrop_rect()` | world rectangles |
| `spawn_position()`, `spawn_facing()`, `home_point(uid)`, `has_home_point(uid)` | markers |
| `zone(id)`, `zone_ids()`, `zones_at(pos)`, `zone_problems()` | zones; `zones_at` is geometric (see Zone contract) |
| `get_surface_at(pos)` | `stone`, `grass` or `sand` from Details > Shore > Grass > Sand, `water` without land |
| `cell_of(pos)`, `cell_center(cell)`, `is_land_cell(cell)`, `is_walkable_cell(cell)`, `walkable_cells()`, `reachable_from(cell)` | tile cells; walkable means land plus a free circle of `walkable_probe_radius` at the cell centre (shore strips, rocks, prop footprints and bounds count) outside every `respawn_area`; needs one physics frame after `_ready` |
| `build_snapshot()` | the world snapshot of `docs/rules.md` |
| `LevelBase.required_zone_ids(def)` | zone ids referenced by the tasks (static) |

### Load sequence

1. Required child nodes and the castaway are checked.
2. Bounds = `bounds_override` or the rectangle of all `Sand` and `Shore` cells; the `Bounds` body and the water backdrop are sized from it.
3. The level JSON is validated by `LevelDef` with the messages of every `i18n_dirs` folder; every zone used by a task must exist under `Zones` and every zone must meet the Zone contract.
4. Any problem ends in the failed state: errors are pushed (unless `push_errors` is false), `level_load_failed` fires, the castaway is disabled and the opaque error panel shows the translated message, the path and a Back button (`exit_requested`, or the main scene when nothing is connected). The water stays visible; nothing ticks and nothing crashes.
5. Otherwise the session is created, the `EntityRegistry` wired, the camera set up, the castaway reset to the spawn and, with `autostart`, the session started.

`_physics_process` (priority 1, after the castaway at 0, before the camera at 2) ticks the session with `build_snapshot()` while it is `RUNNING` or `REQUIRED_DONE`.

### Snapshot

`player.zones` = `zones_at(castaway)`, `player.held` = kind of the carried thing, `player.worn` = `castaway.get_worn_kind()` when it exists, `player.stunned` = `castaway.is_dizzy()`. `entities` = `EntityRegistry.snapshot_entities()` (tree order, `uid`, `kind`, `zones` from the Zone shapes, `held_by` from the entity's `held_by()` method, `worn_by`); LevelBase has no entity builder of its own. An empty list is valid.

### Restart sequence (all in one call, so the snap happens in one frame)

1. `session.restart()` and `session.start()`.
2. `castaway.reset_to(spawn_position(), spawn_facing())`.
3. `EntityRegistry.reset_all()`: every entity back to its `home_marker` with all states cleared.
4. `camera.snap()`.
5. The cue `level.restarted` shows for `restart_cue_seconds`; `restarted` and `EventBus.level_restarted` fire.

Every teleport must call `reset_physics_interpolation()` on the moved node, otherwise the engine draws an interpolated sweep: `Castaway.reset_to`, the castaway safety net, `LevelCamera.snap` and every `reset_to_home`.

## Event effects (`EventEffects`, `scripts/levels/event_effects.gd`)

`event_triggered` starts the presentation of the event type (parrot fly-over, monkey coconut volley, muddy piglet with mud splats, rain overlay with a gradient tint and particle drops; fewer drops with the reduce toggle) and, `actor_impact_seconds` later, the effects of `data/events.json`: `take_worn` (unprotected worn items to a free cell near `flee_zone`), `take_held` (`Castaway.drop_carried()`), `stun_player` (`Castaway.bonk("event", ...)`), `panic_animals` (free, unprotected animals of `kind`), `relocate_entities` (entities of `kind`, else in `zone`/`lane`, else free animals, to seeded free cells within `scatter_radius_px` of their home, outside every pen) and `slippery_ground` (surface override `mud` on `zone`). `event_ended`, the restart and leaving the tree stop the event: actors, overlays, pending effects and the override are removed. Effects never touch the session. Actors (`EventActor`) are visual only and never level entities. The seed is `level seed + event index`, so a replay moves the same entities to the same cells. Test API: `active_event_ids()`, `actor_nodes()`, `overlay_nodes()`, `pending_effects()`, `last_relocations()`, `free_cells()`.

Balance (`data/balance/events.json`, namespace `events`): `actor_impact_seconds`, `actor_fly_seconds`, `actor_height_px`, `actor_scale`, `piglet_scale`, `panic_seconds`, `scatter_radius_px`, `flee_drop_radius_px`, `mud_splat_spacing_px`, `mud_splat_scale`, `mud_splat_alpha`, `rain_particle_amount`, `rain_reduced_amount`, `rain_tint_alpha`, `rain_layer`, `rain_drop_speed`, `rain_drop_scale`, `coconut_arc_height`, `coconut_throw_gap_seconds`, `coconut_scale`, `coconut_spread_px`.

Surface overrides: `set_surface_override(key, zone, surface)`, `clear_surface_override(key)`, `clear_surface_overrides()` and `surface_override_keys()`; `get_surface_at` checks the overrides first. `restart_level()` clears them. `report_delivery(entity, target)` forwards a use-target delivery to the session.

## Use targets

Generic `UseTarget` implementations in `scripts/levels/` (base `UseTargetBase`, exports `target_kind` and `accepted_kinds`; an empty `target_kind` takes the parent animal's kind; a target on a carried or flying animal accepts nothing):

- `DeliveryTarget`: reports `delivered_to` and sends the item home (`reset_to_home`), so deliveries repeat. On the monkey (L1, rides along) and at the trough (L2).
- `WearTarget`: child of an animal; puts a wearable item of an accepted kind on its parent while it wears nothing.
- `PenTarget`: at a pen gate or jetty; puts a carried animal on the next `Marker2D` slot inside its pen zone (slots cycle). Throwing into the zone works as well.

A target may carry an `Art` sprite (gate, jetty, feed bowl).

## Camera (`LevelCamera`)

- `setup(target, bounds)`, `snap()`, `follow(delta)`, `target_point()`, `clamp_to_bounds(p)`, `is_fixed_axis(axis)`, `view_size()`.
- Follows in `_physics_process`: exponential smoothing (`camera_follow_speed`), a lead of `camera_lead_px` in the movement direction, an edge-margin push that keeps the target `camera_edge_margin_px` inside the view, then a cap of `camera_max_step_px` per tick and the clamp to the bounds. An axis on which the level is not larger than the view stays fixed at the bounds centre, so small levels use a fixed camera.
- No built-in `position_smoothing` and no `limit_*`. `offset` is never written: it is reserved for screen shake (BI-8).
- Physics interpolation is on for the camera (Godot 4.7 forces cameras into physics processing when interpolation is on); `snap()` resets it.

Balance (`data/balance/level.json`, namespace `level`): `camera_follow_speed` 7, `camera_max_step_px` 40, `camera_max_lag_px` 4, `camera_jitter_max_px` 0.5, `camera_lead_px` 60, `camera_edge_margin_px` 96, `bounds_thickness` 256, `backdrop_margin_viewports` 1, `walkable_probe_radius` 20, `restart_cue_seconds` 1, `palm_crown_px` 200, `palm_crown_lift_px` 80, `palm_footprint_radius` 18. The dash (about 1440 px/s, 24 px per tick) stays below the step cap.

## Physics interpolation policy

- `physics/common/physics_interpolation = true`, `physics_ticks_per_second = 60`, `physics_jitter_fix = 0`.
- On (inherit): bodies, carried objects, `ThrowFlight`, the castaway including its visual (posed in `_physics_process`, tweens on the physics clock) and the camera.
- Off: every `CanvasLayer` (overlay, cue, error panel, later the HUD) and nodes animated only in `_process` (the `FeedbackDirector` effect layers). Animals and items are posed in `_physics_process` (visual, stars, item hop tween on the physics clock), so they inherit; `relocate_to` and `reset_to_home` call `reset_physics_interpolation()`.

## Painting a layout

Tile data cannot be edited by hand, so layouts are ASCII files painted offline:

```
godot --headless --path . --script res://tools/build_level_layout.gd -- --layout=<txt> --scene=<tscn>
```

Legend: `~` water, `.` sand, `,` grass on sand, `#` rock on sand (solid). Cells outside the text are water, so give the island a water border. The builder writes the `tile_map_data` of the `Sand`, `Grass`, `Shore` and `Details` override sections of the scene (they must exist, for example `[node name="Sand" parent="."]`); the committed `.tscn` is the result and nothing is generated at runtime.

Shore rules (keep the water collision closed):

- A land cell with water on one side becomes a shore edge, with water on two adjacent sides an outer corner; its outer 22 px strip is water collision. Shore cells must be sand `.`.
- A land cell with water only on one diagonal becomes a shore inner corner: a derived tile (atlas source 1, row 3) with the shore rim curving around the notch and a 22×22 px water square in that corner.
- Water on two opposite sides (one-tile strips) or on more than one diagonal is rejected; widen the land instead.
- Rocks carry a solid octagon (radius 40 px) and the surface `stone`.

Grass rules (soft grass-to-sand transitions from `assets/graphics/pirate-pack-derived/grass_edges@2.png`):

- A grass cell with sand or rock on one side gets an edge tile, on two adjacent sides an outer corner tile, and with sand only on one diagonal an inner corner tile (all atlas source 1 on the `Grass` layer, plain sand below). Inner grass cells keep the full grass tiles of the pirate sheet.
- Grass patches must be at least 2 cells wide in both directions; a one-cell strip is a layout error.
- Grass must not touch the shore or water (8-neighbours): keep one plain sand cell between grass and any shore tile.
- Other shapes (for example sand on one side plus a sand diagonal on the far side) are rejected; round the patch off.
- `get_surface_at` reports `grass` for the whole cell of an edge tile.

Props, zones, markers and entities are placed by editing the scene (see `tests/scenes/sample_level.tscn`).

## Props

- `scenes/levels/props/palm.tscn` (`PalmProp`): a top-down pirate-pack palm crown (`tile_70`, `tile_71` default, `tile_72`; set `texture`) of `palm_crown_px` width, lifted `palm_crown_lift_px` above its base, drawn above the actors (absolute z-index 1, not y-sorted) so the castaway walks under its edge. It turns around its centre (`sway.gdshader`, `pivot_mode` 1), casts its shadow at the trunk base and has a solid footprint of `palm_footprint_radius` there. The pack has no trunk art, so the shadow marks the trunk.
- `scenes/levels/props/sway_prop.tscn` (`SwayProp`): side-view foliage from the foliage packs, bent from its base. Bushes (`footprint_radius = 0`, walk-through) and jungle trees (`foliagePack_008`, `foliagePack_010` …, `shadow_width_share` 0.7 and a footprint) – these deciduous trees are not palms.
- `scenes/levels/props/boulder.tscn`: solid boulder.

## Tests

- `tests/levels/test_level_contract.gd` checks every level scene in `tests/scenes` and `scenes/levels`: required zones exist and meet the Zone contract, every entity has a unique uid and a `home_marker` at `HomePoints/<uid>`, spawn, home points (`^[a-z][a-z0-9_]*$`, matching a level entity uid) and zone centres are inside the bounds and on walkable cells, and every walkable cell is reachable from the spawn.
- The sample levels use the real BI-4 entities: a chicken (`chicken_1`) and a coconut (`coconut_1`); `zone_b` is a pen.
- Sample levels (tests only, never referenced from `data/levels`): `tests/scenes/sample_level.tscn` (24×14 tiles, scrolling camera) and `tests/scenes/small_level.tscn` (14×8 tiles, fixed camera), painted from `tests/fixtures/levels/*.layout.txt`. Run one windowed with `Godot_v4.7.2-stable_win64.exe --path . res://tests/scenes/sample_level.tscn`.
- Camera tests read the rendered camera centre from the viewport canvas transform each process frame; in headless runs it already includes the engine's physics interpolation (one frame late, as drawn). `tests/levels/test_level_camera_follow.gd` and `test_level_camera_restart.gd` carry `## run-fps: 60,144`, so `tools/run_tests.py` runs them at both frame rates.
- Shipped levels: `tests/levels/test_shipped_levels.gd` (load, anchors, director, effects, reachable use targets, own theme and music), `test_event_effects.gd`, `test_event_presentation.gd` (warning, HUD cue, actor, reaction), `test_use_targets.gd`, `test_complete_l1_beach_camp.gd` and `test_complete_l2_farm_meadow.gd` (scripted input via `tests/support/level_driver.gd`, events active), `tests/ui/test_level_prompts.gd`, `tests/levels/test_level_data.py` (allocation, timers, workload, no tutorial, no level or task ids in `scripts/`).
- Long tests carry `## watchdog: <s>` in their first five lines: `tools/run_tests.py` passes `--watchdog=<s>` to the runner (game seconds) and raises the process timeout to `max(120, s + 30)` real seconds.
- `python tools/capture_level.py [--level <tscn>] [--size 1920x1080] [--focus x,y]` (opt-in) renders a level with the windowed binary, saves `capture_<height>.png` (other levels: `<level>_capture_<height>.png`, with `--focus` the suffix `_focus_<x>_<y>`) in the testdata folder and checks that the castaway is at least 64 px tall at 1080p. `--focus 17,4` centres the camera on the inner-corner notch of the sample level.
