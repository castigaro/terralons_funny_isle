# Asset sources

Every pack below was copied unchanged from the `assets/` folder of the product specification, which holds the downloads from OpenGameArt. All files are CC0 1.0 (public domain). Weapons, zombies and other violent sprites of the packs were left out on purpose before the copy.

`tools/validate_assets.py` reads the table: the first column is the pack folder relative to `assets/`, every file below `assets/` must lie in a listed folder and every row needs a pack name, author, licence and source. Folders that the game does not use carry a `.gdignore` file, so Godot does not import them (see `docs/asset_map.md`).

| Folder | Pack | Author | Licence | Source | Files |
|---|---|---|---|---|---|
| `graphics/pirate-pack/` | pirate-pack | Kenney | CC0 1.0 | https://opengameart.org/content/pirate-pack-190 | 202 |
| `graphics/pirate-pack-derived/` | Pirate Pack – derived tiles | Kenney (derived by `tools/derive_grass_edges.gd`, `tools/derive_sandcastle.gd` and `tools/derive_zone_marker.gd`) | CC0 1.0 | https://opengameart.org/content/pirate-pack-190 (zone marker: https://opengameart.org/content/ui-pack) | 7 |
| `graphics/theme-derived/` | Theme props – derived | Kenney (derived by `tools/derive_theme_props.gd`) | CC0 1.0 | https://opengameart.org/content/topdown-shooter, https://opengameart.org/content/pirate-pack-190 and https://opengameart.org/content/foliage-sprites | 21 |
| `graphics/volcano-derived/` | Volcano art – derived | Kenney (derived by `tools/derive_volcano_art.gd`) | CC0 1.0 | https://opengameart.org/content/particle-pack-80-sprites and https://opengameart.org/content/pirate-pack-190 | 2 |
| `graphics/topdown-characters/` | topdown-shooter | Kenney | CC0 1.0 | https://opengameart.org/content/topdown-shooter | 537 |
| `graphics/animals/` | animal-pack-redux | Kenney | CC0 1.0 | https://opengameart.org/content/animal-pack-redux | 68 |
| `graphics/foliage/` | foliage-pack | Kenney | CC0 1.0 | https://opengameart.org/content/foliage-pack-100x | 66 |
| `graphics/foliage-sprites/` | foliage-sprites | Kenney | CC0 1.0 | https://opengameart.org/content/foliage-sprites | 50 |
| `graphics/items/` | generic-items | Kenney | CC0 1.0 | https://opengameart.org/content/generic-items | 167 |
| `graphics/particles/` | particle-pack | Kenney | CC0 1.0 | https://opengameart.org/content/particle-pack-80-sprites | 80 |
| `graphics/smoke/` | smoke-particles | Kenney | CC0 1.0 | https://opengameart.org/content/smoke-particle-assets | 43 |
| `graphics/splats/` | splat-pack | Kenney | CC0 1.0 | https://opengameart.org/content/splat-pack | 36 |
| `graphics/emotes/` | emotes-pack | Kenney | CC0 1.0 | https://opengameart.org/content/emotes-pack | 272 |
| `ui/ui-pack/` | ui-pack | Kenney | CC0 1.0 | https://opengameart.org/content/ui-pack | 870 |
| `ui/fonts-derived/` | Kenney Future – derived glyphs | Kenney (derived by `tools/derive_font.py`) | CC0 1.0 | https://opengameart.org/content/ui-pack | 1 |
| `ui/fonts/` | kenney-fonts | Kenney | CC0 1.0 | https://opengameart.org/content/kenney-fonts | 11 |
| `audio/sfx-rpg/` | rpg-sounds | Kenney | CC0 1.0 | https://opengameart.org/content/50-rpg-sound-effects | 51 |
| `audio/sfx-ui/` | ui-sounds | Kenney | CC0 1.0 | https://opengameart.org/content/51-ui-sound-effects-buttons-switches-and-clicks | 51 |
| `audio/sfx-digital/` | digital-sounds | Kenney | CC0 1.0 | https://opengameart.org/content/63-digital-sound-effects-lasers-phasers-space-etc | 62 |
| `audio/sfx-interface/` | interface-sounds | Kenney | CC0 1.0 | https://opengameart.org/content/interface-sounds | 100 |
| `audio/jingles/` | jingles | Kenney | CC0 1.0 | https://opengameart.org/content/85-short-music-jingles | 85 |
| `audio/voiceover/` | voiceover | Kenney | CC0 1.0 | https://opengameart.org/content/voiceover-pack-40-lines | 94 |
| `audio/music/` | chiptunes-action | Juhani Junkala | CC0 1.0 | https://opengameart.org/content/5-chiptunes-action | 6 |

The `graphics/pirate-pack-derived/`, `graphics/theme-derived/`, `graphics/volcano-derived/` and `ui/fonts-derived/` rows are the only folders not copied unchanged. `tools/derive_grass_edges.gd` builds the textured grass fill variants (tinted with the mean colour of the pack's grass tile), the grass-to-sand transitions and the shore inner corners from tiles of the pirate pack; `tools/derive_sandcastle.gd` recolours the pack's tower tiles (`tile_13`, `tile_14`) and the sand specks of `tile_69` into the five sandcastle frames; `tools/derive_zone_marker.gd` redraws the outer line of the UI pack's `button_round_line.png` as the double-stroke zone marker nine-patch. `tools/derive_theme_props.gd` builds the set dressing of Beach Camp and Farm Meadow (fence runs, barn, tent, crate stack, barrels, campfire, driftwood and a ploughed field) from planks, crates, rails, rocks, sticks and the dirt tile of the topdown-shooter tilesheet a plain sail and plank of the pirate pack ship parts, and downscales four white grass tufts of the foliage sprites for the beach. For the Lagoon it builds plank dock runs on posts and two thatched stilt huts from the tilesheet planks, and three boats from the pirate pack: two intact hulls (`hullLarge (1)`, `hullSmall (1)`) with the plain `sailLarge (8)` and the plain furled `sailSmall (4)`, and the rowing dinghy `Ships/dinghyLarge1` (Lagoon props derived from Pirate Pack and Topdown Shooter, CC0); no crew, cannon, flag or skull part is used. The tilesheet, ship part and ship folders stay excluded from the import. `tools/derive_volcano_art.gd` stamps the dirt and smoke shapes of the particle pack into a seamless basalt detail texture for the Volcano Cliffs ground shader and extrudes the alpha of the pirate pack shore tiles into the cliff face atlas, coloured from the palette. `Kenney Future Fixed.ttf` is Kenney Future of the UI pack with diagonal X and x, a slashed %, sharp s drawn as SS and the en dash mapped to the hyphen, rebuilt by `tools/derive_font.py`. All stay CC0.

The `audio/sfx-digital/` row stays (decision D-7): the pack is present as 62 mp3 files, but the game does not use it and the folder is excluded from the import.
