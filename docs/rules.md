# Rules engine: levels, tasks, events, timer and stars

The rules engine in `scripts/rules/` is pure GDScript (`RefCounted` classes, no scenes, no physics, no persistence). Level scenes feed it a world snapshot every physics tick; it decides task progress, win, loss and stars and announces everything on the EventBus. Levels are tuned by editing JSON only.

| File | Class | Role |
|---|---|---|
| `level_def.gd` | `LevelDef` | Parses and validates a level JSON file (same rules as `tools/validate_levels.py`). |
| `conditions.gd` | `Conditions` | Pure evaluation of the generic conditions against a snapshot index. |
| `event_scheduler.gd` | `EventScheduler` | Seeded event schedule (start and end times). |
| `level_timer.gd` | `LevelTimer` | Countdown that only moves when advanced. |
| `stars.gd` | `Stars` | Pure star rating. |
| `level_session.gd` | `LevelSession` | The only writer of rules state; state machine and signals. |

## Balance: `data/balance/rules.json`

| Key | Default | Meaning |
|---|---|---|
| `timer_min_seconds`, `timer_max_seconds` | 180, 300 | Allowed level timer range. |
| `tasks_min`, `tasks_max` | 3, 5 | Tasks per level. |
| `events_min` | 2 | Events per level. |
| `timer_warning_seconds` | 10 | `timer_warning` fires once when the remaining time first drops to this value. |
| `three_star_time_share` | 0.25 | Share of the timer that must be left for 3 stars (D-4); a level may override it. |
| `auto_finish_when_all_done` | true | The level ends as won as soon as every task is done. |

## Level schema: `data/levels/<id>.json`

```json
{
	"format_version": 1,
	"id": "beach_chaos",
	"title_key": "levels.beach_chaos.title",
	"theme": "palm_beach",
	"music": "tune_beach",
	"seed": 4242,
	"timer_seconds": 240,
	"three_star_share": 0.3,
	"tasks": [
		{"id": "hens_in_coop", "required": true,
		 "conditions": [{"type": "in_zone", "entity": "chicken", "zone": "coop", "count": 2}],
		 "hint_key": "levels.beach_chaos.hens_in_coop.hint", "fail_key": "levels.beach_chaos.hens_in_coop.fail"},
		{"id": "coconut_run", "required": false,
		 "conditions": [{"type": "delivered_to", "entity": "coconut", "target": "monkey", "count": 3}],
		 "modifiers": [{"type": "before_event", "event": "big_wave"}],
		 "hint_key": "...", "fail_key": "..."}
	],
	"events": [
		{"id": "big_wave", "type": "wave_wash", "window": [90, 150], "duration_s": 8, "params": {"strength": 1.5}}
	]
}
```

- `id` equals the file name stem. All ids match `^[a-z][a-z0-9_]*$` and are unique across the level, its tasks and its events. `player`, condition type names and event type names are reserved and cannot be used as ids.
- `timer_seconds` is an integer within the balance range. `seed` is an integer. `three_star_share` is optional and must be strictly between 0 and 1.
- There are 3–5 tasks, with at least one required and at least one optional task (A1). Each task has `hint_key` (R-22) and `fail_key` (A9, the reason cue). Both keys must exist with non-empty EN and DE text. Real level texts go to `i18n/levels.csv` (`levels.<level>.<task>.hint|fail`).
- There are at least 2 events. Each has a known `type`, a `window` `[min_s, max_s]` with `0 <= min <= max < timer_seconds`, `duration_s > 0`, and `params` that match the type's parameter schema.
- Unknown fields are rejected everywhere.

### Conditions and modifiers

A task is done when all of its `conditions` and all of its `modifiers` hold at the same tick. Modifiers use the same grammar plus `before_event`.

