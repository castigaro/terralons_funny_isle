class_name Hud
extends CanvasLayer
## In-level HUD: task list with progress and required/optional marks, countdown with warning pulse, 3-star time
## goal, hint button and hint panel, failure cue slot, "Finish!" banner and the interact prompt. It polls the
## LevelSession every frame, reacts to EventBus signals and never changes the session. The layout uses logical
## 1920x1080 coordinates at the screen edges; panels fade when the castaway walks under them. See docs/hud.md.

const FONT_PATH := "res://assets/ui/ui-pack/Font/Kenney Future Narrow.ttf"
const STAR_FULL := "res://assets/ui/ui-pack/PNG/Yellow/Default/star.png"
const STAR_EMPTY := "res://assets/ui/ui-pack/PNG/Yellow/Default/star_outline.png"
const ICON_DONE := "res://assets/ui/ui-pack/PNG/Blue/Default/icon_checkmark.png"
const ICON_MISSED := "res://assets/ui/ui-pack/PNG/Blue/Default/icon_cross.png"
const ICON_HINT := "res://assets/graphics/emotes/PNG/Vector/Style 1/emote_question.png"
const ICON_WARN := "res://assets/graphics/emotes/PNG/Vector/Style 1/emote_exclamation.png"
## Event warning cue key prefix; the event type completes the key (hud.cue.warn.<event_type>).
const WARN_KEY_PREFIX := "hud.cue.warn."
const KEY_CAP_SCENE := preload("res://scenes/ui/key_cap.tscn")
const HINT_BUTTON_KEY := "hud.hint_button"
const STAR_GOAL_KEY := "hud.star_goal"
const BANNER_KEY := "hud.banner.finish"
const REQUIRED_KEY := "hud.required"
const OPTIONAL_KEY := "hud.optional"
const DIGITS_SAMPLE := "88/88"
const TIME_SAMPLE := "8:88"
const GLYPH_RE := "^[A-Za-z0-9_]{1,8}$"

static var _config_cache: Dictionary = {}

var _cfg: Dictionary = {}
var _font: Font
var _level: Node
var _session: LevelSession
var _def: LevelDef
var _castaway: Node2D
var _model: HudModel = HudModel.new()
var _throttle: HudModel.CueThrottle
var _layout_size := Vector2.ZERO
var _clock := 0.0
var _warn_seconds := 0.0
var _reduce := false
var _sample_mode := false

var _root: Control
var _top_left: VBoxContainer
var _task_panel: PanelContainer
var _task_list: VBoxContainer
var _rows: Array = []
var _hint_row: HBoxContainer
var _hint_button: TextureButton
var _hint_key_cap: KeyCap
var _hint_panel: PanelContainer
var _hint_label: Label
var _timer_panel: PanelContainer
var _timer_label: Label
var _star_caption: Label
var _star_icon: TextureRect
var _star_label: Label
var _star_state: TextureRect
var _cue_panel: PanelContainer
var _cue_icon: TextureRect
var _cue_label: Label
var _banner: PanelContainer
var _banner_label: Label
var _banner_key: KeyCap
var _prompt: PanelContainer
var _prompt_key: KeyCap
var _verb_label: Label

var _hint_key := ""
var _hint_left := 0.0
var _cue_key := ""
var _verb := "none"
var _warning := false
var _pulse_time := 0.0
var _alpha := {}
var _forced_castaway_rect := Rect2()


