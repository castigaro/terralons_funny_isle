class_name FxSettings
extends RefCounted
## Reads the player's "reduce screen shake and flashes" choice from settings.json (written by the settings menu).
## A missing or corrupt file or a non-bool value means off.

const KEY := "reduce_shake_flashes"
const FILE := "settings.json"


static func read_reduce(path: String) -> bool:
	if path == "" or not FileAccess.file_exists(path):
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return false
	var value: Variant = (json.data as Dictionary).get(KEY, false)
	return value is bool and value
