class_name FxStrengths
extends RefCounted
## Effective effect values from the balance section "feedback" and the reduce toggle. fx_scale scales the
## intensity fields (amplitude, ms, px, amount, alpha) and the deviation of size fields (scale, x, y) from 1;
## durations and speeds stay. With reduce on, shake amplitude and flash alpha are additionally multiplied by
## reduce_motion_factor (at most 0.25). Hit-stop is clamped to hitstop_max_ms and also scaled by hitstop_scale.

const NAMESPACE := "feedback"
const INTENSITY_FIELDS := ["amplitude", "ms", "px", "amount", "alpha"]
const RELATIVE_FIELDS := ["scale", "x", "y"]

var section: Dictionary = {}
var reduce := false


func _init(values: Dictionary = {}, reduce_on: bool = false) -> void:
	section = values
	reduce = reduce_on


static func from_balance(reduce_on: bool) -> FxStrengths:
	return FxStrengths.new(Balance.get_section(NAMESPACE), reduce_on)


func num(key: String, default: float = 0.0) -> float:
	var v: Variant = section.get(key, default)
	return float(v) if (v is float or v is int) else default


func vec(key: String) -> Vector2:
	var v: Variant = section.get(key, [])
	if v is Array and v.size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO


func sub(key: String) -> Dictionary:
	var v: Variant = section.get(key, {})
	return v if v is Dictionary else {}


func fx_scale() -> float:
	return clampf(num("fx_scale", 1.0), 0.0, 1.0)


func reduce_factor() -> float:
	return clampf(num("reduce_motion_factor", 0.0), 0.0, 1.0)


func has_strength(effect: String, key: String) -> bool:
	var group: Variant = sub("strengths").get(effect, {})
	return group is Dictionary and (group as Dictionary).has(key)


## Raw value of strengths.<effect>.<key>.<field> (default when missing).
func base(effect: String, key: String, field: String, default: float = 0.0) -> float:
	var group: Variant = sub("strengths").get(effect, {})
	if not group is Dictionary:
		return default
	var entry: Variant = (group as Dictionary).get(key, {})
	if not entry is Dictionary:
		return default
	var v: Variant = (entry as Dictionary).get(field, default)
	return float(v) if (v is float or v is int) else default


func effective(effect: String, key: String, field: String) -> float:
	var relative := RELATIVE_FIELDS.has(field)
	var value := base(effect, key, field, 1.0 if relative else 0.0)
	if INTENSITY_FIELDS.has(field):
		value *= fx_scale()
	elif relative:
		value = 1.0 + (value - 1.0) * fx_scale()
	if reduce and ((effect == "shake" and field == "amplitude") or (effect == "flash" and field == "alpha")):
		value *= reduce_factor()
	return value


func shake_amplitude(key: String) -> float:
	return effective("shake", key, "amplitude")


func flash_alpha(key: String) -> float:
	return effective("flash", key, "alpha")


func hitstop_ms(key: String) -> float:
	var ms := effective("hitstop", key, "ms") * clampf(num("hitstop_scale", 1.0), 0.0, 1.0)
	return clampf(ms, 0.0, num("hitstop_max_ms"))


func cap(type: String) -> int:
	return maxi(1, int(sub("caps").get(type, 1)))
