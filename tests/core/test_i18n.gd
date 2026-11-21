extends TestCase
## I18n autoload: default locale, live switch, placeholders and the pure CSV loader.

const I18nScript := preload("res://scripts/autoload/i18n.gd")
const DataDirScript := preload("res://scripts/autoload/data_dir.gd")
const SignalRecorder := preload("res://tests/support/signal_recorder.gd")


func _i18n() -> Node:
	return root().get_node("I18n")


func _fixture_dir(name: String) -> String:
	var data_dir := root().get_node("DataDir")
	var rel := "fixtures/i18n_%s" % name
	data_dir.ensure_dir(rel)
	var dir: String = DataDirScript.globalize(data_dir.file(rel))
	for old in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(old))
	return dir


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _parse_errors(name: String, files: Dictionary) -> Array:
	var dir := _fixture_dir(name)
	for file_name in files:
		var content: Variant = files[file_name]
		var bytes: PackedByteArray = content if content is PackedByteArray else String(content).to_utf8_buffer()
		_write_bytes(dir.path_join(file_name), bytes)
	return I18nScript.parse_dir(dir)["errors"]


func test_default_locale_is_english() -> void:
	var i18n := _i18n()
	check_eq(i18n.startup_locale, "en", "startup locale")
	check_eq(i18n.get_locale(), "en", "current locale")
	check_eq(i18n.last_errors(), [], "load errors")
	check_eq(tr("core.title"), "Terralon's Funny Isle", "EN title")


func test_switch_to_german_emits_once() -> void:
	var i18n := _i18n()
	var rec := SignalRecorder.new(i18n)
	i18n.set_locale("de")
	check_eq(rec.events(), [["locale_changed", ["de"]]], "signal")
	check_eq(tr("core.title"), "Terralons lustige Insel", "DE title")
	check_eq(i18n.text_in("core.title", "en"), "Terralon's Funny Isle", "text_in")
	rec.disconnect_all()


func test_placeholders() -> void:
	var tr_res := Translation.new()
	tr_res.locale = "en"
	tr_res.add_message("core.test_greeting", "Hi {who}, {list}")
	TranslationServer.add_translation(tr_res)
	var text: String = _i18n().t("core.test_greeting", {"who": {"key": "core.title"}, "list": ["a", "b"]})
	TranslationServer.remove_translation(tr_res)
	check_eq(text, "Hi Terralon's Funny Isle, a, b", "formatted")


func test_has_key_and_keys() -> void:
	check(_i18n().has_key("core.title"), "has core.title")
	check(_i18n().keys().has("core.press_any_key"), "keys list")


func test_parse_rejects_bom() -> void:
	var bom := PackedByteArray([0xEF, 0xBB, 0xBF])
	bom.append_array("key,en,de\ncore.a,A,B\n".to_utf8_buffer())
	var errors := _parse_errors("bom", {"core.csv": bom})
	check_eq(errors.size(), 1, "one error")
	check(str(errors).contains("BOM"), "BOM error %s" % str(errors))


func test_parse_rejects_wrong_header() -> void:
	var errors := _parse_errors("header", {"core.csv": "key,en,fr\ncore.a,A,B\n"})
	check(errors.size() == 1 and str(errors).contains("header"), "header error %s" % str(errors))


func test_parse_rejects_duplicate_across_files() -> void:
	var errors := _parse_errors("dup", {"a.csv": "key,en,de\nx.k,A,B\n", "b.csv": "key,en,de\nx.k,C,D\n"})
	check(errors.size() == 1 and str(errors).contains("duplicate"), "duplicate error %s" % str(errors))


func test_parse_rejects_empty_cell_and_columns() -> void:
	var errors := _parse_errors("empty", {"core.csv": "key,en,de\ncore.a,A,\ncore.b,A\n,A,B\n"})
	var text := str(errors)
	check_eq(errors.size(), 3, "three errors %s" % text)
	check(text.contains("empty text"), "empty cell")
	check(text.contains("expected 3 columns"), "columns")
	check(text.contains("empty key"), "empty key")
