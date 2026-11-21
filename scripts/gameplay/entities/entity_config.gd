class_name EntityConfig
extends RefCounted
## Typed animal and item tuning values from data/balance/entities.json (namespace "entities").

const NAMESPACE := "entities"
const KEYS := [
	"respawn_delay", "reaction_max_seconds", "bonk_seconds", "bonk_radius", "knockback_distance",
	"knockback_seconds", "item_knockback_distance", "item_hop_height", "item_hop_seconds", "skim_height",
	"skim_min_progress", "dash_scare_radius", "dash_scare_degrees", "dash_bump_radius", "dash_bump_distance",
	"flee_exit_factor", "flee_min_seconds", "separation_radius", "separation_strength", "accel",
	"body_radius_factor", "wander_pause_min", "wander_pause_max", "wander_arrive_distance",
	"wander_retarget_seconds", "panic_turn_interval", "lure_arrive_distance", "settle_margin",
	"corner_escape_degrees", "waddle_degrees", "waddle_frequency", "hop_height", "hop_seconds",
	"idle_hop_interval", "panic_hop_interval", "wiggle_degrees", "wiggle_frequency", "star_count", "star_scale",
	"star_orbit_radius", "star_orbit_speed", "star_height", "speed_line_amount", "emote_seconds", "emote_scale",
	"emote_height", "shadow_scale", "item_bob_amplitude", "item_bob_frequency", "puff_seconds", "puff_scale",
	"puff_frames",
]

var respawn_delay := 0.0
var reaction_max_seconds := 0.0
var bonk_seconds := 0.0
var bonk_radius := 0.0
var knockback_distance := 0.0
var knockback_seconds := 0.0
var item_knockback_distance := 0.0
var item_hop_height := 0.0
var item_hop_seconds := 0.0
var skim_height := 0.0
var skim_min_progress := 0.0
var dash_scare_radius := 0.0
var dash_scare_degrees := 0.0
var dash_bump_radius := 0.0
var dash_bump_distance := 0.0
var flee_exit_factor := 0.0
var flee_min_seconds := 0.0
var separation_radius := 0.0
var separation_strength := 0.0
var accel := 0.0
var body_radius_factor := 0.0
var wander_pause_min := 0.0
var wander_pause_max := 0.0
var wander_arrive_distance := 0.0
var wander_retarget_seconds := 0.0
var panic_turn_interval := 0.0
var lure_arrive_distance := 0.0
var settle_margin := 0.0
var corner_escape_degrees := 0.0
var waddle_degrees := 0.0
var waddle_frequency := 0.0
var hop_height := 0.0
var hop_seconds := 0.0
var idle_hop_interval := 0.0
var panic_hop_interval := 0.0
var wiggle_degrees := 0.0
var wiggle_frequency := 0.0
var star_count := 0.0
var star_scale := 0.0
var star_orbit_radius := 0.0
var star_orbit_speed := 0.0
var star_height := 0.0
var speed_line_amount := 0.0
var emote_seconds := 0.0
var emote_scale := 0.0
var emote_height := 0.0
var shadow_scale := 0.0
var item_bob_amplitude := 0.0
var item_bob_frequency := 0.0
var puff_seconds := 0.0
var puff_scale := 0.0
var puff_frames := 0.0
## Keys that were missing in the source dictionary.
var missing: Array = []


static func from_dict(values: Dictionary) -> EntityConfig:
	var cfg := EntityConfig.new()
	for key in KEYS:
		if values.has(key):
			cfg.set(key, float(values[key]))
		else:
			cfg.missing.append(key)
	return cfg


static func from_balance() -> EntityConfig:
	return from_dict(Balance.get_section(NAMESPACE))


## Speed of the knockback burst after a bonk.
func knockback_speed() -> float:
	return knockback_distance / knockback_seconds


## Speed of the push when a dash bumps an animal.
func bump_speed() -> float:
	return dash_bump_distance / knockback_seconds
