extends TestCase
## EventBus: frozen typed signal set and no registry.

const FROZEN := [
	"level_started", "level_timer_tick", "task_completed", "all_required_done", "level_won", "level_lost",
	"event_triggered", "object_grabbed", "object_thrown", "object_bonked", "settings_changed",
	"castaway_dashed", "castaway_step", "object_used", "object_landed", "castaway_dizzy_started",
	"castaway_dizzy_ended", "interact_verb_changed",
]

var _got: Array = []


func _bus() -> Node:
	return root().get_node("EventBus")


func _on_won(level_id: String, stars: int) -> void:
	_got = [level_id, stars]


func test_typed_emit_and_receive() -> void:
	var bus := _bus()
	bus.level_won.connect(_on_won)
	bus.level_won.emit("L1", 3)
	bus.level_won.disconnect(_on_won)
	check_eq(_got, ["L1", 3], "received")


func test_frozen_signals_exist_and_are_typed() -> void:
	var names := []
	for s in _bus().get_script().get_script_signal_list():
		names.append(s["name"])
		for arg in s["args"]:
			check_ne(arg["type"], TYPE_NIL, "%s.%s untyped" % [s["name"], arg["name"]])
	for name in FROZEN:
		check(names.has(name), "missing signal %s" % name)


func test_no_registry() -> void:
	var bus := _bus()
	for method in ["register", "get_feature", "registry", "unregister"]:
		check_false(bus.has_method(method), "unexpected method %s" % method)
