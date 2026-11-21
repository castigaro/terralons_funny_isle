# Audio

The `Audio` autoload (`scripts/autoload/audio.gd`, last in the autoload list) plays music, sound effects,
jingles and announcer lines. It listens to the EventBus; gameplay code never calls it for action sounds.

## Buses

`default_bus_layout.tres`: `Master`, `Music` (sends to Master) and `Effects` (sends to Master). Sound effects,
jingles and the announcer play on `Effects`. `Audio.set_volume("music" | "effects", linear)` takes 0..1
(clamped); 0 mutes the bus, other values set `linear_to_db(v)`. `Audio.get_volume(bus)` returns the stored value.

## data/audio.json (format_version 1)

- `music`: id -> WAV path. Ids: `title` (title and level select), `level_1`..`level_3`, `ending` (credits).
  Level files name their track in `music`; level 4 uses `level_2`, level 5 uses `level_3` (D-2).
  `tools/validate_levels.py` and `LevelDef` (with `music_ids` in the context) reject unknown ids.
- `sfx`: sound id -> `{files, volume_db, pitch?}`; one file is picked per play, with seeded pitch jitter.
- `pitch`: animal kind -> pitch multiplier, so each animal sounds distinct.
- `signals`: EventBus signal -> `{default, <refinement>: sfx id, jingle?, announcer?}`. The first String argument
  that is a key of the entry refines the sound (surface such as `water`, kind, reason, event type);
  otherwise `default` plays. `event_triggered` is refined by the event type read from the level file.
- `jingles`: `task_done`, `won`, `lost`. `announcer`: line id -> `{file, caption}` (English voice in both
  languages, translated caption, D-1).
- `ignored`: signals without sound, each with a reason. A test fails when an EventBus signal is neither
  mapped nor ignored.

Only files outside `.gdignore` folders and without deny-list tokens may be used (tests check this).

## Tuning: data/balance/audio.json

Cooldown and voice limit per sound (`per_sound`, defaults `default_cooldown_seconds`, `default_voice_limit`),
pitch jitter, jingle duck depth, attack and release, music crossfade, announcer gap and queue length, caption
size, position and timing, default volume. Dropped sounds are never queued.

## Behaviour

- Music crossfades between two players on `Music` (process mode ALWAYS, keeps playing in pause);
  `play_music` with the current id does nothing, an unknown id keeps the track. On `level_started` the track
  of `data/levels/<id>.json` starts; screens call `Audio.play_music("title" | "ending")`.
- Jingles: requests of one frame are merged – `won`/`lost` replace `task_done`. While a jingle plays the
  music player (not the bus) is lowered by `jingle_duck_db`, then released linearly.
- Announcer: a single-voice queue; a line starts only after the previous one ended plus the gap. Each start
  emits `EventBus.announcer_line(line_id, caption_key, seconds)`; the caption
  (`scenes/audio/announcer_caption.tscn`, child of the autoload) shows the translated text and follows a
  language switch. A repeated `level_started` (restart) clears the queue and says "Go!".
- A missing file, an unknown id or an unmapped signal only warns once (`push_warning`), never errors.

## Ownership

BI-9 owns buses, the `Audio` API, `data/audio.json`, the announcer and its caption. Settings sliders and
their persistence, title/level select/credits screens and menu click sounds belong to the menu item and call
`Audio.set_volume` and `Audio.play_music`.

## Adding a sound

1. Pick a file from an imported pack (see `docs/asset_map.md`), add it to an `sfx` entry or create a new one.
2. Map the signal (or a refinement key) to the sound id in `signals`; a new EventBus signal without sound goes
   to `ignored` with a reason.
3. Optional: add `per_sound` limits in `data/balance/audio.json`.
4. Run `python tools/run_tests.py`.

## Tests

`tests/audio/` checks buses and volumes, loop flags, music allocation, the map against the EventBus and the
data, throttling, the announcer queue, ducking, captions and robustness. Tests set `Audio.manual_clock` and call
`Audio.advance(delta)` instead of waiting for real playback; `Audio.sfx_requests()` lists the sound ids requested
via `play_sfx` since the last `level_started` (also those the throttle dropped, capped at 64); the runner waits briefly in real time before it quits
so the mixer releases stopped playbacks.
