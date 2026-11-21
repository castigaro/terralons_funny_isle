# Art treatment

Rules for the polished top-down look (GDQuest demos, Kenney top-down games). Every number lives in `data/art/palette.json` and is read through `ArtPalette` (`scripts/levels/art_palette.gd`); this page mirrors it. `tests/levels/test_level_art.gd` checks the rules.

## Outline

- Colour: palette `outline` (`#3b2c22`, dark brown), thickness **3 px at 1920×1080**.
- Packs with a drawn outline never get the outline shader, so outlines are never doubled: `assets/graphics/foliage/`, `assets/graphics/foliage-sprites/`, `assets/graphics/topdown-characters/`, `assets/graphics/animals/PNG/Round (outline)/` (palette `drawn_outline`).
- Packs without an outline get `scenes/levels/art/outline.gdshader`: `assets/graphics/items/` (palette `outlined`). The two lists are disjoint.
- The shader grows the sprite quad by `outline_px` and treats texture coordinates outside 0..1 as transparent, so the outline is never clipped. Set `outline_px = ArtPalette.outline_px() / sprite_scale`, so the thickness on screen stays 3 px whatever the sprite scale.
- Tiles and the water backdrop get no outline (the island tiles have a drawn shoreline).

## Drop shadows

- Every actor (castaway, animals, items) and every prop has a child named `Shadow` that is drawn below its sprite: it is the first visual child and has `z_index = -1` (relative).
- Shadows use `scenes/levels/props/shadow.tscn` (`DropShadow`, texture `scenes/castaway/soft_shadow.tres`): alpha **0.55**, width **0.8 ×** the sprite width, height **0.4 ×** the width (`squash`), offset **(6, 4)** px towards the lower right (palette `shadow`).
- `DropShadow.fit(width, base_y)` sizes the ellipse; `base_y` is where the object touches the ground (0 for base-origin props, about 0.4 × the height for centred sprites).
- Base-ellipse rule for flat-cut foliage: side-view trees and bushes stand on their bottom edge (the node origin), and the shadow ellipse sits on that edge to hide the flat cut. Trees use `shadow_width_share = 0.5`, so the shadow covers the trunk base, not the whole crown.

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

The water highlight bands are white with alpha 0.2 (`highlight`, `highlight_alpha`).

## Layer order and z-index

Bottom to top in every level (`scenes/levels/level_base.tscn`):

1. `WaterBackdrop` – one repeating standalone water texture (`tile_73.png`) with `water.gdshader`, sampled in world space; it covers the level bounds plus one viewport on every side, so no clear colour ever shows.
2. `Sand` – plain sand under every interior land cell.
3. `Grass` – full grass tiles on top of sand.
4. `Shore` – shoreline edge, outer corner and inner corner tiles on the outer land cells (their transparent outer part shows the water).
5. `Details` – rocks.
6. `Actors` – castaway, animals, items and props, `y_sort_enabled`.

- The ground layers (1–5) have `z_index = -2`, shadows `-1`, everything else 0 or more. No other node uses a negative z-index.
- Everything in `Actors` is y-sorted at its base: props have their origin at the bottom of the sprite, actors at their feet or centre.
- UI is drawn on `CanvasLayer`s above the level (cue layer 90, error panel layer 100).

## Motion

- Water: continuous UV distortion (amplitude 5 px) and slow highlight bands from `TIME`; `TIME` keeps running while the tree is paused, so the water also moves behind menus.
- Foliage: `sway.gdshader` bends the sprite from its base (`pow(1 - uv.y, 1.5)`) with a small amplitude (5 px at the top) and a phase hashed from the instance origin, so neighbouring props never sway in sync. `SwayPhase.phase()` mirrors the hash in GDScript.
- Keep motion subtle: the gameplay chaos is the loud part; the environment only breathes.
