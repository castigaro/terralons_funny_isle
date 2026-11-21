extends TestCase
## Base for feedback tests: a FeedbackDirector on the root with a frame clock (60 fps under --fixed-fps 60), an
## optional stub castaway in group "castaway" and helpers to emit EventBus signals and read the played effects.

const StubFxTarget := preload("res://tests/support/stub_fx_target.gd")
const FRAME_MS := 1000.0 / 60.0
const SETTINGS_KEY := "reduce_shake_flashes"

var director: FeedbackDirector
var castaway_stub: Node2D
var bus: Node


## Builds the director; overrides are Balance values of the namespace "feedback" set before its _ready.
func make_director(with_castaway: bool = true, overrides: Dictionary = {}) -> FeedbackDirector:
	bus = root().get_node("EventBus")
	Balance.set_overrides("feedback", overrides)
	if with_castaway:
		castaway_stub = make_target(Vector2(400, 300))
		castaway_stub.add_to_group("castaway")
	director = FeedbackDirector.new()
	director.clock = frame_clock
	add_node(director)
	return director


func make_target(pos: Vector2) -> Node2D:
	var t: Node2D = StubFxTarget.new()
	t.position = pos
	add_node(t)
	return t


func frame_clock() -> float:
	return float(Engine.get_process_frames()) * FRAME_MS


func emit(sig_name: String, args: Array = []) -> void:
	bus.callv("emit_signal", [sig_name] + args)


## Effect types of the entries the director played since the last clear, for one signal.
func types_for(sig_name: String) -> Array:
	var out: Array = []
	for e in director.last_effects():
		if e["signal"] == sig_name:
			out.append(e["type"])
	return out


func effects_for(sig_name: String) -> Array:
	var out: Array = []
	for e in director.last_effects():
		if e["signal"] == sig_name:
			out.append(e)
	return out


## Writes settings.json in the (redirected) data folder.
func write_settings(values: Dictionary) -> void:
	DataDir.ensure_dir()
	var f := FileAccess.open(DataDir.file("settings.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(values))
	f.close()


## Puts the reduce toggle back to off so later directors start with full effects.
func reset_settings() -> void:
	write_settings({SETTINGS_KEY: false})
