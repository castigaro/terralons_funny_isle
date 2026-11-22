# Asset map

The sprites, fonts and sounds that later items use, chosen from the CC0 packs in `assets/` (sources in `assets/SOURCES.md`). Only folders that appear here are imported by Godot; every other pack folder carries a `.gdignore`. A later item may pick a different file from an imported folder; to use a file from an excluded folder, delete that folder's `.gdignore` and add the file here. `python tools/validate_assets.py` lists every imported file that nothing references as a warning, so the list shrinks as the game grows.

Rules: every visible sprite and every sound comes from `assets/` (R-39); file names on the deny list `data/assets/deny_list.json` (weapons, violence, scary content) must never be used (R-43). Paths in backticks are checked by `tests/core/test_validate_assets.py`.

## Castaway

- Standing: `assets/graphics/topdown-characters/PNG/Survivor 1/survivor1_stand.png` (37×43 px)
- Carrying (arms forward): `assets/graphics/topdown-characters/PNG/Survivor 1/survivor1_hold.png`
- The sprite is small: draw it at scale 2 (86 px tall at 1920×1080, above the 64 px minimum) with linear filtering; squash and stretch, the run bob and the drop shadow are done in code.
- The folders `Man Blue`, `Man Brown`, `Man Old` and `Woman Green` stay imported for a possible skin choice; the interior tiles (`PNG/Tiles`) and the tilesheet are excluded.

## Animals

Round heads with outline (about 130–190 px; draw at scale 0.5–0.6) from `assets/graphics/animals/PNG/Round (outline)/`:

- `assets/graphics/animals/PNG/Round (outline)/chicken.png`, `assets/graphics/animals/PNG/Round (outline)/chick.png`
- `assets/graphics/animals/PNG/Round (outline)/goat.png`, `assets/graphics/animals/PNG/Round (outline)/pig.png`
- `assets/graphics/animals/PNG/Round (outline)/duck.png`, `assets/graphics/animals/PNG/Round (outline)/parrot.png`
- `assets/graphics/animals/PNG/Round (outline)/monkey.png`, `assets/graphics/animals/PNG/Round (outline)/frog.png`
- `assets/graphics/animals/PNG/Round (outline)/penguin.png`, `assets/graphics/animals/PNG/Round (outline)/cow.png`
- Reserve: rabbit, owl, sloth, walrus. The variant without outline (`PNG/Round`) and the spritesheets are excluded.

## Items

Generic items, coloured (`assets/graphics/items/PNG/Colored/`). The pack has no coconut and no hat; the substitutes below are the closest shapes and may be swapped within the task example pools (BI-4):

| Role | File | Note |
|---|---|---|
| Coconut | `assets/graphics/items/PNG/Colored/genericItem_color_161.png` | brown ball, 24 px – draw at scale 2.5 |
| Hat (straw hat) | `assets/graphics/items/PNG/Colored/genericItem_color_152.png` | beige dome, reads as a hat from above |
| Bucket | `assets/graphics/items/PNG/Colored/genericItem_color_114.png` | pot with handles |
| Sand pail shovel | `assets/graphics/items/PNG/Colored/genericItem_color_022.png` | shovel |
| Message bottle | `assets/graphics/items/PNG/Colored/genericItem_color_127.png` | bottle |
| Bone | `assets/graphics/items/PNG/Colored/genericItem_color_101.png` | treat for animals |
| Key | `assets/graphics/items/PNG/Colored/genericItem_color_155.png` | cage key |
| Bag | `assets/graphics/items/PNG/Colored/genericItem_color_143.png` | carry bag |
| Compass | `assets/graphics/items/PNG/Colored/genericItem_color_162.png` | treasure prop |
| Feed bowl (trough, L2) | `assets/graphics/items/PNG/Colored/genericItem_color_128.png` | blue bowl, art of the trough use target |

Never use the knife (`genericItem_color_134`), the axe (`_020`), saws or other sharp tools as carryable items.

## Tiles and props

