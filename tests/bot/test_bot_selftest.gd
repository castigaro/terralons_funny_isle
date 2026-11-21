extends TestCase
## The bot harness reports failures instead of hiding them: a broken plan fails as stuck with a message that names
## level, mode, seed and the stuck task; the summary files merge runs by key; the run seeds give distinct schedules.

const BotRun := preload("res://tests/support/bot_run.gd")
const BotPlans := preload("res://tests/support/bot_plans.gd")
const BotReport := preload("res://tests/support/bot_report.gd")
const BotCase := preload("res://tests/support/bot_case.gd")
const SAMPLE_LEVEL := "res://tests/scenes/sample_level.tscn"
const SELFTEST_SUBDIR := "bot_selftest"
const SHORT_STUCK_SECONDS := 3.0
const SHORT_LIMIT_SECONDS := 20.0
const BROKEN_PLAN := {
	"scene": SAMPLE_LEVEL,
	"hold_style": "staged",
	"steps": [{"task": "fx_reach_a", "kinds": ["no_such_kind"], "skip_zone": "", "target": "Actors/Castaway"}],
}


func test_broken_plan_fails_as_stuck_with_reproducible_message() -> void:
	var entry: Dictionary = await BotRun.new().run(self, {"level_id": "selftest_sample", "plan": BROKEN_PLAN,
			"mode": EventScheduler.MODE_SEEDED, "seed": 77, "variant": "plain",
			"stuck_seconds": SHORT_STUCK_SECONDS, "limit_seconds": SHORT_LIMIT_SECONDS})
	check_eq(entry["result"], "fail", "broken plan fails")
	check_eq(entry["reason"], "stuck", "reason")
	check_eq(entry["stuck_task"], "fx_reach_a", "stuck task")
	var line := BotRun.format_failure(entry)
	for part in ["level=selftest_sample", "mode=seeded", "seed=77", "stuck_task=fx_reach_a", "goal=", "carried=",
			"elapsed="]:
		check_has(line, part, "failure line")


func test_format_failure_is_pure() -> void:
	var entry := {"level": "l4_lagoon", "mode": "latest", "seed": 4404, "variant": "hold", "reason": "not_3_stars",
			"stuck_task": "", "goal": "use:Actors/LagoonJetty:hold", "carried": "duck", "elapsed": 196.2,
			"tasks_done": 4, "tasks_total": 4, "time_left": 63.8}
	check_eq(BotRun.format_failure(entry), "BOT FAIL level=l4_lagoon mode=latest seed=4404 variant=hold "
			+ "reason=not_3_stars stuck_task= goal=use:Actors/LagoonJetty:hold carried=duck elapsed=196.2s tasks=4/4 "
			+ "time_left=63.8", "line")


func test_seeds_give_distinct_schedules() -> void:
	for level_id in BotPlans.level_ids():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BotPlans.plan(level_id)["json"]))
		var seeds: Array = BotCase.seeds_for(level_id)
		check_eq(seeds.size(), 3, "%s has three run seeds" % level_id)
		var schedules: Array = []
		for s in seeds:
			var starts: Array = []
			for entry in EventScheduler.build(data["events"], int(s)):
				starts.append([entry["id"], snappedf(float(entry["start"]), 0.001)])
			check_false(schedules.has(starts), "%s seed %d gives a schedule of its own" % [level_id, s])
			schedules.append(starts)


func test_report_upsert_keeps_one_entry_per_key() -> void:
	var base := BotReport.report_dir()
	if base == "":
		print("report dir not configured – upsert check skipped")
		return
	var dir := base.get_base_dir() + "/" + SELFTEST_SUBDIR
	var a := {"variant": "plain", "mode": "seeded", "seed": 1, "result": "pass"}
	var a2 := {"variant": "plain", "mode": "seeded", "seed": 1, "result": "fail"}
	var b := {"variant": "hold", "mode": "latest", "seed": 1, "result": "pass"}
	var path := BotReport.upsert("selftest", a, dir)
	BotReport.upsert("selftest", a2, dir)
	var plain := _runs_of(path, "plain")
	check_eq(plain.size(), 1, "same key replaces")
	check_eq(plain[0]["result"] if not plain.is_empty() else "", "fail", "newest entry kept")
	check_eq(plain[0]["seed"] if not plain.is_empty() else 0, 1, "seed stays an integer")
	BotReport.upsert("selftest", b, dir)
	check_eq(_runs_of(path, "plain").size() + _runs_of(path, "hold").size(), 2, "different key appends")


func _runs_of(path: String, variant: String) -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (data["runs"] as Array).filter(func(r: Dictionary) -> bool: return r["variant"] == variant)


func test_report_dir_refuses_project_and_user_folders() -> void:
	check_false(BotReport.is_allowed_dir("res://bot"), "res:// refused")
	check_false(BotReport.is_allowed_dir("user://bot"), "user:// refused")
	check_false(BotReport.is_allowed_dir(ProjectSettings.globalize_path("res://") + "tests/bot_out"),
			"project folder refused")
	check_eq(BotReport.upsert("selftest", {}, "res://bot_out"), "", "no write below res://")
