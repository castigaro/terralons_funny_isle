extends "res://tests/support/flow_case.gd"
## Credits screen: every SOURCES.md pack grouped by author with licence; reachable from the title; guard.


func test_credits_list_every_pack() -> void:
	await open_flow("credits_list")
	await click(screen_node().get("credits_button"))
	var credits := screen_node()
	check_eq(credits.call("authors"), ["Kenney", "Juhani Junkala"], "authors grouped")
	var text: String = credits.call("pack_text")
	var data: Dictionary = read_json("res://data/credits.json")
	for group in data["groups"]:
		for pack in group["packs"]:
			check_has(text, pack["pack"], "pack listed")
	for pack in ["pirate-pack", "ui-pack", "chiptunes-action", "voiceover"]:
		check_has(text, pack, "SOURCES.md pack %s" % pack)
	var labels: Array = []
	for child in credits.find_children("*", "Label", true, false):
		labels.append((child as Label).text)
	check_has(labels, "Licence: CC0 1.0", "licence shown")
	check_false(text.contains("–"), "no en dash (font has no glyph)")


func test_guard_and_return() -> void:
	await open_flow("credits_guard")
	flow.call("show_screen", FlowRules.Screen.CREDITS, FlowRules.Screen.TITLE)
	await frames(1)
	await key(KEY_SPACE)
	check_eq(screen(), FlowRules.Screen.CREDITS, "key during the guard ignored")
	await frames(int(ceilf(Balance.get_float("flow", "credits_guard_s") * 60.0)) + 2)
	await key(KEY_SPACE)
	check_eq(screen(), FlowRules.Screen.TITLE, "any key returns to the title")
