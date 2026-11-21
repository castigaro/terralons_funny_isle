extends MenuScreen
## Title screen: game title, a row of island animals and the buttons Play, Settings, language toggle (shows the
## other language by its own name), Credits and Quit. Esc does nothing here.

signal play_pressed
signal settings_pressed
signal language_pressed
signal credits_pressed
signal quit_pressed

const ICON_PLAY := "res://assets/ui/ui-pack/PNG/Extra/Default/icon_play_light.png"
const ICON_SETTINGS := "res://assets/ui/ui-pack/PNG/Yellow/Default/slide_hangle.png"
const ICON_CREDITS := "res://assets/ui/ui-pack/PNG/Yellow/Default/star.png"
const ICON_QUIT := "res://assets/ui/ui-pack/PNG/Yellow/Default/icon_cross.png"
const ANIMALS := ["chicken", "pig", "goat", "duck", "monkey", "penguin"]
const ANIMAL_DIR := "res://assets/graphics/animals/PNG/Round (outline)/"

var play_button: Button
var settings_button: Button
var language_button: Button
var credits_button: Button
var quit_button: Button


func _build() -> void:
	var box := make_panel()
	box.add_child(make_label("core.title", {}, MenuTheme.VARIATION_TITLE))
	var animals := HBoxContainer.new()
	animals.alignment = BoxContainer.ALIGNMENT_CENTER
	animals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var px := float(cfg.get("title_animal_px", 0))
	for kind in ANIMALS:
		var pic := TextureRect.new()
		pic.texture = load(ANIMAL_DIR + kind + ".png")
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(px, px)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		animals.add_child(pic)
	box.add_child(animals)
	play_button = _add(box, make_button("menu.play", ICON_PLAY), play_pressed)
	settings_button = _add(box, make_button("menu.settings", ICON_SETTINGS), settings_pressed)
	language_button = _add(box, make_button(""), language_pressed)
	credits_button = _add(box, make_button("menu.credits", ICON_CREDITS), credits_pressed)
	quit_button = _add(box, make_button("menu.quit", ICON_QUIT), quit_pressed)
	_first_focus = play_button


func _add(box: Control, button: Button, sig: Signal) -> Button:
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(sig.emit)
	box.add_child(button)
	return button


func _refresh() -> void:
	bind_text(language_button, "menu.lang.de" if I18n.get_locale() == "en" else "menu.lang.en")