func _ready() -> void:
	_cfg = Balance.get_section("hud")
	layer = int(_cfg.get("layer", 1))
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	_throttle = HudModel.CueThrottle.new(float(_cfg.get("cue_seconds", 1.0)), float(_cfg.get("cue_min_interval", 0.0)))
	_build()
	EventBus.entity_lost.connect(_on_entity_lost)
	EventBus.level_lost.connect(_on_level_lost)
	EventBus.castaway_dizzy_started.connect(_on_dizzy_started)
	EventBus.event_triggered.connect(_on_event_triggered)
	EventBus.event_warning.connect(_on_event_warning)
	EventBus.animal_fled.connect(_on_animal_fled)
	EventBus.interact_verb_changed.connect(_on_verb_changed)
	EventBus.level_restarted.connect(_on_level_restarted)
	EventBus.level_won.connect(_on_level_ended.unbind(2))
	EventBus.settings_changed.connect(_on_settings_changed)
	I18n.locale_changed.connect(_on_locale_changed)
	get_viewport().size_changed.connect(force_layout)
	_reduce = FxSettings.read_reduce(DataDir.file(FxSettings.FILE))
	visible = false
	force_layout()


# --- Building --------------------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var sep := int(_cfg.get("row_separation_px", 0))

	_top_left = VBoxContainer.new()
	_top_left.name = "TopLeft"
	_top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_left.add_theme_constant_override("separation", sep)
	_root.add_child(_top_left)
	_task_panel = _panel("TaskPanel")
	_top_left.add_child(_task_panel)
	_task_list = VBoxContainer.new()
	_task_list.name = "TaskList"
	_task_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_task_list.add_theme_constant_override("separation", sep)
	_task_panel.add_child(_task_list)

	_hint_row = HBoxContainer.new()
	_hint_row.name = "HintRow"
	_hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_row.add_theme_constant_override("separation", sep)
	_top_left.add_child(_hint_row)
	_hint_button = TextureButton.new()
	_hint_button.name = "HintButton"
	_hint_button.texture_normal = load(ICON_HINT)
	_hint_button.ignore_texture_size = true
	_hint_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_hint_button.focus_mode = Control.FOCUS_NONE
	_hint_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var hb := float(_cfg.get("hint_button_size_px", 1))
	_hint_button.custom_minimum_size = Vector2(hb, hb)
	_hint_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_hint_button.pressed.connect(show_hint)
	_hint_row.add_child(_hint_button)
	_hint_key_cap = KEY_CAP_SCENE.instantiate()
	_hint_key_cap.name = "HintKey"
	_hint_key_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hint_row.add_child(_hint_key_cap)
	_hint_key_cap.set_action(&"hint")
	_hint_panel = _panel("HintPanel")
	_hint_row.add_child(_hint_panel)
	_hint_label = _label("HintLabel", int(_cfg.get("font_size", 1)))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.max_lines_visible = int(_cfg.get("hint_max_lines", 1))
	_hint_label.custom_minimum_size = Vector2(float(_cfg.get("hint_width_px", 1)), 0.0)
	_hint_panel.add_child(_hint_label)
	_hint_panel.visible = false

	_timer_panel = _panel("TimerPanel")
	_timer_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_timer_panel)
	var timer_box := _hbox("TimerBox")
	_timer_panel.add_child(timer_box)
	_timer_label = _label("TimerLabel", int(_cfg.get("timer_font_size", 1)))
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.custom_minimum_size = Vector2(_text_width(TIME_SAMPLE, int(_cfg.get("timer_font_size", 1))), 0.0)
	timer_box.add_child(_timer_label)
	_star_caption = _label("StarGoalCaption", int(_cfg.get("tag_font_size", 1)))
	timer_box.add_child(_star_caption)
	_star_icon = _icon("StarGoalIcon", STAR_FULL)
	timer_box.add_child(_star_icon)
	_star_label = _label("StarGoalLabel", int(_cfg.get("font_size", 1)))
	timer_box.add_child(_star_label)
	_star_state = _icon("StarGoalState", ICON_DONE)
	timer_box.add_child(_star_state)

	_cue_panel = _panel("CueSlot")
	_root.add_child(_cue_panel)
	var cue_box := _hbox("CueBox")
	_cue_panel.add_child(cue_box)
	_cue_icon = _icon("CueIcon", "")
	cue_box.add_child(_cue_icon)
	_cue_label = _label("CueLabel", int(_cfg.get("cue_font_size", 1)))
	cue_box.add_child(_cue_label)
	_cue_panel.visible = false

	_banner = _panel("FinishBanner")
	_root.add_child(_banner)
	var banner_box := _hbox("BannerBox")
	_banner.add_child(banner_box)
	_banner_label = _label("BannerLabel", int(_cfg.get("banner_font_size", 1)))
	_banner_label.add_theme_color_override("font_color", ArtPalette.color("ui_accent"))
	banner_box.add_child(_banner_label)
	_banner_key = KEY_CAP_SCENE.instantiate()
	_banner_key.name = "FinishKey"
	_banner_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	banner_box.add_child(_banner_key)
	_banner_key.set_action(&"finish")
	_banner.visible = false

	_prompt = _panel("InteractPrompt")
	_root.add_child(_prompt)
	var prompt_box := _hbox("PromptBox")
	_prompt.add_child(prompt_box)
	_prompt_key = KEY_CAP_SCENE.instantiate()
	_prompt_key.name = "InteractKey"
	_prompt_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prompt_box.add_child(_prompt_key)
	_prompt_key.set_action(&"interact")
	_verb_label = _label("VerbLabel", int(_cfg.get("font_size", 1)))
	prompt_box.add_child(_verb_label)
	_prompt.visible = false
	_relabel_all()