Island tiles 128×128 px from the pirate pack (`assets/graphics/pirate-pack/PNG/Retina/Tiles/`, the pack's tilesheet says 64 px at 1×):

- Level TileMapLayers use the retina tilesheet `assets/graphics/pirate-pack/Tilesheet/tiles_sheet@2.png` (16×6 tiles of 128 px) through `scenes/levels/island_tileset.tres` (BI-5): shore edges and outer corners at atlas (0–2, 0–2), rocks at (0–2, 3–4), plain sand at (3–4, 4), full grass at (6–7, 1–2). The water backdrop uses the standalone `assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_73.png`, because shader distortion on an atlas tile bleeds into its neighbours.

- Sand island with shoreline: `tile_01`–`tile_03`, `tile_17`–`tile_19`, `tile_33`–`tile_35` (for example `assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_18.png`)
- Grass on sand: `tile_06`–`tile_09`, `tile_22`–`tile_25`, `tile_38`–`tile_41`, `tile_54`–`tile_57`; full grass `assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_23.png`
- Derived transitions (BI-5, BI-19): `assets/graphics/pirate-pack-derived/grass_edges@2.png` (4×5 tiles of 128 px, atlas source 1 of `island_tileset.tres`), built once by `tools/derive_grass_edges.gd` from the tilesheet. Row 0: grass edges with sand to the N, S, W, E; row 1: grass outer corners NW, NE, SW, SE; row 2: grass inner corners (sand only on that diagonal); row 3: shore inner corners (water only on that diagonal) with a water collision square; row 4: four textured grass fill variants (surface `grass`, no collision). The pack has no stand-alone grass-to-sand transitions (its blob edges are baked into the shore ring), no shore inner corners and only a flat full-grass tile; the layouts no longer use the pack's full grass tiles.
- Palm crowns (top-down): `assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_70.png`, `tile_71`, `tile_72` (tilesheet atlas (5–7, 4)) in `scenes/levels/props/palm.tscn`; the foliage pack has no palms, its deciduous trees (`foliagePack_008`, `foliagePack_010` …) stay available as jungle trees.
- Water (animate by UV scroll or shader): `assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_73.png`
- Stone ground (volcano cliffs): `tile_10`–`tile_12`, `tile_26`–`tile_28`, `tile_42`–`tile_44`, `tile_58`, `tile_59`, `tile_74`, `tile_75`
- Rocks: `assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_49.png`, `tile_50`, `tile_51`, mossy `tile_65`–`tile_67`
- Sand details and small plants: `tile_68`, `tile_69`, `tile_70`–`tile_72`, `tile_87`, `tile_88`
- Props: wrecked boat `assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_81.png`, wooden bridge `tile_60` and `tile_76` (BI-10: pen gates use `tile_76`, the pond jetty `tile_60`; the packs have no fence, so pens are framed by bushes)
- Levels 3–5 (BI-11): the perch, goat pen, shelter and mud pool gates use `tile_76`, the pond and lagoon jetties `tile_60`, the beach landmark of the lagoon (`BeachFlag`) the wrecked boat `tile_81` (the pack's flags sit in the excluded ship parts). The mud pool is a mud-tinted splat `assets/graphics/splats/PNG/Default (256px)/splat03.png`.
- Sandcastle stages (`BuildTarget`, L4, BI-19), derived by `tools/derive_sandcastle.gd`: build site `assets/graphics/pirate-pack-derived/sandcastle_0@2.png` (hollow sand ring), small tower `assets/graphics/pirate-pack-derived/sandcastle_1@2.png`, tower `assets/graphics/pirate-pack-derived/sandcastle_2@2.png`, keep `assets/graphics/pirate-pack-derived/sandcastle_3@2.png`; flattened `assets/graphics/pirate-pack-derived/sandcastle_flat@2.png` (low mound). The towers are the pack's stone fortress pieces `tile_13` and `tile_14` recoloured to sand; there is no dedicated sandcastle sprite. The opaque squares `tile_68` and `tile_69` are no longer used.
- Zone markers (BI-19): `assets/graphics/pirate-pack-derived/zone_marker@2.png`, derived by `tools/derive_zone_marker.gd` from the outer line of the UI pack's `assets/ui/ui-pack/PNG/Extra/Default/button_round_line.png` (which has a filled white centre and is not used directly), in `scenes/levels/props/zone_marker.tscn`.
- Ships, ship parts (cannons, skull sails) and the explosion effects are excluded.

Foliage (`assets/graphics/foliage/PNG/Retina/`), sway by a shader:

- Trees: `assets/graphics/foliage/PNG/Retina/foliagePack_008.png`, `foliagePack_007`, `foliagePack_009`–`foliagePack_011`; autumn trees `foliagePack_013`–`foliagePack_018` for the jungle and volcano levels
- Bushes: `assets/graphics/foliage/PNG/Retina/foliagePack_050.png`, `foliagePack_051`–`foliagePack_053`
- Flowers: `assets/graphics/foliage/PNG/Retina/foliagePack_001.png`, `foliagePack_002`–`foliagePack_004`
- Grass: `foliagePack_019`–`foliagePack_022`; boulders `foliagePack_054`–`foliagePack_056`
- White grass tufts for tinting and swaying (`assets/graphics/foliage-sprites/PNG/Shaded/`): `assets/graphics/foliage-sprites/PNG/Shaded/sprite_0052.png` to `sprite_0069`

Jungle decoration of L3 (BI-21), generated by `tools/place_jungle_decor.py` into `scenes/levels/decor/l3_jungle_decor.tscn`; every white foliage-sprite and every foliage-pack tree and bush there is tinted from the palette (`tint_key`):

- Canopy: trees `assets/graphics/foliage/PNG/Retina/foliagePack_007.png`, `foliagePack_011`, `foliagePack_012`, `foliagePack_040`, `foliagePack_042` (tint `jungle_canopy`), creepers beside the trunks `assets/graphics/foliage-sprites/PNG/Shaded/sprite_0094.png`, `sprite_0095` (tint `jungle_leaf_deep`), walk-through palm crowns `tile_71`, `tile_72` on the sand ring.
- Bushes: `foliagePack_050`–`foliagePack_053` and the trunkless crowns `foliagePack_038`, `foliagePack_039`, `foliagePack_041` (tint `jungle_canopy`), large leaves `assets/graphics/foliage-sprites/PNG/Shaded/sprite_0084.png`, `sprite_0085`, `sprite_0087`, `sprite_0089` (tint `jungle_leaf`), tall leafy plants `sprite_0092`, `sprite_0093` (tint `jungle_leaf_deep`).
- Ground cover: grass `foliagePack_020`, `foliagePack_022`, flowers `foliagePack_002`, `foliagePack_004`, ferns and grass tufts `sprite_0052`, `sprite_0053`, `sprite_0062`, `sprite_0063`, `sprite_0065`, `sprite_0069`, `sprite_0070` (tint `jungle_fern`).
- The L3 props of 1.1.0 keep their places: trees now `foliagePack_007`, `foliagePack_011`, `foliagePack_012`, `foliagePack_040`, `foliagePack_042`, bushes `foliagePack_050`–`foliagePack_053` (all tinted `jungle_canopy`), flowers `foliagePack_002` and `foliagePack_004`, grass `foliagePack_020` and `foliagePack_022`. L2 keeps the lime trees `foliagePack_008` and `foliagePack_010`. The leaf rosettes `sprite_0096`–`sprite_0098` were tried and dropped: tinted dark they read as dirt smudges on the grass.

## UI

- Buttons (blue, with depth): `assets/ui/ui-pack/PNG/Blue/Default/button_rectangle_depth_gradient.png`, `assets/ui/ui-pack/PNG/Blue/Default/button_round_depth_gradient.png`, `assets/ui/ui-pack/PNG/Blue/Default/button_square_depth_gradient.png`
- Volume sliders: `assets/ui/ui-pack/PNG/Blue/Default/slide_horizontal_color.png`, `assets/ui/ui-pack/PNG/Blue/Default/slide_hangle.png`
- Toggle: `assets/ui/ui-pack/PNG/Blue/Default/check_square_color_checkmark.png`, `assets/ui/ui-pack/PNG/Blue/Default/check_square_grey.png`
- Task done and failed: `assets/ui/ui-pack/PNG/Blue/Default/icon_checkmark.png`, `assets/ui/ui-pack/PNG/Blue/Default/icon_cross.png`
- Stars (result screen, thresholds): `assets/ui/ui-pack/PNG/Yellow/Default/star.png`, `assets/ui/ui-pack/PNG/Yellow/Default/star_outline.png`
- Icons: play `assets/ui/ui-pack/PNG/Extra/Default/icon_play_light.png`, retry `assets/ui/ui-pack/PNG/Extra/Default/icon_repeat_light.png`, back `assets/ui/ui-pack/PNG/Blue/Default/arrow_basic_w.png`
- Menu icons (BI-7, `scripts/ui/menus/`): icons on the blue buttons come from the Yellow set for contrast: back and next `assets/ui/ui-pack/PNG/Yellow/Default/arrow_basic_w.png`, `assets/ui/ui-pack/PNG/Yellow/Default/arrow_basic_e.png`; the pack has no gear, pause, lock, quit or language icon, so the substitutes are: settings = text only (the slider handle and the 16 px slider section both read as a dot on the button in the windowed check, and settings is not one of the glyph actions of AC1), quit and locked level = `assets/ui/ui-pack/PNG/Yellow/Default/icon_cross.png`, credits = Yellow `star`, language = the language name as text (no icon). Volume slider track `assets/ui/ui-pack/PNG/Blue/Default/slide_horizontal_grey.png` with the `slide_horizontal_color` fill; the hovered or focused slider shows the Yellow grabber `assets/ui/ui-pack/PNG/Yellow/Default/slide_hangle.png` next to its focus ring. Level tiles use `button_square_depth_gradient`, the title shows the round animals `chicken`, `pig`, `goat`, `duck`, `monkey` and `penguin`.
- Emote bubbles (Style 1, `assets/graphics/emotes/PNG/Vector/Style 1/`): `assets/graphics/emotes/PNG/Vector/Style 1/emote_stars.png` (dizzy), `emote_exclamation`, `emote_question`, `emote_anger`, `emote_heart`, `emote_laugh`, `emote_swirl`, `emote_faceHappy`, `emote_faceSad`
- The colours Grey, Green and Red and all `Double` variants are excluded.

## Fonts

- Every text (headings, timer, buttons, body, hints, prompts, captions, popups): `assets/ui/fonts-derived/Kenney Future Fixed.ttf` (`MenuTheme.FONT`), derived from `assets/ui/ui-pack/Font/Kenney Future.ttf` by `python tools/derive_font.py`. The source draws X like H, % like a stretched S and ß like B; the derived font has diagonal X and x, a slashed %, ß as SS and the en dash mapped to the hyphen, without system fallback. `tests/ui/test_ui_font_glyphs.gd` checks every i18n codepoint and the glyph shapes.
- Kenney Future Narrow and the pixel fonts in `assets/ui/fonts/` stay imported but are not used.

## Particles and effects

- Smoke puffs (dash, landing, BONK): `assets/graphics/smoke/PNG/White puff/whitePuff00.png` to `whitePuff24`
- Fart cloud (pig in mud, comic relief): `assets/graphics/smoke/PNG/Fart/fart00.png` to `fart08`
- Flash (task done, grab): `assets/graphics/smoke/PNG/Flash/flash00.png` to `flash07`
- Splats (mud, splash, thrown items; tint per material): `assets/graphics/splats/PNG/Default (256px)/splat00.png` to `splat35`
- Stars and sparkles (dizzy stars, task done, 3-star result): `assets/graphics/particles/PNG/star_01.png` to `star_09`, `assets/graphics/particles/PNG/spark_01.png` to `spark_07`
- Dust and speed lines: `assets/graphics/particles/PNG/dirt_01.png` to `dirt_03`, `assets/graphics/particles/PNG/trace_01.png` to `trace_07`
- Water drops and rain: `assets/graphics/particles/PNG/circle_01.png` to `circle_05`
- Never use `muzzle_*`, `scorch_*`, `slash_*` or `fire_*` (deny list or scary).
- Feedback (`data/feedback.json`, BI-8): popups in the UI font `assets/ui/fonts-derived/Kenney Future Fixed.ttf`; emotes `emote_exclamation`, `emote_heart`, `emote_swirl`, `emote_question`, `emote_anger`, `emote_stars` and `emote_laugh` from `assets/graphics/emotes/PNG/Vector/Style 1/`; puffs `whitePuff00`–`whitePuff11`, fart `fart00`–`fart08`, flash `flash00`–`flash07`, splats `splat00`–`splat07` tinted mud, water or sand; particles `dirt_01`, `trace_01`, `star_01`, `spark_01` and `circle_01`.

## Music

Chiptunes (`assets/audio/music/`, WAV, loop on import), allocation per D-2:

- Title and level select: `assets/audio/music/Juhani Junkala [Retro Game Music Pack] Title Screen.wav`
- Level 1: `assets/audio/music/Juhani Junkala [Retro Game Music Pack] Level 1.wav`
- Level 2 and level 4: `assets/audio/music/Juhani Junkala [Retro Game Music Pack] Level 2.wav`
- Level 3 and level 5: `assets/audio/music/Juhani Junkala [Retro Game Music Pack] Level 3.wav`
- Credits: `assets/audio/music/Juhani Junkala [Retro Game Music Pack] Ending.wav`

## SFX

- Steps: `assets/audio/sfx-rpg/OGG/footstep00.ogg` to `footstep09`
- Grab: `assets/audio/sfx-rpg/OGG/cloth1.ogg`, `cloth2`–`cloth4`
- Throw: `assets/audio/sfx-interface/Audio/maximize_001.ogg`, `maximize_002`–`maximize_004`
- Land and drop: `assets/audio/sfx-interface/Audio/drop_001.ogg`, `drop_002`–`drop_004`, `assets/audio/sfx-rpg/OGG/dropLeather.ogg`
- BONK: `assets/audio/sfx-rpg/OGG/metalPot1.ogg`, `metalPot2`, `metalPot3`
- Splash: `assets/audio/sfx-interface/Audio/glass_001.ogg`, `glass_002`–`glass_006`
- Dash: `assets/audio/sfx-interface/Audio/scratch_001.ogg`, `scratch_002`–`scratch_005`
- Animal reactions (pitch-shifted per animal): `assets/audio/sfx-interface/Audio/pluck_001.ogg`, `pluck_002`, `assets/audio/sfx-interface/Audio/bong_001.ogg`, `question_001`–`question_004`
- Task done: `assets/audio/sfx-interface/Audio/confirmation_001.ogg`, `confirmation_002`–`confirmation_004`
- Failure cue: `assets/audio/sfx-interface/Audio/error_001.ogg`, `error_002`–`error_008`
- Cage, latch, door: `assets/audio/sfx-rpg/OGG/metalLatch.ogg`, `assets/audio/sfx-rpg/OGG/doorClose_1.ogg`, `creak1`–`creak3`
- Menus (`ui_click`, `ui_hover` in `data/audio.json`): `assets/audio/sfx-ui/click1.wav`, `assets/audio/sfx-ui/rollover1.wav`; reserve `assets/audio/sfx-ui/switch1.wav`
- Timer warning tick: `assets/audio/sfx-interface/Audio/tick_001.ogg`, `tick_002`, `tick_004`
- Never use `drawKnife*` or `knifeSlice*` (deny list).

## Jingles

NES set (`assets/audio/jingles/OGG/jingles_NES/`), duck the music while playing:

- Task done: `assets/audio/jingles/OGG/jingles_NES/jingles_NES03.ogg`
- Level won: `assets/audio/jingles/OGG/jingles_NES/jingles_NES00.ogg`
- Level lost: `assets/audio/jingles/OGG/jingles_NES/jingles_NES09.ogg`
- Spare set: `jingles_PIZZA`. The sets HIT, SAX and STEEL are excluded.

## Announcer

Male voice (`assets/audio/voiceover/Male/`, the female set is excluded):

- `assets/audio/voiceover/Male/ready.ogg`, `assets/audio/voiceover/Male/set.ogg`, `assets/audio/voiceover/Male/go.ogg`
- `assets/audio/voiceover/Male/hurry_up.ogg`, `assets/audio/voiceover/Male/time_over.ogg`
- `assets/audio/voiceover/Male/objective_achieved.ogg`, `assets/audio/voiceover/Male/mission_completed.ogg`, `assets/audio/voiceover/Male/mission_failed.ogg`
- `assets/audio/voiceover/Male/congratulations.ogg`, `assets/audio/voiceover/Male/new_highscore.ogg`, `assets/audio/voiceover/Male/level_up.ogg`
- Countdown: `1.ogg` to `10.ogg`. Never use the `war_*` lines (deny list).

## Excluded from the import

`.gdignore` folders: animal spritesheets and the outline-less animals, emote styles 2–8 and emote spritesheets, foliage and item spritesheets, pirate ships, ship parts, effects and spritesheet (the pirate tilesheet is imported since BI-5), the top-down interior tiles and tilesheet, UI colours Grey, Green, Red and all `Double` variants, the female voice, the jingle sets HIT, SAX and STEEL, and the whole `audio/sfx-digital/` pack (lasers and phasers, kept in `SOURCES.md` per D-7).
