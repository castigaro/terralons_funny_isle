class_name AudioTuning
extends RefCounted
## Typed view of data/balance/audio.json; the only place that knows its key names.

const NS := "audio"
const NUMBER_KEYS := ["default_cooldown_seconds", "default_voice_limit", "sfx_pitch_jitter", "sfx_seed",
		"jingle_duck_db", "duck_attack_seconds", "duck_release_seconds", "music_crossfade_seconds", "music_volume_db",
		"silent_db", "announcer_gap_seconds", "announcer_max_queue", "caption_extra_seconds", "caption_fade_seconds",
		"caption_font_size", "caption_max_width_share", "caption_top_share", "caption_panel_alpha", "caption_padding",
		"caption_layer", "default_volume", "quit_settle_msec"]
const NON_NEGATIVE_KEYS := ["default_cooldown_seconds", "sfx_pitch_jitter", "duck_attack_seconds",
		"duck_release_seconds", "music_crossfade_seconds", "announcer_gap_seconds", "caption_extra_seconds",
		"caption_fade_seconds", "default_volume"]

var default_cooldown := 0.0
var default_voice_limit := 1
var per_sound := {}
var pitch_jitter := 0.0
var sfx_seed := 0
var duck_db := 0.0
var duck_attack := 0.0
var duck_release := 0.0
var crossfade := 0.0
var music_db := 0.0
var silent_db := 0.0
var announcer_gap := 0.0
var announcer_max_queue := 1
var caption_extra := 0.0
var caption_fade := 0.0
var caption_font_size := 1
var caption_max_width_share := 1.0
var caption_top_share := 0.0
var caption_panel_alpha := 1.0
var caption_padding := 0
var caption_layer := 1
var default_volume := 1.0
var quit_settle_msec := 0
var errors: Array = []


## Builds the tuning from a balance section (the merged "audio" section of the Balance autoload).
static func from_section(section: Dictionary) -> AudioTuning:
	var t := AudioTuning.new()
	for key in NUMBER_KEYS:
		var v: Variant = section.get(key)
		if not (v is int or v is float):
			t.errors.append("balance audio: %s missing or not a number" % key)
	for key in NON_NEGATIVE_KEYS:
		if _num(section, key, 0.0) < 0.0:
			t.errors.append("balance audio: %s must be >= 0" % key)
	if _num(section, "default_voice_limit", 1.0) < 1.0:
		t.errors.append("balance audio: default_voice_limit must be >= 1")
	t.default_cooldown = maxf(_num(section, "default_cooldown_seconds", 0.0), 0.0)
	t.default_voice_limit = maxi(int(_num(section, "default_voice_limit", 1.0)), 1)
	var per: Variant = section.get("per_sound", {})
	if per is Dictionary:
		for id in per:
			var spec: Variant = per[id]
			if not spec is Dictionary:
				t.errors.append("balance audio: per_sound.%s must be an object" % id)
				continue
			if _num(spec, "voice_limit", 1.0) < 1.0:
				t.errors.append("balance audio: per_sound.%s.voice_limit must be >= 1" % id)
			if _num(spec, "cooldown_seconds", 0.0) < 0.0:
				t.errors.append("balance audio: per_sound.%s.cooldown_seconds must be >= 0" % id)
			t.per_sound[id] = spec
	else:
		t.errors.append("balance audio: per_sound must be an object")
	t.pitch_jitter = maxf(_num(section, "sfx_pitch_jitter", 0.0), 0.0)
	t.sfx_seed = int(_num(section, "sfx_seed", 0.0))
	t.duck_db = _num(section, "jingle_duck_db", 0.0)
	t.duck_attack = maxf(_num(section, "duck_attack_seconds", 0.0), 0.0)
	t.duck_release = maxf(_num(section, "duck_release_seconds", 0.0), 0.0)
	t.crossfade = maxf(_num(section, "music_crossfade_seconds", 0.0), 0.0)
	t.music_db = _num(section, "music_volume_db", 0.0)
	t.silent_db = _num(section, "silent_db", 0.0)
	t.announcer_gap = maxf(_num(section, "announcer_gap_seconds", 0.0), 0.0)
	t.announcer_max_queue = maxi(int(_num(section, "announcer_max_queue", 1.0)), 1)
	t.caption_extra = maxf(_num(section, "caption_extra_seconds", 0.0), 0.0)
	t.caption_fade = maxf(_num(section, "caption_fade_seconds", 0.0), 0.0)
	t.caption_font_size = maxi(int(_num(section, "caption_font_size", 1.0)), 1)
	t.caption_max_width_share = clampf(_num(section, "caption_max_width_share", 1.0), 0.0, 1.0)
	t.caption_top_share = clampf(_num(section, "caption_top_share", 0.0), 0.0, 1.0)
	t.caption_panel_alpha = clampf(_num(section, "caption_panel_alpha", 1.0), 0.0, 1.0)
	t.caption_padding = maxi(int(_num(section, "caption_padding", 0.0)), 0)
	t.caption_layer = int(_num(section, "caption_layer", 1.0))
	t.default_volume = clampf(_num(section, "default_volume", 1.0), 0.0, 1.0)
	t.quit_settle_msec = maxi(int(_num(section, "quit_settle_msec", 0.0)), 0)
	return t


static func _num(section: Dictionary, key: String, fallback: float) -> float:
	var v: Variant = section.get(key, fallback)
	if v is int or v is float:
		return float(v)
	return fallback


## Cooldown of one sound in seconds (per_sound override, else the default).
func cooldown(sound_id: String) -> float:
	var spec: Dictionary = per_sound.get(sound_id, {})
	return maxf(_num(spec, "cooldown_seconds", default_cooldown), 0.0)


## Maximum number of voices of one sound playing at the same time.
func voice_limit(sound_id: String) -> int:
	var spec: Dictionary = per_sound.get(sound_id, {})
	return maxi(int(_num(spec, "voice_limit", float(default_voice_limit))), 1)