func _panel(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	var bg := ArtPalette.color("ui_panel")
	bg.a = float(_cfg.get("panel_alpha", 1.0))
	style.bg_color = bg
	style.set_corner_radius_all(int(_cfg.get("panel_corner_px", 0)))
	style.set_content_margin_all(float(_cfg.get("panel_padding_px", 0)))
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _hbox(node_name: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.name = node_name
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", int(_cfg.get("row_separation_px", 0)))
	return box


func _label(node_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", ArtPalette.color("ui_text"))
	label.add_theme_font_size_override("font_size", font_size)
	if _font != null:
		label.add_theme_font_override("font", _font)
	return label


func _icon(node_name: String, path: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var s := float(_cfg.get("icon_size_px", 1))
	rect.custom_minimum_size = Vector2(s, s)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if path != "":
		rect.texture = load(path)
	return rect


func _text_width(text: String, font_size: int) -> float:
	if _font == null:
		return 0.0
	return ceilf(_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + 2.0


func _build_rows(tasks: Array) -> void:
	for row in _rows:
		(row["box"] as Node).queue_free()
		_task_list.remove_child(row["box"])
	_rows.clear()
	var font_size := int(_cfg.get("font_size", 1))
	for i in tasks.size():
		var task: Dictionary = tasks[i]
		var box := _hbox("Row%d" % i)
		_task_list.add_child(box)
		var mark := _icon("MarkIcon", STAR_FULL if bool(task.get("required", false)) else STAR_EMPTY)
		box.add_child(mark)
		var tag := _label("TagLabel", int(_cfg.get("tag_font_size", font_size)))
		tag.add_theme_color_override("font_color",
				ArtPalette.color("ui_accent" if bool(task.get("required", false)) else "ui_text"))
		box.add_child(tag)
		var name_label := _label("NameLabel", int(_cfg.get("task_font_size", font_size)))
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.max_lines_visible = int(_cfg.get("task_name_max_lines", 1))
		name_label.custom_minimum_size = Vector2(float(_cfg.get("task_name_width_px", 1)), 0.0)
		box.add_child(name_label)
		var progress := _label("ProgressLabel", font_size)
		progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		progress.custom_minimum_size = Vector2(maxf(float(_cfg.get("progress_min_width_px", 1)),
				_text_width(DIGITS_SAMPLE, font_size)), 0.0)
		box.add_child(progress)
		var state_icon := _icon("StateIcon", "")
		box.add_child(state_icon)
		_rows.append({"box": box, "id": String(task.get("id", "")), "title_key": HudModel.task_title_key(task),
				"required": bool(task.get("required", false)), "mark": mark, "tag": tag, "name": name_label,
				"progress": progress, "state": state_icon, "text": ""})
	_relabel_all()


# --- Binding and refresh -----------------------------------------------------------------------------------

## Connects the HUD to a loaded level (called by LevelBase once the session exists).
func bind_level(level: Node) -> void:
	_level = level
	_session = level.call("level_session")
	_def = level.call("level_def")
	_castaway = level.call("castaway")
	_warn_seconds = float(Balance.get_section("rules").get("timer_warning_seconds", 0.0))
	var types: Dictionary = LevelDef.load_event_types()["types"]
	_model = HudModel.new(config(), EntityDefs.animal_kinds(), EntityDefs.item_kinds(),
			HudModel.event_effects_for(_session.schedule(), types), _def.tasks)
	_sample_mode = false
	_build_rows(_def.tasks)
	if _castaway != null and _castaway.has_method("get_interact_verb"):
		_on_verb_changed(String(_castaway.call("get_interact_verb")), "")
	_reduce = FxSettings.read_reduce(DataDir.file(FxSettings.FILE))
	visible = true
	refresh()
	force_layout()


## Parsed data/hud.json (cached; load errors are pushed once).
static func config() -> Dictionary:
	if _config_cache.is_empty():
		var res := HudModel.load_config(HudModel.CONFIG_PATH, EventBus, {})
		for line in res["errors"]:
			push_error("Hud: %s" % line)
		_config_cache = res["config"]
	return _config_cache


## Re-reads the session into the rows, timer, star goal, warning state and banner.
func refresh() -> void:
	if _session == null or _sample_mode:
		return
	var progress := _session.task_progress()
	for i in mini(progress.size(), _rows.size()):
		var row: Dictionary = _rows[i]
		var st: Dictionary = progress[i]
		var text := "%d/%d" % [int(st["current"]), int(st["target"])]
		if row["text"] != text:
			row["text"] = text
			(row["progress"] as Label).text = text
		var state_icon := row["state"] as TextureRect
		var path := ICON_DONE if st["done"] else (ICON_MISSED if st["missed"] else "")
		var want: Texture2D = load(path) if path != "" else null
		if state_icon.texture != want:
			state_icon.texture = want
		(row["name"] as Label).modulate.a = 0.5 if st["done"] or st["missed"] else 1.0
	var left := _session.time_left()
	_set_text(_timer_label, HudModel.format_time(left))
	var goal := _session.three_star_time()
	_set_text(_star_label, HudModel.format_time(goal))
	var reachable := HudModel.star_goal_reachable(left, goal)
	_star_icon.texture = load(STAR_FULL if reachable else STAR_EMPTY)
	_star_state.texture = load(ICON_DONE if reachable else ICON_MISSED)
	var state := _session.get_state()
	_set_warning(HudModel.is_warning(left, _warn_seconds, state))
	_banner.visible = state == LevelSession.State.REQUIRED_DONE


func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


func _set_warning(on: bool) -> void:
	if on == _warning:
		return
	_warning = on
	_pulse_time = 0.0
	_timer_label.add_theme_color_override("font_color", ArtPalette.color("ui_warning" if on else "ui_text"))
	if not on:
		_timer_label.scale = Vector2.ONE


func _process(delta: float) -> void:
	_clock += delta
	refresh()
	if _hint_panel.visible and not _sample_mode:
		_hint_left -= delta
		if _hint_left <= 0.0:
			hide_hint()
	if _cue_panel.visible and not _sample_mode and _throttle.visible_key(_clock) == "":
		_hide_cue()
	_pulse(delta)
	force_layout()
	_fade(delta)


func _pulse(delta: float) -> void:
	if not is_pulsing():
		return
	_pulse_time += delta
	var period := maxf(float(_cfg.get("warning_pulse_period", 1.0)), 0.01)
	var amp := float(_cfg.get("warning_pulse_scale", 1.0)) - 1.0
	var s := 1.0 + amp * (0.5 + 0.5 * sin(_pulse_time * TAU / period))
	_timer_label.pivot_offset = _timer_label.size / 2.0
	_timer_label.scale = Vector2(s, s)


# --- Hint ---------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("hint") and not event.is_echo():
		if show_hint():
			get_viewport().set_input_as_handled()


## Shows the hint of the first unfinished task (required first) for hud.hint_seconds; the timer keeps running.
func show_hint() -> bool:
	if _session == null or get_tree().paused:
		return false
	var state := _session.get_state()
	if state == LevelSession.State.PAUSED or state == LevelSession.State.WON or state == LevelSession.State.LOST:
		return false
	_hint_key = HudModel.select_hint(_def.tasks, _session.task_progress())
	_hint_left = float(_cfg.get("hint_seconds", 1.0))
	_hint_label.text = _text(_hint_key)
	_hint_panel.visible = true
	force_layout()
	return true


func hide_hint() -> void:
	_hint_panel.visible = false
	_hint_key = ""
	_hint_left = 0.0


func hint_visible() -> bool:
	return _hint_panel.visible


func hint_key() -> String:
	return _hint_key if _hint_panel.visible else ""


func hint_seconds_left() -> float:
	return _hint_left


func hint_button() -> TextureButton:
	return _hint_button


# --- Cues ---------------------------------------------------------------------------------------------

func _on_entity_lost(kind: String, reason: String) -> void:
	on_failure_signal("entity_lost", [kind, reason])


func _on_level_lost(level_id: String, open_tasks: Array) -> void:
	_on_level_ended()
	on_failure_signal("level_lost", [level_id, open_tasks])


func _on_dizzy_started(cause: String) -> void:
	on_failure_signal("castaway_dizzy_started", [cause])


func _on_event_triggered(event_id: String) -> void:
	on_failure_signal("event_triggered", [event_id])


func _on_animal_fled(kind: String) -> void:
	on_failure_signal("animal_fled", [kind])


## Classifies one EventBus signal and shows its cue (public for tests and future emitters).
func on_failure_signal(signal_name: String, args: Array) -> void:
	if _session == null:
		return
	var ctx := {"player_held": "", "player_worn": "", "progress": _session.task_progress()}
	if _castaway != null and is_instance_valid(_castaway):
		if _castaway.has_method("get_carried"):
			var carried: Variant = _castaway.call("get_carried")
			if carried is Object and is_instance_valid(carried) and "kind" in carried:
				ctx["player_held"] = String(carried.get("kind"))
		if _castaway.has_method("get_worn_kind"):
			ctx["player_worn"] = String(_castaway.call("get_worn_kind"))
	var cue := _model.classify(signal_name, args, ctx)
	if cue.is_empty():
		return
	_show_cue(String(cue["key"]), String(cue.get("icon", "")), _model.is_priority(String(cue["type"])))


## Event warning: a short "watch out" cue naming the coming event (hud.cue.warn.<event_type>).
func _on_event_warning(_event_id: String, event_type: String, _seconds_until: float) -> void:
	if _session == null or not I18n.has_key(WARN_KEY_PREFIX + event_type):
		return
	_show_cue(WARN_KEY_PREFIX + event_type, ICON_WARN, false)


func _show_cue(key: String, icon: String, priority: bool) -> void:
	var result := _throttle.offer(key, _clock, priority)
	if result == HudModel.CueThrottle.Result.BLOCKED:
		return
	_cue_key = key
	_cue_icon.texture = load(icon) if icon != "" and ResourceLoader.exists(icon) else null
	_apply_cue_text()
	_cue_panel.visible = true
	force_layout()


func _apply_cue_text() -> void:
	_cue_label.text = _text(_cue_key)
	var size_max := int(_cfg.get("cue_font_size", 1))
	var size_min := int(_cfg.get("cue_min_font_size", size_max))
	var limit := float(_cfg.get("cue_max_width_px", 1)) - float(_cfg.get("icon_size_px", 0)) \
			- float(_cfg.get("row_separation_px", 0)) - float(_cfg.get("panel_padding_px", 0)) * 2.0
	var font_size := size_max
	while font_size > size_min and _text_width(_cue_label.text, font_size) > limit:
		font_size -= 1
	_cue_label.add_theme_font_size_override("font_size", font_size)


func _hide_cue() -> void:
	_cue_panel.visible = false
	_cue_key = ""


func current_cue_key() -> String:
	return _cue_key if _cue_panel.visible else ""


# --- Prompt, banner, restart ------------------------------------------------------------------------------

func _on_verb_changed(verb: String, _target_kind: String) -> void:
	_verb = verb
	var verbs: Dictionary = config().get("verbs", {})
	_prompt.visible = verbs.has(verb)
	if _prompt.visible:
		_verb_label.text = _text(String(verbs[verb]))
		force_layout()


func prompt_verb() -> String:
	return _verb if _prompt.visible else "none"


func banner_visible() -> bool:
	return _banner.visible


func _on_level_restarted(_level_id: String) -> void:
	hide_hint()
	_hide_cue()
	_throttle.clear()
	_set_warning(false)
	_banner.visible = false
	refresh()


func _on_level_ended() -> void:
	hide_hint()
	_banner.visible = false
	# The flow pauses the tree on the result screen, so the last progress is drawn here and not in _process.
	refresh()


func _on_settings_changed(_key: String) -> void:
	reload_settings()


## Re-reads the reduce motion toggle from settings.json (pulse off, colour stays).
func reload_settings() -> void:
	_reduce = FxSettings.read_reduce(DataDir.file(FxSettings.FILE))
	if _reduce:
		_timer_label.scale = Vector2.ONE


func is_warning() -> bool:
	return _warning


func is_pulsing() -> bool:
	return _warning and not _reduce


func timer_label() -> Label:
	return _timer_label


# --- Texts -------------------------------------------------------------------------------------------

## Translation of a key: HUD keys from I18n, level keys through the level's catalogue.
func _text(key: String) -> String:
	if _level != null and _level.has_method("text"):
		return String(_level.call("text", key))
	return I18n.t(key)


func _relabel_all() -> void:
	_hint_button.tooltip_text = I18n.t(HINT_BUTTON_KEY)
	_timer_panel.tooltip_text = I18n.t(STAR_GOAL_KEY)
	_star_caption.text = I18n.t(STAR_GOAL_KEY)
	_banner_label.text = I18n.t(BANNER_KEY)
	var tag_width := 0.0
	for key in [REQUIRED_KEY, OPTIONAL_KEY]:
		tag_width = maxf(tag_width, _text_width(I18n.t(key), int(_cfg.get("tag_font_size", 1))))
	for row in _rows:
		(row["name"] as Label).text = _text(row["title_key"])
		var tag := row["tag"] as Label
		tag.text = I18n.t(REQUIRED_KEY if row["required"] else OPTIONAL_KEY)
		tag.custom_minimum_size = Vector2(tag_width, 0.0)
	if _hint_key != "":
		_hint_label.text = _text(_hint_key)
	if _cue_key != "":
		_apply_cue_text()
	var verbs: Dictionary = config().get("verbs", {})
	if verbs.has(_verb):
		_verb_label.text = _text(String(verbs[_verb]))
	force_layout()


func _on_locale_changed(_code: String) -> void:
	_relabel_all()


## [[Control, key], ...] of every visible translated text (tests compare them with the catalogue).
func text_bindings() -> Array:
	var out: Array = []
	for row in _rows:
		out.append([row["name"], row["title_key"]])
		out.append([row["tag"], REQUIRED_KEY if row["required"] else OPTIONAL_KEY])
	out.append([_star_caption, STAR_GOAL_KEY])
	if _hint_panel.visible:
		out.append([_hint_label, _hint_key])
	if _cue_panel.visible:
		out.append([_cue_label, _cue_key])
	if _banner.visible:
		out.append([_banner_label, BANNER_KEY])
	if _prompt.visible:
		out.append([_verb_label, String(config().get("verbs", {}).get(_verb, ""))])
	for cap in [_banner_key, _prompt_key]:
		if cap.is_visible_in_tree() and cap.bound_key() != "":
			out.append([cap.label(), cap.bound_key()])
	return out


## True for texts that need no translation: m:ss, n/n and raw key glyphs.
static func is_untranslated_ok(text: String) -> bool:
	var re := RegEx.create_from_string("^(\\d+:\\d\\d|\\d+/\\d+)$")
	if re.search(text) != null:
		return true
	return RegEx.create_from_string(GLYPH_RE).search(text) != null and text.to_upper() == text


func task_rows() -> Array:
	return _rows.duplicate()


func root_control() -> Control:
	return _root


# --- Layout and occlusion -------------------------------------------------------------------------------

## Uses a fixed visible area for the layout (tests); Vector2.ZERO follows the viewport again.
func set_layout_size(view: Vector2) -> void:
	_layout_size = view
	force_layout()


func _view_size() -> Vector2:
	return _layout_size if _layout_size != Vector2.ZERO else get_viewport().get_visible_rect().size


func _base_size() -> Vector2:
	return Vector2(float(_cfg.get("base_width_px", 1)), float(_cfg.get("base_height_px", 1)))


## Lays out the panels at the screen edges in logical base coordinates, scaled uniformly to the visible area
## (the same rule as the project's canvas_items stretch).
func force_layout() -> void:
	if _root == null:
		return
	var view := _view_size()
	var base := _base_size()
	var s := minf(view.x / base.x, view.y / base.y)
	var area := view / s
	_root.scale = Vector2(s, s)
	_root.size = area
	_root.position = Vector2.ZERO
	var m := float(_cfg.get("margin_px", 0))
	_fit(_top_left)
	_top_left.position = Vector2(m, m)
	_fit(_timer_panel)
	_timer_panel.position = Vector2(area.x - m - _timer_panel.size.x, m)
	_fit(_cue_panel)
	var cue_top := maxf(float(_cfg.get("cue_top_px", 0)), m + _timer_panel.size.y + float(_cfg.get("row_separation_px", 0)))
	_cue_panel.position = Vector2(area.x - m - _cue_panel.size.x, cue_top)
	_fit(_prompt)
	_prompt.position = Vector2((area.x - _prompt.size.x) / 2.0,
			area.y - float(_cfg.get("prompt_bottom_px", 0)) - _prompt.size.y)
	_fit(_banner)
	_banner.position = Vector2((area.x - _banner.size.x) / 2.0,
			area.y - float(_cfg.get("banner_bottom_px", 0)) - _banner.size.y)


func _fit(c: Control) -> void:
	c.size = Vector2.ZERO
	c.size = c.get_combined_minimum_size()


func _panels() -> Array:
	return [_task_panel, _hint_button, _hint_panel, _timer_panel, _cue_panel, _banner, _prompt]


## Global rects of the visible HUD panels (same space as castaway_screen_rect()).
func visible_panel_rects() -> Array:
	var out: Array = []
	for p in _panels():
		if (p as Control).is_visible_in_tree():
			out.append((p as Control).get_global_rect())
	return out


## Named visible panels {name: Rect2} (tests).
func panel_rects() -> Dictionary:
	var out := {}
	for p in _panels():
		if (p as Control).is_visible_in_tree():
			out[String((p as Control).name)] = (p as Control).get_global_rect()
	return out


func panel(node_name: String) -> Control:
	return _root.find_child(node_name, true, false) as Control


## Pins the castaway screen rect for tests (Rect2() follows the castaway again).
func force_castaway_rect(rect: Rect2) -> void:
	_forced_castaway_rect = rect


## Screen rect of the castaway sprite in HUD coordinates (empty without a castaway).
func castaway_screen_rect() -> Rect2:
	if _forced_castaway_rect.size != Vector2.ZERO:
		return _forced_castaway_rect
	if _castaway == null or not is_instance_valid(_castaway) or not _castaway.is_inside_tree():
		return Rect2()
	var body := _castaway.get_node_or_null("Visual/Body") as Sprite2D
	var rect := Rect2(_castaway.get_global_transform_with_canvas().origin, Vector2.ZERO)
	if body != null and body.texture != null:
		rect = body.get_global_transform_with_canvas() * body.get_rect()
	var real := get_viewport().get_visible_rect().size
	if _layout_size != Vector2.ZERO and real.x > 0.0 and real.y > 0.0:
		var k := _layout_size / real
		rect = Rect2(rect.position * k, rect.size * k)
	return rect


## Castaway rect grown by the safe margin (scaled like the HUD).
func castaway_safe_rect() -> Rect2:
	var rect := castaway_screen_rect()
	if rect.size == Vector2.ZERO:
		return rect
	return rect.grow(float(_cfg.get("castaway_safe_margin_px", 0)) * _root.scale.x)


func _fade(delta: float) -> void:
	var safe := castaway_safe_rect()
	var low := float(_cfg.get("occlude_alpha", 1.0))
	var step := (1.0 - low) / maxf(float(_cfg.get("occlude_fade_seconds", 0.0)), 0.001) * delta
	for p in _panels():
		var c := p as Control
		var target := 1.0
		if safe.size != Vector2.ZERO and c.is_visible_in_tree() and c.get_global_rect().intersects(safe):
			target = low
		c.modulate.a = move_toward(c.modulate.a, target, step)


func panel_alpha(node_name: String) -> float:
	var c := panel(node_name)
	return c.modulate.a if c != null else 1.0


# --- Overflow sample ----------------------------------------------------------------------------------

## Fills the HUD with its longest content for the overflow check: five task rows (title_keys, or the longest
## current titles), wide progress digits, the longest hint, cue and verb, the banner and the prompt; freezes it.
func overflow_sample(title_keys: Array = [], hint_key_override: String = "") -> void:
	_sample_mode = true
	var keys := title_keys.duplicate()
	if keys.is_empty():
		for row in _rows:
			keys.append(row["title_key"])
	keys.sort_custom(func(a: String, b: String) -> bool: return _text(a).length() > _text(b).length())
	var tasks: Array = []
	var max_rows := int(Balance.get_section("rules").get("tasks_max", 1))
	for i in max_rows:
		var key: String = keys[i % keys.size()] if not keys.is_empty() else BANNER_KEY
		tasks.append({"id": "sample_%d" % i, "required": i % 2 == 0, "title_key": key, "hint_key": key})
	_build_rows(tasks)
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		(row["progress"] as Label).text = DIGITS_SAMPLE
		(row["state"] as TextureRect).texture = load(ICON_DONE if i % 2 == 0 else ICON_MISSED)
	_timer_label.text = HudModel.format_time(float(Balance.get_section("rules").get("timer_max_seconds", 0)))
	_star_label.text = _timer_label.text
	_hint_key = hint_key_override if hint_key_override != "" else _longest(keys + [HudModel.NO_HINT_KEY])
	_hint_label.text = _text(_hint_key)
	_hint_panel.visible = true
	var cue_keys: Array = []
	var types: Dictionary = config().get("failure_types", {})
	for type_name in types:
		cue_keys.append(String(types[type_name].get("key", "")))
	if _def != null:
		for task in _def.tasks:
			cue_keys.append(String(task.get("fail_key", "")))
	_cue_key = _longest(cue_keys)
	_apply_cue_text()
	_cue_icon.texture = load(ICON_HINT)
	_cue_panel.visible = true
	_banner.visible = true
	var verbs: Dictionary = config().get("verbs", {})
	_verb = "grab"
	for verb in verbs:
		if _text(String(verbs[verb])).length() > _text(String(verbs[_verb])).length():
			_verb = verb
	_verb_label.text = _text(String(verbs.get(_verb, "")))
	_prompt.visible = true
	force_layout()


func _longest(keys: Array) -> String:
	var best := ""
	for key in keys:
		if best == "" or _text(String(key)).length() > _text(best).length():
			best = String(key)
	return best
