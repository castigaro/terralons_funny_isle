extends TestCase
## Campaign: the real five-level list, the fixture list, availability, navigation and broken files.

const REAL_IDS := ["beach_camp", "farm_meadow", "jungle", "lagoon", "volcano_cliffs"]


func test_real_campaign() -> void:
	var res := Campaign.load_file("res://data/campaign.json")
	check_true(res["ok"], "loads: %s" % str(res["errors"]))
	var c: Campaign = res["campaign"]
	check_eq(c.ids(), REAL_IDS, "order and naming")
	for i in REAL_IDS.size():
		var e := c.entry(REAL_IDS[i])
		check_eq(e["number"], i + 1, "number")
		check_eq(e["scene"], Campaign.SCENE_DIR + REAL_IDS[i] + ".tscn", "scene path")
		check_eq(e["json"], Campaign.JSON_DIR + REAL_IDS[i] + ".json", "json path")
		check_eq(e["available"], ResourceLoader.exists(e["scene"]), "available follows the scene")


func test_fixture_campaign_and_navigation() -> void:
	var c: Campaign = Campaign.load_file("res://tests/fixtures/flow/campaign.json")["campaign"]
	check_eq(c.size(), 3, "three entries")
	check_true(c.entry("valid_sample_level")["available"], "sample available")
	check_false(c.entry("missing_level")["available"], "missing scene unavailable")
	check_eq(c.entry("valid_sample_level")["title_key"], "fixture.sample_title", "title key from JSON")
	check_eq(c.entry("missing_level")["title_key"], "", "no JSON, no title")
	check_eq(c.next_id("valid_sample_level"), "valid_small_level", "next")
	check_eq(c.next_id("missing_level"), "", "after the last")
	check_true(c.is_last("missing_level"), "is_last")
	check_false(c.is_last("valid_small_level"), "not last")
	check_eq(c.index_of("valid_small_level"), 1, "index")
	check_eq(c.index_of("zzz"), -1, "unknown index")
	check_eq(c.entry("zzz"), {}, "unknown entry")
	check_eq(c.first_id(), "valid_sample_level", "first")


func test_broken_campaign_files() -> void:
	var broken := Campaign.load_file("res://tests/fixtures/flow/campaign_broken.json")
	check_false(broken["ok"], "errors reported")
	check_eq((broken["campaign"] as Campaign).ids(), ["ok_one"], "valid entry kept once")
	check_true(broken["errors"].size() >= 3, "bad id, non-object, duplicate: %s" % str(broken["errors"]))
	var missing := Campaign.load_file("res://tests/fixtures/flow/" + "does_not_exist.json")
	check_false(missing["ok"], "missing file")
	check_eq((missing["campaign"] as Campaign).size(), 0, "empty campaign, no crash")
	check_false(Campaign.parse([], "x")["ok"], "array top level")
