extends Node
## Player settings in <DataDir>/settings.json: language (English on first start), music and effects volume and the
## "reduce screen shake and flashes" toggle. Applies them at boot and live on every change. Contract: the file is
## written before EventBus.settings_changed is emitted for the reduce toggle, so readers of the file see the new
## value. Slider changes are saved debounced and flushed on drag end, screen close and exit.

const FILE := FxSettings.FILE

var _values := {}
var _status := ""
var _dirty := false
var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer = Timer.new()
	_save_timer.name = "SaveTimer"
	_save_timer.one_shot = true
	_save_timer.timeout.connect(flush)
	add_child(_save_timer)
	reload()


func _default_volume() -> float:
	return Balance.get_float("audio", "default_volume")


func file_path() -> String:
	return DataDir.file(FILE)


## Re-reads settings.json (missing or corrupt means defaults) and applies every value.
func reload() -> void:
	var res := JsonStore.read(file_path())
	_status = res["status"]
	_values = SettingsModel.sanitize(res["data"], _default_volume())
	_dirty = false
	if _save_timer != null:
		_save_timer.stop()
	apply_all()


## Status of the last read: ok, missing, empty or corrupt.
func last_status() -> String:
	return _status


func get_value(key: String) -> Variant:
	return _values.get(key)


func values() -> Dictionary:
	return _values.duplicate()


## Stores, applies and saves one value; save_now false debounces the write (sliders). The reduce toggle is
## always written at once.
func set_value(key: String, value: Variant, save_now: bool = true) -> void:
	if not SettingsModel.is_key(key):
		push_warning("Settings: unknown key %s" % key)
		return
	var clean: Variant = SettingsModel.sanitize_value(key, value, _values.get(key))
	var changed: bool = clean != _values.get(key)
	_values[key] = clean
	_apply(key)
	var debounce := Balance.get_float("flow", "settings_save_debounce_s")
	if save_now or key == SettingsModel.KEY_REDUCE or debounce <= 0.0:
		save()
	elif changed:
		_dirty = true
		_save_timer.start(debounce)
	if changed:
		EventBus.settings_changed.emit(key)


## Writes settings.json now and returns the Error code.
func save() -> Error:
	_dirty = false
	_save_timer.stop()
	return JsonStore.write_atomic(file_path(), _values)


## Writes pending debounced changes.
func flush() -> void:
	if _dirty:
		save()


func has_pending_save() -> bool:
	return _dirty


func apply_all() -> void:
	for key in SettingsModel.KEYS:
		_apply(key)


func _apply(key: String) -> void:
	match key:
		SettingsModel.KEY_LOCALE:
			if I18n.get_locale() != String(_values[key]):
				I18n.set_locale(String(_values[key]))
		SettingsModel.KEY_MUSIC:
			Audio.set_volume("music", float(_values[key]))
		SettingsModel.KEY_EFFECTS:
			Audio.set_volume("effects", float(_values[key]))


## Back to in-memory defaults without touching any file (between tests).
func reset_for_tests() -> void:
	_values = SettingsModel.defaults(_default_volume())
	_status = ""
	_dirty = false
	if _save_timer != null:
		_save_timer.stop()
	apply_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()


func _exit_tree() -> void:
	flush()
