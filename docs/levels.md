# Level scenes

Every level is a scene that inherits `scenes/levels/level_base.tscn` (`LevelBase`, `scripts/levels/level_base.gd`). The base loads the level JSON (BI-3, `docs/rules.md`) into a `LevelSession`, owns the handcrafted tile layout, the bounds, the spawn, home points, zones and the camera, feeds the session a world snapshot every physics tick and runs the instant restart. The whole level is always visible: no fog of war, darkness or reveal logic exists (`tools/validate_code.py` rule (h)). Art rules are in `docs/art_treatment.md`.

## Node layout

| Node | Type | Role |
|---|---|---|
| `WaterBackdrop` | `Sprite2D` | animated water under everything, sized at runtime to the bounds plus one viewport per side |
| `Sand`, `Grass`, `Shore`, `Details` | `TileMapLayer` | the layout, all with `scenes/levels/island_tileset.tres` |
| `Actors` | `Node2D`, y-sorted | castaway (`Actors/Castaway`, `castaway_path`), animals, items, props |
| `Markers/Spawn` | `Marker2D` | castaway start; its rotation is the start facing |
| `HomePoints/<uid>` | `Marker2D` | home of the level entity with that uid (reset after restart or when unreachable) |
| `Zones/<zone_id>` | `Area2D` with `LevelZone` | task zones; the node name is the zone id of `in_zone` conditions |
| `Bounds` | `StaticBody2D` | four rectangles built at runtime around the bounds (layer `bounds`) |
| `LevelCamera` | `Camera2D` with `LevelCamera` | the camera, a child of the level and never of the castaway |
| `Overlay/LevelCue`, `Overlay/LevelErrorPanel` | `CanvasLayer` | restart cue and load error panel |

## Groups

- `actor` – castaway, animals and items (all need a `Shadow` child).
- `prop` – palms, bushes, boulders (`SwayProp`, `boulder.tscn`; all need a `Shadow` child).
- `animal`, `item` – kind of a level entity (sprite size checks).
- `level_entity` – everything the snapshot reports. Needs `uid: String`, `kind: String`, `held_by` (the castaway node, a String or null) and `worn_by: String`; optional `reset_to_home()`.
- `surface_provider` – `LevelBase` itself (`get_surface_at`), used by `Grabbable.surface_at` for step and landing sounds.

## LevelBase API

Exports: `level_json_path`, `i18n_dirs` (catalogue folders for the level keys, default `["res://i18n"]`), `session_options` (default `{"schedule_mode": "seeded"}`), `autostart` (default true; the level flow sets false and calls `start_level()` after the intro), `handle_restart_key` (default true; a pause menu owner may switch it off), `bounds_override` (zero size = rectangle of all land cells), `castaway_path`, `push_errors`.

Signals: `level_ready(level_id)`, `level_load_failed(path, errors)`, `restarted(level_id)`, `exit_requested()`. `EventBus.level_restarted(level_id)` fires with `restarted`.

| Method | Returns |
|---|---|
| `start_level()`, `restart_level()` | start (from READY) or restart the attempt |
| `level_session()`, `level_def()`, `castaway()`, `camera()` | the owned objects |
| `is_failed()`, `load_errors()` | load state |
| `get_bounds()`, `backdrop_rect()` | world rectangles |
| `spawn_position()`, `spawn_facing()`, `home_point(uid)`, `has_home_point(uid)` | markers |
| `zone(id)`, `zone_ids()`, `zones_at(pos)` | zones; `zones_at` is a physics point query on the `zones` layer |
| `get_surface_at(pos)` | `stone`, `grass` or `sand` from Details > Shore > Grass > Sand, `water` without land |
| `cell_of(pos)`, `cell_center(cell)`, `is_land_cell(cell)`, `is_walkable_cell(cell)`, `walkable_cells()`, `reachable_from(cell)` | tile cells; walkable means land plus a free circle of `walkable_probe_radius` at the cell centre (shore strips, rocks, prop footprints and bounds count); needs one physics frame after `_ready` |
| `build_snapshot()` | the world snapshot of `docs/rules.md` |
| `LevelBase.required_zone_ids(def)` | zone ids referenced by the tasks (static) |

### Load sequence

1. Required child nodes and the castaway are checked.
2. Bounds = `bounds_override` or the rectangle of all `Sand` and `Shore` cells; the `Bounds` body and the water backdrop are sized from it.
3. The level JSON is validated by `LevelDef` with the messages of every `i18n_dirs` folder; every zone used by a task must exist under `Zones`.
4. Any problem ends in the failed state: errors are pushed (unless `push_errors` is false), `level_load_failed` fires, the castaway is disabled and the opaque error panel shows the translated message, the path and a Back button (`exit_requested`, or the main scene when nothing is connected). The water stays visible; nothing ticks and nothing crashes.
5. Otherwise the session is created, the camera set up, the castaway reset to the spawn and, with `autostart`, the session started.

`_physics_process` (priority 1, after the castaway at 0, before the camera at 2) ticks the session with `build_snapshot()` while it is `RUNNING` or `REQUIRED_DONE`.

### Snapshot

