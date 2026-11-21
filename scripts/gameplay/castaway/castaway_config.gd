class_name CastawayConfig
extends RefCounted
## Typed castaway tuning values from data/balance/castaway.json (namespace "castaway").

const NAMESPACE := "castaway"
const KEYS := [
	"move_speed", "move_accel", "move_decel", "carry_speed_factor", "turn_speed",
	"dash_distance", "dash_duration", "dash_cooldown",
	"grab_radius", "grab_cone_degrees", "grab_touch_radius", "use_radius",
	"throw_range", "throw_flight_time", "throw_arc_height", "throw_aim_tolerance_degrees", "throw_pose_seconds",
	"throw_wall_pad",
	"knockback_distance", "knockback_duration", "dizzy_seconds", "dizzy_immunity_seconds",
	"body_radius", "hold_offset", "sprite_scale", "shadow_scale", "shadow_min_scale",
	"star_scale", "star_count", "star_orbit_radius", "star_orbit_speed", "star_height",
	"bob_amplitude", "bob_frequency", "lean_degrees", "dash_stretch", "landing_squash", "landing_squash_seconds",
	"throw_punch_offset", "dizzy_wobble_degrees", "dizzy_wobble_frequency", "dust_amount", "step_interval",
	"carry_weight_min", "carry_weight_max", "slippery_accel_factor", "slippery_friction_factor",
]

var move_speed := 0.0
var move_accel := 0.0
var move_decel := 0.0
var carry_speed_factor := 0.0
var turn_speed := 0.0
var dash_distance := 0.0
var dash_duration := 0.0
var dash_cooldown := 0.0
var grab_radius := 0.0
## Half-angle of the grab cone in degrees (75 means 150 degrees in total).
var grab_cone_degrees := 0.0
var grab_touch_radius := 0.0
var use_radius := 0.0
var throw_range := 0.0
var throw_flight_time := 0.0
var throw_arc_height := 0.0
var throw_aim_tolerance_degrees := 0.0
var throw_pose_seconds := 0.0
var throw_wall_pad := 0.0
var knockback_distance := 0.0
var knockback_duration := 0.0
var dizzy_seconds := 0.0
var dizzy_immunity_seconds := 0.0
var body_radius := 0.0
var hold_offset := 0.0
var sprite_scale := 0.0
var shadow_scale := 0.0
var shadow_min_scale := 0.0
var star_scale := 0.0
var star_count := 0.0
var star_orbit_radius := 0.0
var star_orbit_speed := 0.0
var star_height := 0.0
var bob_amplitude := 0.0
var bob_frequency := 0.0
var lean_degrees := 0.0
var dash_stretch := 0.0
var landing_squash := 0.0
var landing_squash_seconds := 0.0
var throw_punch_offset := 0.0
var dizzy_wobble_degrees := 0.0
var dizzy_wobble_frequency := 0.0
var dust_amount := 0.0
var step_interval := 0.0
## Limits for the carry weight of animals and items (1.0 is a normal load).
var carry_weight_min := 0.0
var carry_weight_max := 0.0
## Traction on slippery ground (mud): share of move_accel while steering and of move_decel while sliding out.
var slippery_accel_factor := 1.0
var slippery_friction_factor := 1.0
## Keys that were missing in the source dictionary.
var missing: Array = []


static func from_dict(values: Dictionary) -> CastawayConfig:
	var cfg := CastawayConfig.new()
	for key in KEYS:
		if values.has(key):
			cfg.set(key, float(values[key]))
		else:
			cfg.missing.append(key)
	return cfg


static func from_balance() -> CastawayConfig:
	return from_dict(Balance.get_section(NAMESPACE))


func dash_speed() -> float:
	return dash_distance / dash_duration


func knockback_speed() -> float:
	return knockback_distance / knockback_duration
