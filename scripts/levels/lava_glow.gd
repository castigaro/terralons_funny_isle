class_name LavaGlow
extends Sprite2D
## Decorative lava glow on rock: a slow sine pulse of the sprite alpha (at most once a second, small swing) that holds
## still at full glow under "reduce screen shake and flashes"; no physics, no gameplay.

## Highest allowed pulse rate (one luminance cycle per second keeps it far below any flashing threshold).
const MAX_PULSE_HZ := 1.0
## Largest allowed alpha swing between the dim and the bright end of the pulse.
const MAX_SWING := 0.35  # balance-exempt: art safety limit, not a tuning value

@export var pulse_hz := 0.4  # balance-exempt: per-instance art default
@export var alpha_min := 0.55  # balance-exempt: per-instance art default
@export var alpha_max := 0.85  # balance-exempt: per-instance art default
@export var phase := 0.0

var _time := 0.0
var _reduced := false


func _ready() -> void:
	_reduced = FxSettings.read_reduce(_settings_path())
	if _reduced:
		modulate.a = alpha_max
		set_process(false)
	else:
		modulate.a = alpha_at(0.0, pulse_hz, alpha_min, alpha_max, phase)


func _process(delta: float) -> void:
	_time += delta
	modulate.a = alpha_at(_time, pulse_hz, alpha_min, alpha_max, phase)


func is_reduced() -> bool:
	return _reduced


## Alpha of the pulse at time t; the rate is clamped to MAX_PULSE_HZ and the swing to MAX_SWING.
static func alpha_at(t: float, hz: float, amin: float, amax: float, ph: float) -> float:
	var rate := clampf(hz, 0.0, MAX_PULSE_HZ)
	var low := maxf(amin, amax - MAX_SWING)
	return lerpf(low, amax, 0.5 + 0.5 * sin(TAU * rate * t + ph))


func _settings_path() -> String:
	var data_dir := get_node_or_null("/root/DataDir")
	return String(data_dir.call("file", FxSettings.FILE)) if data_dir != null else ""
