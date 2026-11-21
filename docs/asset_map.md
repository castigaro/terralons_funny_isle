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

Never use the knife (`genericItem_color_134`), the axe (`_020`), saws or other sharp tools as carryable items.

## Tiles and props

Island tiles 128×128 px from the pirate pack (`assets/graphics/pirate-pack/PNG/Retina/Tiles/`, the pack's tilesheet says 64 px at 1×):

- Level TileMapLayers use the retina tilesheet `assets/graphics/pirate-pack/Tilesheet/tiles_sheet@2.png` (16×6 tiles of 128 px) through `scenes/levels/island_tileset.tres` (BI-5): shore edges and outer corners at atlas (0–2, 0–2), rocks at (0–2, 3–4), plain sand at (3–4, 4), full grass at (6–7, 1–2). The water backdrop uses the standalone `assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_73.png`, because shader distortion on an atlas tile bleeds into its neighbours.

- Sand island with shoreline: `tile_01`–`tile_03`, `tile_17`–`tile_19`, `tile_33`–`tile_35` (for example `assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_18.png`)
- Grass on sand: `tile_06`–`tile_09`, `tile_22`–`tile_25`, `tile_38`–`tile_41`, `tile_54`–`tile_57`; full grass `assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_23.png`
- Water (animate by UV scroll or shader): `assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_73.png`
- Stone ground (volcano cliffs): `tile_10`–`tile_12`, `tile_26`–`tile_28`, `tile_42`–`tile_44`, `tile_58`, `tile_59`, `tile_74`, `tile_75`
- Rocks: `assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_49.png`, `tile_50`, `tile_51`, mossy `tile_65`–`tile_67`
- Sand details and small plants: `tile_68`, `tile_69`, `tile_70`–`tile_72`, `tile_87`, `tile_88`
- Props: wrecked boat `assets/graphics/pirate-pack/PNG/Retina/Tiles/tile_81.png`, wooden bridge `tile_60` and `tile_76`
- Ships, ship parts (cannons, skull sails) and the explosion effects are excluded.

Foliage (`assets/graphics/foliage/PNG/Retina/`), sway by a shader:

- Trees: `assets/graphics/foliage/PNG/Retina/foliagePack_008.png`, `foliagePack_007`, `foliagePack_009`–`foliagePack_011`; autumn trees `foliagePack_013`–`foliagePack_018` for the jungle and volcano levels
- Bushes: `assets/graphics/foliage/PNG/Retina/foliagePack_050.png`, `foliagePack_051`–`foliagePack_053`
- Flowers: `assets/graphics/foliage/PNG/Retina/foliagePack_001.png`, `foliagePack_002`–`foliagePack_004`
- Grass: `foliagePack_019`–`foliagePack_022`; boulders `foliagePack_054`–`foliagePack_056`
- White grass tufts for tinting and swaying (`assets/graphics/foliage-sprites/PNG/Shaded/`): `assets/graphics/foliage-sprites/PNG/Shaded/sprite_0052.png` to `sprite_0069`

## UI

- Buttons (blue, with depth): `assets/ui/ui-pack/PNG/Blue/Default/button_rectangle_depth_gradient.png`, `assets/ui/ui-pack/PNG/Blue/Default/button_round_depth_gradient.png`, `assets/ui/ui-pack/PNG/Blue/Default/button_square_depth_gradient.png`
- Volume sliders: `assets/ui/ui-pack/PNG/Blue/Default/slide_horizontal_color.png`, `assets/ui/ui-pack/PNG/Blue/Default/slide_hangle.png`
- Toggle: `assets/ui/ui-pack/PNG/Blue/Default/check_square_color_checkmark.png`, `assets/ui/ui-pack/PNG/Blue/Default/check_square_grey.png`
- Task done and failed: `assets/ui/ui-pack/PNG/Blue/Default/icon_checkmark.png`, `assets/ui/ui-pack/PNG/Blue/Default/icon_cross.png`
- Stars (result screen, thresholds): `assets/ui/ui-pack/PNG/Yellow/Default/star.png`, `assets/ui/ui-pack/PNG/Yellow/Default/star_outline.png`
- Icons: play `assets/ui/ui-pack/PNG/Extra/Default/icon_play_light.png`, retry `assets/ui/ui-pack/PNG/Extra/Default/icon_repeat_light.png`, back `assets/ui/ui-pack/PNG/Blue/Default/arrow_basic_w.png`
- Emote bubbles (Style 1, `assets/graphics/emotes/PNG/Vector/Style 1/`): `assets/graphics/emotes/PNG/Vector/Style 1/emote_stars.png` (dizzy), `emote_exclamation`, `emote_question`, `emote_anger`, `emote_heart`, `emote_laugh`, `emote_swirl`, `emote_faceHappy`, `emote_faceSad`
- The colours Grey, Green and Red and all `Double` variants are excluded.

## Fonts

- Headings, timer and buttons: `assets/ui/ui-pack/Font/Kenney Future.ttf`
- Body text, hints and prompts: `assets/ui/ui-pack/Font/Kenney Future Narrow.ttf`
- Both cover ä, ö, ü, Ä, Ö, Ü and ß but have no en dash glyph: player-facing texts use a hyphen or a fallback font. The pixel fonts in `assets/ui/fonts/` stay imported but are not part of the polished look.

## Particles and effects

- Smoke puffs (dash, landing, BONK): `assets/graphics/smoke/PNG/White puff/whitePuff00.png` to `whitePuff24`
- Fart cloud (pig in mud, comic relief): `assets/graphics/smoke/PNG/Fart/fart00.png` to `fart08`
- Flash (task done, grab): `assets/graphics/smoke/PNG/Flash/flash00.png` to `flash07`
- Splats (mud, splash, thrown items; tint per material): `assets/graphics/splats/PNG/Default (256px)/splat00.png` to `splat35`
- Stars and sparkles (dizzy stars, task done, 3-star result): `assets/graphics/particles/PNG/star_01.png` to `star_09`, `assets/graphics/particles/PNG/spark_01.png` to `spark_07`
- Dust and speed lines: `assets/graphics/particles/PNG/dirt_01.png` to `dirt_03`, `assets/graphics/particles/PNG/trace_01.png` to `trace_07`
- Water drops and rain: `assets/graphics/particles/PNG/circle_01.png` to `circle_05`
- Never use `muzzle_*`, `scorch_*`, `slash_*` or `fire_*` (deny list or scary).

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
- Menus: `assets/audio/sfx-ui/click1.wav`, `assets/audio/sfx-ui/rollover1.wav`, `assets/audio/sfx-ui/switch1.wav`
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
