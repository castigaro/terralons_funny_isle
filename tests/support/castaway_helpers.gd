extends RefCounted
## Shared helpers for the pure castaway logic tests (fixed 60 Hz ticks against a stub world).

const StubWorld := preload("res://tests/support/stub_castaway_world.gd")
const StubThing := preload("res://tests/support/stub_thing.gd")
const DT := 1.0 / 60.0


static func config() -> CastawayConfig:
	return CastawayConfig.from_balance()


static func logic(facing: float = 0.0) -> CastawayLogic:
	var l := CastawayLogic.new(config())
	l.reset_to(facing)
	return l


static func world() -> CastawayWorld:
	return StubWorld.new()


static func tick(l: CastawayLogic, move: Vector2 = Vector2.ZERO, dash: bool = false, interact: bool = false,
		w: CastawayWorld = null, pos: Vector2 = Vector2.ZERO) -> CastawayStep:
	return l.step(CastawayInput.make(move, dash, interact), DT, pos, w if w != null else world())


## Runs n ticks with the same input (presses only on the first tick) and returns the last step.
static func run(l: CastawayLogic, n: int, move: Vector2 = Vector2.ZERO, w: CastawayWorld = null,
		pos: Vector2 = Vector2.ZERO) -> CastawayStep:
	var last: CastawayStep = null
	for i in n:
		last = tick(l, move, false, false, w, pos)
	return last


static func ticks_for(seconds: float) -> int:
	return int(ceil(seconds / DT - 0.0001))