| Type | Fields | Holds when |
|---|---|---|
| `in_zone` | `entity`, `zone`, `count`=1 | `entity` is `player`: the player is in `zone`. Otherwise at least `count` free (not carried) entities of that kind are in `zone`. |
| `held` | `entity` | The player carries an entity of that kind. |
| `worn` | `item`, `wearer`=`player` | The player wears `item`, or an entity of kind `item` has `worn_by == wearer`. |
| `delivered_to` | `entity`, `target`, `count`=1 | The cumulative deliveries reported via `report_delivery(entity, target)` reach `count`. |
| `count_reached` | `counter`, `count` | The cumulative `report_count(counter, n)` total reaches `count`. |
| `before_time` | `seconds` (0 < s ≤ timer) | Elapsed gameplay time is ≤ `seconds`. It cannot be the only condition. |
| `before_event` (modifier only) | `event` (an event id of this level) | The event has not triggered yet. It is allowed only on optional tasks. |

- **Progress target:** the `count` of the single condition with `count > 1`, otherwise 1. More than one such condition is rejected as an ambiguous target.
- **Progress display:** progress is shown clamped to `target − 1` until the task is done, so `n/n` always means done.
- **Done is latched:** a done task stays done even when the world changes later.
- **Missed tasks:** a `before_time` or `before_event` that no longer holds marks the task as missed. A missed task can never complete and counts as open.

## Event catalogue: `data/events.json`

`{"format_version": 1, "types": {<type>: {"params": {<name>: {"type": "string|int|float|bool", "required": bool}}, "effects": [...]}}}`

| Type | Effects |
|---|---|
| `parrot_steal_hat` | `take_worn` |
| `goat_stampede` (param `lane` required) | `relocate_entities`, `stun_player` |
| `coconut_throw` | `stun_player`, `take_held` |
| `rain_panic` | `panic_animals`, `relocate_entities` |
| `wave_wash` | `relocate_entities` |
| `mud_trail` | `slippery_ground` |

The effects vocabulary is declarative. Level scenes apply effects to the world when they receive `event_triggered(event_id)`, and stop them on `event_ended(event_id)`. Events never get a session reference, so they cannot end a level, change the timer or undo a completed task (A6, R-20). Effects only move items and animals; deliveries and counters are cumulative and never drop.

## World snapshot (built by the level scene each physics tick, BI-4/BI-5)

```
{
  "player":   {"zones": [String], "held": String kind or "", "worn": String kind or "", "stunned": bool (optional)},
  "entities": [{"uid": String, "kind": String, "zones": [String], "held_by": "" | "player", "worn_by": "" | kind}]
}
```

The `entities` list comes from `EntityRegistry.snapshot_entities()` (`docs/entities.md`). Deliveries and counters are events rather than states, so scenes report them with `report_delivery(entity, target)` and `report_count(counter, n)`.

## LevelSession

```
var def: LevelDef = LevelDef.load_file(path, LevelDef.make_context(Balance.get_section("rules"),
		LevelDef.load_event_types()["types"], I18n.parse_dir("res://i18n")["messages"]))["def"]
var session := LevelSession.new(def, EventBus, Balance.get_section("rules"), {"schedule_mode": "seeded"})
session.start()                      # after the intro
session.tick(delta, snapshot)        # every physics frame
```

- **Options:** `seed_override` (int) and `schedule_mode` (`seeded`, `earliest`, `latest`). The bot and the worst-case tests use `earliest` and `latest`.
- **States:** `READY → RUNNING ⇄ PAUSED`, `RUNNING → REQUIRED_DONE ⇄ PAUSED`, then `REQUIRED_DONE → WON` or `RUNNING → LOST`. `WON` and `LOST` are final until `restart()`.
- **API:** `start`, `tick`, `pause`, `resume`, `finish() -> bool` (only in `REQUIRED_DONE`, otherwise no side effects), `restart`, `report_delivery`, `report_count` (n ≤ 0 is ignored), `get_state`, `task_progress`, `result`, `three_star_time`, `schedule`, `time_left`, `elapsed`, `state_dict`, `level_id`. There are no setters for the timer or task state.

