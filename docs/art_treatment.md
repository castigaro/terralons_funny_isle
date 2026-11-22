# Art treatment

Rules for the polished top-down look (GDQuest demos, Kenney top-down games). Every number lives in `data/art/palette.json` and is read through `ArtPalette` (`scripts/levels/art_palette.gd`); this page mirrors it. `tests/levels/test_level_art.gd` checks the rules.

## Outline

- Colour: palette `outline` (`#3b2c22`, dark brown), thickness **3 px at 1920×1080**.
- Packs with a drawn outline never get the outline shader, so outlines are never doubled: `assets/graphics/foliage/`, `assets/graphics/foliage-sprites/`, `assets/graphics/pirate-pack/PNG/Retina/Tiles/` (palm crowns), `assets/graphics/topdown-characters/`, `assets/graphics/animals/PNG/Round (outline)/` (palette `drawn_outline`).
- Packs without an outline get `scenes/levels/art/outline.gdshader`: `assets/graphics/items/` (palette `outlined`). The two lists are disjoint.
- The shader grows the sprite quad by `outline_px` and treats texture coordinates outside 0..1 as transparent, so the outline is never clipped. Set `outline_px = ArtPalette.outline_px() / sprite_scale` (`ArtPalette.apply_outline(sprite)` does this; `Item` calls it), so the thickness on screen stays 3 px whatever the sprite scale.
- Tiles and the water backdrop get no outline (the island tiles have a drawn shoreline).

## Drop shadows

- Every actor (castaway, animals, items) and every prop has a child named `Shadow` that is drawn below its sprite: it is the first visual child and has `z_index = -1` (relative). Every `Shadow` uses the `DropShadow` script, so its alpha comes from the palette.
- Shadows use the texture `scenes/castaway/soft_shadow.tres`: a radial gradient in the palette colour `shadow` (`#1e3b3f`, a dark blue-green, Kenney style, never pure black) with full alpha at the centre, 0.7 at half the radius and 0 at the rim. `DropShadow` multiplies it by alpha **0.75**, so the ellipse core is 0.75.
- Props use `scenes/levels/props/shadow.tscn` and `DropShadow.fit(width, base_y)`: width **0.8 ×** the object width, but never below **48 px** (`min_px`), height **0.5 ×** the width (`squash`), offset **(6, 4)** px towards the lower right (palette `shadow`).
- Measurable visibility rule: on sand, the darkest shadow pixel (palette `shadow` at alpha 0.75 over `sand`) is at least **25 %** darker in relative luminance than the sand (`min_contrast_on_sand`; it is about 70 %). `tests/levels/test_level_art.gd` computes it from `palette.json`.
- `DropShadow.fit(width, base_y)` sizes the ellipse; `base_y` is where the object touches the ground (0 for base-origin props, about 0.4 × the height for centred sprites).
- Base-ellipse rule for flat-cut foliage: side-view trees and bushes stand on their bottom edge (the node origin), and the shadow ellipse sits on that edge to hide the flat cut. Trees use `shadow_width_share = 0.7` (`tree_width_share`), so the shadow covers the trunk base, not the whole crown.
- Top-down canopy rule (palms, `PalmProp`): the crown is drawn above the actors (absolute z-index 1, not y-sorted), lifted `palm_crown_lift_px` above the base, and its shadow (0.7 × the crown width) sits on the ground at the trunk base, so the castaway can walk under the crown edge while the shadow shows where the solid trunk is.

## Palette

| Key | Colour | Use |
|---|---|---|
| `sand` | `#fae8c2` | sand tiles (reference) |
| `grass` | `#2ecc71` | grass tiles (reference) |
| `water` | `#abe3f5` | water tint, `rendering/environment/defaults/default_clear_color` |
| `water_deep` | `#5bb8de` | deep water accents |
| `foliage` | `#2e9e5b` | foliage tint for grass tufts |
| `outline` | `#3b2c22` | outline shader colour |
| `ui_panel` | `#1d2733` | dark panels (error panel, cues) |
| `ui_text` | `#f7f3e8` | text on `ui_panel` (contrast at least 4.5:1) |
| `ui_accent` | `#ffc93c` | highlights, stars |
| `shadow` | `#1e3b3f` | drop shadow colour (gradient of `soft_shadow.tres`) |

