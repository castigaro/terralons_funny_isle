class_name SettingsModel
extends RefCounted
## Settings values (pure): language, music and effects volume (linear 0..1, 0 mutes) and the "reduce screen
## shake and flashes" toggle. sanitize() checks every key on its own; unknown keys are dropped.

const SCHEMA_VERSION := 1
const KEY_LOCALE := "locale"
const KEY_MUSIC := "music_volume"
const KEY_EFFECTS := "effects_volume"
const KEY_REDUCE := FxSettings.KEY
const KEYS := [KEY_LOCALE, KEY_MUSIC, KEY_EFFECTS, KEY_REDUCE]
const I18nScript := preload("res://scripts/autoload/i18n.gd")


static func defaults(default_volume: float) -> Dictionary:
	var volume := clampf(default_volume, 0.0, 1.0)
	return {"schema_version": SCHEMA_VERSION, KEY_LOCALE: I18nScript.DEFAULT_LOCALE, KEY_MUSIC: volume,
			KEY_EFFECTS: volume, KEY_REDUCE: false}


## Returns a complete, valid settings dictionary; a missing schema_version counts as the current one, a newer
## one gives the defaults.
static func sanitize(data: Variant, default_volume: float) -> Dictionary:
	var out := defaults(default_volume)
	if not data is Dictionary:
		return out
	var version: Variant = data.get("schema_version", SCHEMA_VERSION)
	if not (version is int or version is float) or int(version) > SCHEMA_VERSION:
		return out
	for key in KEYS:
		if data.has(key):
			out[key] = sanitize_value(key, data[key], out[key])
	return out


## Returns a valid value for one key, or fallback.
static func sanitize_value(key: String, value: Variant, fallback: Variant) -> Variant:
	match key:
		KEY_LOCALE:
			return value if value is String and I18nScript.LOCALES.has(value) else I18nScript.DEFAULT_LOCALE
		KEY_MUSIC, KEY_EFFECTS:
			if (value is int) or (value is float and is_finite(value)):
				return clampf(float(value), 0.0, 1.0)
			return fallback
		KEY_REDUCE:
			return value if value is bool else false
	return fallback


static func is_key(key: String) -> bool:
	return KEYS.has(key)
