# Asset sources

Every pack below was copied unchanged from the `assets/` folder of the product specification, which holds the downloads from OpenGameArt. All files are CC0 1.0 (public domain). Weapons, zombies and other violent sprites of the packs were left out on purpose before the copy.

`tools/validate_assets.py` reads the table: the first column is the pack folder relative to `assets/`, every file below `assets/` must lie in a listed folder and every row needs a pack name, author, licence and source. Folders that the game does not use carry a `.gdignore` file, so Godot does not import them (see `docs/asset_map.md`).

| Folder | Pack | Author | Licence | Source | Files |
|---|---|---|---|---|---|
| `graphics/pirate-pack/` | pirate-pack | Kenney | CC0 1.0 | https://opengameart.org/content/pirate-pack-190 | 202 |
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
| `ui/fonts/` | kenney-fonts | Kenney | CC0 1.0 | https://opengameart.org/content/kenney-fonts | 11 |
| `audio/sfx-rpg/` | rpg-sounds | Kenney | CC0 1.0 | https://opengameart.org/content/50-rpg-sound-effects | 51 |
| `audio/sfx-ui/` | ui-sounds | Kenney | CC0 1.0 | https://opengameart.org/content/51-ui-sound-effects-buttons-switches-and-clicks | 51 |
| `audio/sfx-digital/` | digital-sounds | Kenney | CC0 1.0 | https://opengameart.org/content/63-digital-sound-effects-lasers-phasers-space-etc | 62 |
| `audio/sfx-interface/` | interface-sounds | Kenney | CC0 1.0 | https://opengameart.org/content/interface-sounds | 100 |
| `audio/jingles/` | jingles | Kenney | CC0 1.0 | https://opengameart.org/content/85-short-music-jingles | 85 |
| `audio/voiceover/` | voiceover | Kenney | CC0 1.0 | https://opengameart.org/content/voiceover-pack-40-lines | 94 |
| `audio/music/` | chiptunes-action | Juhani Junkala | CC0 1.0 | https://opengameart.org/content/5-chiptunes-action | 6 |

The `audio/sfx-digital/` row stays (decision D-7): the pack is present as 62 mp3 files, but the game does not use it and the folder is excluded from the import.