The water highlight bands are white with alpha 0.2 (`highlight`, `highlight_alpha`).

## Layer order and z-index

Bottom to top in every level (`scenes/levels/level_base.tscn`):

1. `WaterBackdrop` – one repeating standalone water texture (`tile_73.png`) with `water.gdshader`, sampled in world space; it covers the level bounds plus one viewport on every side, so no clear colour ever shows.
2. `Sand` – plain sand under every interior land cell.
3. `Grass` – textured grass on top of sand: inner cells use one of four derived fill variants (palette grass shaded by value noise that wraps on the tile, a few foliage-coloured blade marks; luma standard deviation 0.025–0.04; all variants share a 6 px border band, so any neighbours are seamless) and border cells the derived soft grass-to-sand edge, outer corner and inner corner tiles built from fill variant 0 (`assets/graphics/pirate-pack-derived/grass_edges@2.png`, wavy border measured from the pack's grass blob, sand strip 40 px deep), never a hard or flat grass square.
4. `Shore` – shoreline edge and outer corner tiles of the pack and the derived inner corner tiles on the outer land cells (their transparent outer part shows the water).
5. `Details` – rocks.
6. `GroundDecor` – flat set dressing (BI-20): fields, fence runs and driftwood as plain `Sprite2D` decals in group `decor`, `z_index = -2`, after `Details` and before `ZoneMarkers`. They carry their soft shadow baked into the PNG (palette `shadow` at about 0.35 alpha, offset (3, 3), 2 px blur) instead of a `Shadow` node, are not in group `prop`, have no collision and never cover actors; the castaway and the animals walk over them.
7. `ZoneMarkers` – one `ZoneMarker` per player-action zone (pens, ponds, perches, the trough, the sandcastle site, the shelter and the mud pool): a nine-patch outline on the zone bounds, `z_index = -2`, drawn after the ground and below the actors.
8. `Actors` – castaway, animals, items and props, `y_sort_enabled`.

- The ground layers (1–5), `GroundDecor` and `ZoneMarkers` have `z_index = -2`; shadows and the ground art of use targets (gate and jetty `Art`, the L5 `Puddle`) have `-1`; everything else 0 or more. No other node uses a negative z-index (`test_only_ground_layers_use_negative_z`).
- Everything in `Actors` is y-sorted at its base: props have their origin at the bottom of the sprite, actors at their feet or centre.
- UI is drawn on `CanvasLayer`s above the level (cue layer 90, error panel layer 100).

## Set dressing (BI-20)

- Theme props come from `tools/derive_theme_props.gd` (`assets/graphics/theme-derived/`, see `docs/asset_map.md`): deterministic, transparent around the silhouette (except the field), a drawn outline in palette `outline` (2–3 px), so they are listed under `drawn_outline` and never get the outline shader.
- Standing decor (tent, crate stack, barrels, campfire) uses `scenes/levels/props/decor_prop.tscn` (`DecorProp`): base origin (y-sorted at its base), the `Shadow` as first child sized by `DropShadow.fit` (0.8 × the width, at least 48 px), groups `prop` and `decor`, no physics. Decor taller than 100 px stands only on a solid layout cell (`#`), so the castaway can never stand inside it; the barn of L2 is the sprite of an existing boulder and keeps its collision circle.
- Flat decor goes under `GroundDecor` (above) and keeps off zones, home points, the spawn and event anchors; fence runs may sit on a zone's outer 16 px band.
- White foliage-sprites tufts are tinted per instance with `SwayProp.tint` (sprite only, the shadow keeps its palette alpha); Beach Camp uses a sand-green `(0.62, 0.78, 0.42)`.
- The campfire flame (`Flame`, an `AnimatedSprite2D` of the particle pack's `flame_01`–`flame_06` with additive blending) flickers at 4 fps without brightness jumps and stays on its first frame when "reduce screen shake and flashes" is on (WCAG 2.3.1).
- Props on water (BI-22, Lagoon): stilt huts stand on water cells only, with their stilts in pale ripple rings baked into the PNG. Huts and boats use `shadow_style` water: the `Shadow` is tinted palette `water_deep`, its alpha is the palette shadow alpha × `water_shadow_alpha_share` (0.6), it is `water_shadow_widen` (1.15) wider and sits flat at the base without the downward offset – a soft reflection, never a dark ground shadow on the water. Boats set `bob`: `scenes/levels/art/bob.gdshader` lifts and sinks the sprite by `boat_bob_px` (3 px) and rocks it by `boat_bob_tilt_deg` (1.5°) at `boat_bob_speed` (0.9 rad/s), phase hashed from the origin, no colour change; with "reduce screen shake and flashes" the boats get no material and stay still. Docks are flat `GroundDecor` decals, so every actor draws above them.
- `tests/levels/test_theme_decor.gd` guards the play fingerprint (`tests/support/play_fingerprint.gd`, baselines in `tests/fixtures/levels/play_baseline_<level>.json`, written by `tools/level_play_fingerprint.gd` only from a reference state), the placement rules and that Beach Camp and Farm Meadow share no theme texture.

## No flat placeholder ground (BI-19)

- No flat single-colour ground, zone or filled sprite: `tools/validate_code.py` rule (j) bans `ColorRect`, `Polygon2D` and `Line2D` nodes in level scenes and `draw_rect`, `draw_circle`, `draw_colored_polygon` and `draw_polygon` in gameplay, level and feedback scripts.
- Two thresholds on the sRGB luma (`tests/support/ground_art.gd`): the green pixels of every grass tile and every opaque filled sprite (opaque share of at least 0.9) need a standard deviation of at least 0.02; every other ground tile (sand, shore, details) at least 0.005. The pack's full grass tile (6,1) has 0 and fails both. Sand keeps the pack tiles (0.007–0.008); themed sand textures follow in later items.
- Zone markers: `assets/graphics/pirate-pack-derived/zone_marker@2.png`, a 64 px nine-patch (margins 24, transparent centre) with a dark outer line in palette `outline` (3 px, at least 3:1 on grass and on sand) and a light inner line in palette `zone_marker` (2.5 px), scaled ×2 in the world. Shape and the zone props are the non-colour cue; there is no fill and no animation. Area zones (the L4 beach and lagoon) and helper zones (lanes, flee areas, event perches) stay unmarked.
- Sandcastle frames: `tools/derive_sandcastle.gd` recolours the pack's tower tiles onto a ramp of palette sand (site ring, small tower, tower, keep) and draws the flattened frame as a wide low mound; every frame is transparent around its silhouette.
- Opt-in screenshot check: `python tools/flat_area_check.py <playtest dir>` reports 96 px windows with a luma standard deviation below 0.015 outside the HUD bands, water and sand.

## Motion

- Water: continuous UV distortion (amplitude 5 px) and slow highlight bands from `TIME`; `TIME` keeps running while the tree is paused, so the water also moves behind menus.
- Foliage: `sway.gdshader` bends the sprite from its base (`pivot_mode` 0, `pow(1 - uv.y, 1.5)`) with a small amplitude (5 px at the top) and a phase hashed from the instance origin, so neighbouring props never sway in sync. Top-down palm crowns use `pivot_mode` 1: a turn of `turn_deg` (3°) around the crown centre plus a small drift. `SwayPhase` mirrors the hash and the pivot constants in GDScript.
- Keep motion subtle: the gameplay chaos is the loud part; the environment only breathes.
