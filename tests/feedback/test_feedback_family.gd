extends "res://tests/support/feedback_case.gd"
## Family-friendly effects (AC5): splats are mud, water or sand and never red, no deny-listed asset, flashes are
## soft (alpha <= 0.4) and rate limited to at most 3 per second (WCAG 2.3.1).

const DENY_PATH := "res://data/assets/deny_list.json"
const MAX_FLASH_ALPHA := 0.4
const MAX_FLASHES_PER_SECOND := 3


func _deny_tokens() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(DENY_PATH))["tokens"]


func _asset_paths(entry: Dictionary) -> Array:
	var out: Array = []
	if entry.has("asset"):
		out.append(entry["asset"])
	if entry.has("frames"):
		for i in int(entry.get("frame_count", 1)):
			out.append(String(entry["frames"]) % i)
	return out


func test_splats_use_family_materials() -> void:
	make_director()
	var found := 0
	for entry in director.map.all_entries():
		if entry["effect"] == "splat":
			found += 1
			check(entry.get("material", "") in ["mud", "water", "sand"], "splat material %s" % entry.get("material"))
	check(found > 0, "splats mapped")
	check_eq(director.map.materials.keys().size(), 3, "exactly three materials")
	for name in director.map.materials:
		var c: Color = director.map.materials[name]
		check_false(c.r >= 0.55 and c.r > c.g * 1.6 and c.r > c.b * 1.6, "%s colour is not red-dominant" % name)


func test_no_deny_listed_asset() -> void:
	make_director()
	var tokens := _deny_tokens()
	for entry in director.map.all_entries():
		for path: String in _asset_paths(entry):
			check(ResourceLoader.exists(path), "%s exists" % path)
			var parts := path.get_file().get_basename().to_lower().replace("-", "_").replace(" ", "_").split("_")
			for token in tokens:
				check_false(parts.has(token), "%s contains deny token %s" % [path, token])


func test_flash_soft_and_rate_limited() -> void:
	make_director()
	for key in director.strengths.sub("strengths")["flash"]:
		check(director.effective_flash_alpha(key) <= MAX_FLASH_ALPHA, "flash %s alpha" % key)
	check(director.strengths.num("flash_min_interval_ms") >= 1000.0 / MAX_FLASHES_PER_SECOND,
			"interval allows at most 3 flashes per second")
	var before := director.played("flash")
	for i in 10:
		emit("object_used", ["bucket", "sandcastle"])
		await frames(6)
	var flashes := director.played("flash") - before
	check(flashes >= 1, "flashes shown")
	check(flashes <= MAX_FLASHES_PER_SECOND, "%d flashes in one second" % flashes)


func test_effect_words_are_slapstick() -> void:
	for key in I18n.keys():
		if String(key).begins_with("fx."):
			var text := I18n.text_in(key, "en").to_lower()
			for bad in ["kill", "dead", "blood", "die", "hurt", "ouch"]:
				check_false(text.contains(bad), "%s is family-friendly" % key)
