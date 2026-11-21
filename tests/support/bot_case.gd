extends TestCase
## Base for the bot playthrough tests: runs one BotRun, writes its entry to the per-level summary and checks it.

const BotRun := preload("res://tests/support/bot_run.gd")
const BotPlans := preload("res://tests/support/bot_plans.gd")
const BotReport := preload("res://tests/support/bot_report.gd")
const SEEDS_FILE := "res://tests/fixtures/bot/seeds.json"


## The run seeds of a level: its own level seed followed by the extra seeds of the fixture.
static func seeds_for(level_id: String) -> Array:
	var out: Array = [BotPlans.level_seed(level_id)]
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEEDS_FILE))
	if data is Dictionary:
		for s in (data as Dictionary).get(level_id, []):
			out.append(int(s))
	return out


## Runs, reports and returns one entry; opts are passed on to BotRun.run.
func play(level_id: String, variant: String, mode: String, run_seed: int, opts: Dictionary = {}) -> Dictionary:
	var all := opts.duplicate()
	all["level_id"] = level_id
	all["variant"] = variant
	all["mode"] = mode
	all["seed"] = run_seed
	var entry: Dictionary = await BotRun.new().run(self, all)
	BotReport.upsert(level_id, entry)
	print("BOT %s %s %s seed=%d -> %s %s tasks=%d/%d elapsed=%.1f time_left=%.1f stars=%d throws=%d respawns=%d" % [
			level_id, variant, mode, run_seed, entry["result"], entry["reason"], entry["tasks_done"],
			entry["tasks_total"], entry["elapsed"], entry["time_left"], entry["stars"], entry["throws"],
			entry["respawns"]])
	return entry


func expect_pass(entry: Dictionary) -> void:
	check(entry["result"] == "pass", BotRun.format_failure(entry))


## A plain seeded run with the seed at index of seeds_for (0 = level seed).
func play_seeded(level_id: String, index: int) -> void:
	expect_pass(await play(level_id, "plain", EventScheduler.MODE_SEEDED, seeds_for(level_id)[index]))


## A worst-case run: every event at the earliest or latest end of its window, the final unit held back.
func play_worst(level_id: String, mode: String) -> void:
	expect_pass(await play(level_id, "hold", mode, BotPlans.level_seed(level_id), {"hold": true}))


## Failure injection: every task entity is thrown into the water once, the level is still won with every task done.
func play_injection(level_id: String) -> void:
	var entry: Dictionary = await play(level_id, "inject", EventScheduler.MODE_SEEDED, BotPlans.level_seed(level_id),
			{"inject": true})
	expect_pass(entry)
	check(int(entry["throws"]) > 0, "injection threw task entities: %s" % BotRun.format_failure(entry))
