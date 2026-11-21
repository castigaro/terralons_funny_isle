extends "res://tests/support/feedback_case.gd"
## Translated sound-word popups: English by default, German after a live locale switch, auto-translation off on
## the pooled labels and every fx.* key has short EN and DE text.

const MAX_LETTERS := 8


func test_bonk_popup_in_english() -> void:
	make_director()
	emit("object_bonked", ["castaway", "coconut"])
	check_eq(director.last_popup_text(), "BONK!", "english popup")
	var labels := director.active_nodes("popup")
	check_eq(labels.size(), 1, "one popup")
	check_eq((labels[0] as Label).text, "BONK!", "label text")


func test_german_after_locale_switch() -> void:
	make_director()
	I18n.set_locale("de")
	emit("object_landed", ["coconut", Vector2(10, 10), "water"])
	check_eq(director.last_popup_text(), "KLATSCH!", "water in German")
	emit("object_landed", ["coconut", Vector2(10, 10), "mud"])
	check_eq(director.last_popup_text(), "PLATSCH!", "mud in German")
	I18n.set_locale("en")
	emit("object_landed", ["coconut", Vector2(10, 10), "mud"])
	check_eq(director.last_popup_text(), "SPLAT!", "back to English")


func test_popups_do_not_auto_translate() -> void:
	make_director()
	emit("level_started", ["lvl"])
	var labels := director.active_nodes("popup")
	check(labels.size() >= 1, "popup shown")
	for label in labels:
		check_eq((label as Label).auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "auto translate off")
		check((label as Label).label_settings != null, "label settings with the comic font")
		check_eq((label as Label).label_settings.font, FeedbackDirector.FONT, "Kenney Future")


func test_every_fx_key_has_short_en_and_de() -> void:
	var count := 0
	for key in I18n.keys():
		if not String(key).begins_with("fx."):
			continue
		count += 1
		for loc in ["en", "de"]:
			var text := I18n.text_in(key, loc)
			check(text != "", "%s %s text" % [key, loc])
			check(text.rstrip("!").length() <= MAX_LETTERS, "%s %s '%s' short" % [key, loc, text])
			check_eq(text, text.to_upper(), "%s %s upper case" % [key, loc])
	check(count >= 10, "fx keys: %d" % count)


func test_every_popup_word_is_a_key() -> void:
	make_director()
	for entry in director.map.all_entries():
		if entry["effect"] == "popup":
			check(I18n.has_key(entry["word"]), "word %s exists" % entry["word"])


func test_german_popup_fits_like_english() -> void:
	make_director()
	var font := FeedbackDirector.FONT
	var size := int(director.strengths.num("popup_font_size"))
	for key in I18n.keys():
		if not String(key).begins_with("fx."):
			continue
		var en := font.get_string_size(I18n.text_in(key, "en"), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var de := font.get_string_size(I18n.text_in(key, "de"), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var big := director.strengths.base("popup", "big", "scale")
		check(de * big < 1280.0 / 2.0, "%s German popup %.0f px fits half a 720p screen" % [key, de * big])
		check(en > 0.0, "%s english measured" % key)
