extends TestCase
## Feedback coverage (AC1): every custom EventBus signal is mapped to visual entries or listed in no_visual, the
## required gameplay signals play visuals and the script signal list equals the source declarations.

const BUS_PATH := "res://scripts/autoload/event_bus.gd"
const BUILTINS := ["ready", "tree_entered", "tree_exiting", "tree_exited", "script_changed", "child_entered_tree",
		"child_exiting_tree", "renamed", "property_list_changed", "editor_description_changed"]
const REQUIRED := ["castaway_step", "castaway_dashed", "object_grabbed", "object_thrown", "object_landed",
		"object_used", "task_completed", "object_bonked", "animal_fled", "animal_bonked", "animal_panicked",
		"animal_caught", "animal_lured", "timer_warning", "event_triggered", "event_warning"]


func _decls() -> Array:
	return FeedbackMap.custom_signals(load(BUS_PATH))


func _map() -> FeedbackMap:
	var res := FeedbackMap.parse(FeedbackDirector.FEEDBACK_PATH, _decls(),
			Balance.get_section("feedback").get("strengths", {}))
	check_eq(res["errors"], [], "feedback.json parses without errors")
	return res["map"]


func _by_name(decls: Array) -> Dictionary:
	var out := {}
	for d in decls:
		out[d["name"]] = d["args"]
	return out


func test_script_signals_equal_source_declarations() -> void:
	var from_script := _by_name(_decls())
	var from_text := _by_name(FeedbackMap.parse_signal_decls(FileAccess.get_file_as_string(BUS_PATH)))
	var a := from_script.keys()
	var b := from_text.keys()
	a.sort()
	b.sort()
	check_eq(a, b, "same signal names")
	for name in from_script:
		check_eq(from_script[name], from_text.get(name, []), "%s arguments" % name)
	check(a.size() >= 30, "all signals found: %d" % a.size())


func test_no_node_builtins() -> void:
	for d in _decls():
		check_false(BUILTINS.has(d["name"]), "built-in %s listed as custom signal" % d["name"])


func test_every_signal_mapped_or_no_visual_not_both() -> void:
	var map := _map()
	for d in _decls():
		var name: String = d["name"]
		var mapped := map.is_mapped(name)
		var silent := map.is_no_visual(name)
		check(mapped != silent, "%s: mapped=%s no_visual=%s" % [name, mapped, silent])
	for name in map.no_visual():
		check(str(map.no_visual()[name]).length() > 0, "%s has a reason" % name)


func test_required_signals_have_visual_entries() -> void:
	var map := _map()
	var types: Dictionary = LevelDef.load_event_types("res://data/events.json")["types"]
	for name in REQUIRED:
		var count := 0
		if FeedbackMap.EVENT_SIGNALS.has(name):
			count = map.entries_for(name, []).size()
			for t in types:
				check(map.event_entries(t, FeedbackMap.EVENT_SIGNALS[name]).size() > 0,
						"%s has %s entries for %s" % [name, FeedbackMap.EVENT_SIGNALS[name], t])
			count += 1
		else:
			var spec: Dictionary = map.signals.get(name, {})
			count = spec.get("default", []).size()
			for value in spec.get("variants", {}):
				count += spec["variants"][value].size()
		check(count > 0, "%s has visual entries" % name)


func test_at_most_four_arguments() -> void:
	for d in _decls():
		check(d["argc"] <= FeedbackDirector.MAX_SIGNAL_ARGS, "%s has %d arguments" % [d["name"], d["argc"]])


func test_structural_errors_are_reported() -> void:
	var decls := [{"name": "object_bonked", "argc": 2, "args": ["kind", "cause"]}]
	var data := {"format_version": 1, "materials": {"mud": "#7a5230"}, "no_visual": {},
		"signals": {
			"ready": {"default": []},
			"object_bonked": {"variant_arg": "nope", "default": [{"effect": "laser", "strength": "x"},
					{"effect": "shake", "strength": "missing"}, {"effect": "popup", "anchor": "moon",
					"strength": "normal", "word": "fx.bonk"}]},
		},
		"events": {}}
	var res := FeedbackMap.from_data(data, decls, {"shake": {"bonk": {}}, "popup": {"normal": {}}})
	var text := "\n".join(PackedStringArray(res["errors"]))
	for needle in ["signals.ready: not an EventBus signal", "variant_arg: nope", "unknown effect laser",
			"strengths.shake.missing missing", "unknown anchor moon"]:
		check(text.contains(needle), "error %s in %s" % [needle, text])