### Tick order

Ticks are ignored unless the state is `RUNNING` or `REQUIRED_DONE`. That is how the timer stops during pause and menus (R-26).

1. **Timer:** `elapsed += delta`. Emits `level_timer_tick(seconds_left)` when the whole second changes, and `timer_warning(level_id, seconds_left)` once per attempt.
2. **Events:** every schedule point with time ≤ elapsed fires in time order (`event_warning`, `event_triggered`, `event_ended`). `event_warning(event_id, event_type, seconds_until)` comes `event_warning_lead_seconds` (rules.json) before the start, clamped at 0. At equal times a warning comes before a trigger and a trigger before an end, then data order applies. Triggering depends on accumulated time only, so it is frame-rate independent.
3. **Tasks:** emits `task_progress(level_id, task_id, current, target)` on change, then `task_completed(level_id, task_id)`. `task_completed` is the "task done" signal.
4. **Win and loss:**
   - When all required tasks are done, `all_required_done(level_id)` fires and the state becomes `REQUIRED_DONE`. Play continues (D-3).
   - When all tasks are done and auto finish is on, the level is won with `level_won(level_id, stars)`.
   - If the timer expires in `REQUIRED_DONE`, the level is won (time left 0, so at most 2 stars).
   - If the timer expires in `RUNNING`, the level is lost with `level_lost(level_id, open_required_ids)` in data order.
   - **Tie rule:** a task completed in the same tick in which the time runs out counts as completed.

`level_started`, `all_required_done`, `timer_warning`, `level_won` and `level_lost` fire at most once per attempt.

## Stars (D-4, A1)

`Stars.compute(required_done, all_done, time_left, time_total, share)` returns:

- 0 when a required task is open;
- 1 when only the required tasks are done;
- 2 when all tasks are done;
- 3 when all tasks are done and `time_left >= share × time_total`, with a 1e-6 tolerance so that exactly 25 % counts.

`share` is the level's `three_star_share`, otherwise `three_star_time_share` from balance.

## Determinism and assumptions

- **Seeded schedule:** `SeededRng(seed)` draws exactly one `randf_range(min, max)` per event in data order, so appending an event never shifts the earlier start times. Every attempt and every restart replays the same schedule (fairness for replays and 3-star runs, A2, R-19).
- **Restart:** `restart()` rebuilds tasks, counters, timer, flags and schedule. `state_dict()` then equals that of a fresh session.
- **`before_event` and missed tasks:** `before_event` is forbidden on required tasks, so an event can never cause a loss. A missed optional task stays open.
- **Same-tick events:** an event that triggers in the same tick as a task completion is processed first, because events run before tasks.

## Validation

```
python tools/validate_levels.py [--root DIR] [--path FILE] [--i18n-dir DIR ...]
```

The validator checks `data/events.json` and every `data/levels/*.json`, or a single file with `--path`. Entity names in conditions (`in_zone`, `held` and `delivered_to` entity, `worn` item and wearer) must be animal or item kinds from `data/animals.json` or `data/items.json`, except `player`; `delivered_to` targets are use-target kinds and are not checked. `LevelDef.make_context` takes the known kinds as an optional fourth argument (`EntityDefs.kinds()`); without them the names are not checked. It prints one line per error as `<file>: <field path>: <message>` and exits with 1 on any error. A missing or empty levels folder is valid. `run_tests.py` runs it with every validator.

Test fixtures live in `tests/fixtures/levels/` (`valid_*` must pass, `invalid_*` must fail). Their texts are in `tests/fixtures/levels/i18n/fixture.csv`, a separate catalogue with a committed `importer="keep"` import file, so that test keys never enter the product catalogue. `tests/rules/test_level_def.gd` asserts that `LevelDef` reaches the same verdict on every fixture.