`player.zones` = `zones_at(castaway)`, `player.held` = kind of the carried thing, `player.worn` = `castaway.get_worn_kind()` when it exists, `player.stunned` = `castaway.is_dizzy()`. `entities` lists every `level_entity` below the level sorted by uid with `uid`, `kind`, `zones`, `held_by` (`player` when held by the castaway) and `worn_by`. An empty list is valid.

### Restart sequence (all in one call, so the snap happens in one frame)

1. `session.restart()` and `session.start()`.
2. `castaway.reset_to(spawn_position(), spawn_facing())`.
3. `reset_to_home()` on every level entity that has it (it uses `home_point(uid)`).
4. `camera.snap()`.
5. The cue `level.restarted` shows for `restart_cue_seconds`; `restarted` and `EventBus.level_restarted` fire.

Every teleport must call `reset_physics_interpolation()` on the moved node, otherwise the engine draws an interpolated sweep: `Castaway.reset_to`, the castaway safety net, `LevelCamera.snap` and every `reset_to_home`.

## Camera (`LevelCamera`)

- `setup(target, bounds)`, `snap()`, `follow(delta)`, `target_point()`, `clamp_to_bounds(p)`, `is_fixed_axis(axis)`, `view_size()`.
- Follows in `_physics_process`: exponential smoothing (`camera_follow_speed`), a lead of `camera_lead_px` in the movement direction, an edge-margin push that keeps the target `camera_edge_margin_px` inside the view, then a cap of `camera_max_step_px` per tick and the clamp to the bounds. An axis on which the level is not larger than the view stays fixed at the bounds centre, so small levels use a fixed camera.
- No built-in `position_smoothing` and no `limit_*`. `offset` is never written: it is reserved for screen shake (BI-8).
- Physics interpolation is on for the camera (Godot 4.7 forces cameras into physics processing when interpolation is on); `snap()` resets it.

Balance (`data/balance/level.json`, namespace `level`): `camera_follow_speed` 7, `camera_max_step_px` 40, `camera_max_lag_px` 4, `camera_jitter_max_px` 0.5, `camera_lead_px` 60, `camera_edge_margin_px` 96, `bounds_thickness` 256, `backdrop_margin_viewports` 1, `walkable_probe_radius` 20, `restart_cue_seconds` 1, `max_zone_hits` 32. The dash (about 1440 px/s, 24 px per tick) stays below the step cap.

## Physics interpolation policy

- `physics/common/physics_interpolation = true`, `physics_ticks_per_second = 60`, `physics_jitter_fix = 0`.
- On (inherit): bodies, carried objects, `ThrowFlight`, the castaway including its visual (posed in `_physics_process`, tweens on the physics clock) and the camera.
- Off: every `CanvasLayer` (overlay, cue, error panel, later the HUD) and nodes animated only in `_process`.

## Painting a layout

Tile data cannot be edited by hand, so layouts are ASCII files painted offline:

```
godot --headless --path . --script res://tools/build_level_layout.gd -- --layout=<txt> --scene=<tscn>
```

Legend: `~` water, `.` sand, `,` grass on sand, `#` rock on sand (solid). Cells outside the text are water, so give the island a water border. The builder writes the `tile_map_data` of the `Sand`, `Grass`, `Shore` and `Details` override sections of the scene (they must exist, for example `[node name="Sand" parent="."]`); the committed `.tscn` is the result and nothing is generated at runtime.

Shore rules (keep the water collision closed):

- A land cell with water on one side becomes a shore edge, with water on two adjacent sides an outer corner; its outer 22 px strip is water collision. Shore cells must be sand `.`.
- A land cell with water only on one diagonal becomes an inner corner (plain sand with a 22×22 px water square in that corner).
- Water on two opposite sides (one-tile strips) or on more than one diagonal is rejected; widen the land instead.
- Rocks carry a solid octagon (radius 40 px) and the surface `stone`.

Props, zones, markers and entities are placed by editing the scene (see `tests/scenes/sample_level.tscn`).

## Tests

- `tests/levels/test_level_contract.gd` checks every level scene in `tests/scenes` and `scenes/levels`: required zones exist, spawn, home points (`^[a-z][a-z0-9_]*$`, matching a level entity uid) and zone centres are inside the bounds and on walkable cells, and every walkable cell is reachable from the spawn.
- Sample levels (tests only, never referenced from `data/levels`): `tests/scenes/sample_level.tscn` (24×14 tiles, scrolling camera) and `tests/scenes/small_level.tscn` (14×8 tiles, fixed camera), painted from `tests/fixtures/levels/*.layout.txt`. Run one windowed with `Godot_v4.7.2-stable_win64.exe --path . res://tests/scenes/sample_level.tscn`.
- Camera tests read the rendered camera centre from the viewport canvas transform each process frame; in headless runs it already includes the engine's physics interpolation (one frame late, as drawn). `tests/levels/test_level_camera_follow.gd` and `test_level_camera_restart.gd` carry `## run-fps: 60,144`, so `tools/run_tests.py` runs them at both frame rates.
- `python tools/capture_level.py [--level <tscn>] [--size 1920x1080]` (opt-in) renders a level with the windowed binary, saves the screenshot below the testdata folder and checks that the castaway is at least 64 px tall at 1080p.
