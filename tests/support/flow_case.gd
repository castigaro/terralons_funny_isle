extends TestCase
## Base for game flow tests: a per-test data folder below the redirected test data root, the fixture campaign
## (sample and small level plus one missing scene), fixture translations, the GameFlow root and synthetic keys,
## clicks and hovers pushed through the root viewport.

const FIXTURE_CAMPAIGN := "res://tests/fixtures/flow/campaign.json"
const MAIN_SCENE := "res://scenes/main.tscn"
const FIXTURE_LEVELS := "res://tests/fixtures/levels"
const FIXTURE_I18N := ["res://tests/fixtures/levels/i18n", "res://tests/fixtures/flow/i18n"]
const SAMPLE := "valid_sample_level"
const SMALL := "valid_small_level"
const MISSING := "missing_level"
const ENV_VAR := "TFI_DATA_DIR"

static var _base_env := ""

var flow: Node = null
var quit_calls := 0
var _translations: Array = []


## Points DataDir at <test data root>/bi7/<sub> (fresh: old settings and progress files there are removed).
func use_data_dir(sub: String) -> String:
	if _base_env == "":
		_base_env = OS.get_environment(ENV_VAR)
	check_ne(_base_env, "", "run_tests sets TFI_DATA_DIR")
	var dir := _base_env.path_join("bi7").path_join(sub)
	OS.set_environment(ENV_VAR, dir)
	check_false(DataDir.path().begins_with("user://"), "data dir is redirected")
	DirAccess.make_dir_recursive_absolute(dir)
	for name in ["settings.json", "progress.json", "settings.json.tmp", "progress.json.tmp"]:
		if FileAccess.file_exists(dir.path_join(name)):
			DirAccess.remove_absolute(dir.path_join(name))
	return dir


func restore_data_dir() -> void:
	if _base_env != "":
		OS.set_environment(ENV_VAR, _base_env)


func write_file(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Adds the fixture catalogues to the TranslationServer (level and task titles of the sample levels).
func install_fixture_translations() -> void:
	var messages := {}
	for dir in FIXTURE_I18N:
		messages.merge(I18n.parse_dir(dir)["messages"])
	for loc in I18n.LOCALES:
		var res := Translation.new()
		res.locale = loc
		for key in messages:
			res.add_message(key, messages[key][loc])
		TranslationServer.add_translation(res)
		_translations.append(res)


## Opens the GameFlow root on the fixture campaign with a fresh data folder named after sub.
func open_flow(sub: String, campaign: String = FIXTURE_CAMPAIGN) -> Node:
	use_data_dir(sub)
	install_fixture_translations()
	Settings.reload()
	Progress.use_campaign(campaign)
	Audio.levels_dir = FIXTURE_LEVELS
	flow = (load(MAIN_SCENE) as PackedScene).instantiate()
	flow.set("quit_handler", func() -> void: quit_calls += 1)
	add_node(flow)
	await frames(1)
	return flow


func after_each() -> void:
	if flow != null and is_instance_valid(flow):
		flow.get_parent().remove_child(flow)
		flow.free()
	flow = null
	Settings.flush()
	for res in _translations:
		TranslationServer.remove_translation(res)
	_translations.clear()
	tree().paused = false
	restore_data_dir()


func screen() -> int:
	return int(flow.call("current_screen"))


func screen_node() -> MenuScreen:
	return flow.call("current_screen_node")


func level() -> LevelBase:
	return flow.call("level")


func session() -> LevelSession:
	return level().level_session() if level() != null else null


# --- Synthetic input -------------------------------------------------------------------------------------

func key(code: Key, frames_after: int = 1) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		root().push_input(ev, true)
	await frames(frames_after)


func center_of(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func hover(control: Control) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = center_of(control)
	ev.global_position = ev.position
	root().push_input(ev, true)
	await frames(1)


func click(control: Control, frames_after: int = 1) -> void:
	await hover(control)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = center_of(control)
		ev.global_position = ev.position
		ev.pressed = pressed
		root().push_input(ev, true)
	await frames(frames_after)


## Waits until the current screen accepts input (guards and delays use the ALWAYS-processing screen clock).
func wait_guard() -> void:
	var node := screen_node()
	if node != null:
		node.advance_time(node.guard_s)
	await frames(1)


func focused() -> Control:
	return root().gui_get_focus_owner()


## From the title into a running fixture level by keyboard (Enter on Play, Enter on the tile, any key).
func enter_level_by_keys() -> void:
	await key(KEY_ENTER)
	await key(KEY_ENTER)
	await wait_guard()
	await key(KEY_SPACE)


## Ends the running level as won: castaway into zone_a (required task), one tick, then finish().
func win_level() -> void:
	var lvl := level()
	lvl.castaway().call("reset_to", lvl.zone("zone_a").global_position, 0.0)
	session().tick(1.0 / 60.0, lvl.build_snapshot())
	session().finish()
	await frames(1)


## Ends the running level as lost: the whole timer in one tick with the required task open.
func lose_level() -> void:
	session().tick(level().level_def().timer_seconds + 1.0, level().build_snapshot())
	await frames(1)
