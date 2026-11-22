extends RefCounted
## Reusable clip check for UI trees (menus, HUD): check_tree() reports every visible Label, Button (CheckBox) and
## RichTextLabel whose text does not fit: single-line text width plus stylebox margins plus icon must fit the width,
## wrapping text must fit the height, active clipping or trimming with overflow fails, and the rect must stay inside
## the viewport, every clip_contents ancestor, the nearest PanelContainer (its visible frame) and an enclosing
## Button (tile children). Visible sibling controls of a non-container parent must not overlap.

const WIDTH_SLACK := 0.5
const HEIGHT_SLACK := 1.0


## Returns one message per problem (empty = pass).
static func check_tree(root: Node, label: String, locale: String, viewport: Rect2) -> Array[String]:
	var errors: Array[String] = []
	_walk(root, "%s [%s]" % [label, locale], viewport, errors)
	return errors


static func _walk(node: Node, where: String, viewport: Rect2, errors: Array[String]) -> void:
	if node is Control and (node as Control).is_visible_in_tree():
		_check_control(node, where, viewport, errors)
		if not node is Container:
			_check_overlap(node, where, errors)
	for child in node.get_children():
		_walk(child, where, viewport, errors)


static func _check_control(c: Control, label: String, viewport: Rect2, errors: Array[String]) -> void:
	var text := ""
	if c is Label or c is Button or c is RichTextLabel:
		text = String(c.get("text"))
	if text == "":
		return
	var where := "%s %s" % [label, str(c.get_path())]
	var rect := c.get_global_rect()
	if not viewport.grow(WIDTH_SLACK).encloses(rect):
		errors.append("%s: rect %s leaves the viewport %s" % [where, rect, viewport])
	var parent := c.get_parent()
	var framed := false
	var in_button := false
	while parent != null:
		if parent is Control:
			var p := parent as Control
			var prect := p.get_global_rect().grow(WIDTH_SLACK)
			if p.clip_contents and not prect.encloses(rect):
				errors.append("%s: rect %s is clipped by %s" % [where, rect, p.name])
			if not framed and p is PanelContainer:
				framed = true
				if not prect.encloses(rect):
					errors.append("%s: rect %s sticks out of its panel %s" % [where, rect, p.get_global_rect()])
			if not in_button and p is Button:
				in_button = true
				if not prect.encloses(rect):
					errors.append("%s: rect %s sticks out of its button %s" % [where, rect, p.get_global_rect()])
		parent = parent.get_parent()
	if c is RichTextLabel:
		_check_rich(c, where, errors)
	elif c is Label:
		_check_label(c, text, where, errors)
	elif c is Button:
		_check_button(c, text, where, errors)


static func _widest_line(font: Font, text: String, fs: int) -> float:
	var widest := 0.0
	for line in text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return widest


static func _check_label(label: Label, text: String, where: String, errors: Array[String]) -> void:
	var font := label.get_theme_font("font")
	var fs := label.get_theme_font_size("font_size")
	var sb := label.get_theme_stylebox("normal")
	var margins := sb.get_minimum_size() if sb != null else Vector2.ZERO
	var line_h := font.get_height(fs)
	var spacing := float(label.get_theme_constant("line_spacing"))
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		if label.size.x < 1.0:
			errors.append("%s: wrapping label collapsed" % where)
			return
		var lines := label.get_line_count()
		var need_h := lines * line_h + maxi(lines - 1, 0) * spacing + margins.y
		if need_h > label.size.y + HEIGHT_SLACK:
			errors.append("%s: wrapped text needs height %.1f, has %.1f" % [where, need_h, label.size.y])
		if label.max_lines_visible >= 0 and lines > label.max_lines_visible:
			errors.append("%s: %d lines but max_lines_visible %d" % [where, lines, label.max_lines_visible])
		for word in text.split(" "):
			if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + margins.x > label.size.x + WIDTH_SLACK:
				errors.append("%s: word '%s' is wider than the label" % [where, word])
		return
	var width := _widest_line(font, text, fs) + margins.x
	var trimming := label.clip_text or label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
	if width > label.size.x + WIDTH_SLACK:
		errors.append("%s: text '%s' needs width %.1f, has %.1f%s" % [where, text, width, label.size.x,
				" (clipped or trimmed)" if trimming else ""])
	var lines_n := text.split("\n").size()
	var height := lines_n * line_h + maxi(lines_n - 1, 0) * spacing + margins.y
	if height > label.size.y + HEIGHT_SLACK:
		errors.append("%s: text needs height %.1f, has %.1f" % [where, height, label.size.y])


static func _check_button(button: Button, text: String, where: String, errors: Array[String]) -> void:
	var font := button.get_theme_font("font")
	var fs := button.get_theme_font_size("font_size")
	var sb := button.get_theme_stylebox("normal")
	var margins := sb.get_minimum_size() if sb != null else Vector2.ZERO
	var icon: Texture2D = button.icon
	if button is CheckBox or button is CheckButton:
		icon = button.get_theme_icon("checked" if button.button_pressed else "unchecked")
	var extra := 0.0
	if icon != null:
		var icon_w := float(icon.get_width())
		var max_w := button.get_theme_constant("icon_max_width")
		if max_w > 0:
			icon_w = minf(icon_w, float(max_w))
		extra = icon_w + button.get_theme_constant("h_separation")
	var width := _widest_line(font, text, fs) + margins.x + extra
	var trimming := button.clip_text or button.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
	if width > button.size.x + WIDTH_SLACK:
		errors.append("%s: text '%s' needs width %.1f, has %.1f%s" % [where, text, width, button.size.x,
				" (clipped or trimmed)" if trimming else ""])
	var height := font.get_height(fs) * text.split("\n").size() + margins.y
	if height > button.size.y + HEIGHT_SLACK:
		errors.append("%s: text needs height %.1f, has %.1f" % [where, height, button.size.y])


static func _check_rich(rich: RichTextLabel, where: String, errors: Array[String]) -> void:
	if rich.fit_content:
		return
	if float(rich.get_content_height()) > rich.size.y + HEIGHT_SLACK:
		errors.append("%s: rich text needs height %d, has %.1f" % [where, rich.get_content_height(), rich.size.y])


## Visible Control children of a non-container parent must not overlap (layout bugs hide text behind text).
static func _check_overlap(parent: Control, where: String, errors: Array[String]) -> void:
	var kids: Array = []
	for child in parent.get_children():
		if child is Control and (child as Control).is_visible_in_tree() and _has_text(child):
			kids.append(child)
	for i in kids.size():
		for j in range(i + 1, kids.size()):
			var a: Rect2 = (kids[i] as Control).get_global_rect()
			var b: Rect2 = (kids[j] as Control).get_global_rect()
			if a.grow(-WIDTH_SLACK).intersects(b.grow(-WIDTH_SLACK)):
				errors.append("%s %s: %s overlaps %s" % [where, str(parent.get_path()), kids[i].name, kids[j].name])


static func _has_text(node: Node) -> bool:
	if (node is Label or node is Button or node is RichTextLabel) and String(node.get("text")) != "":
		return true
	for child in node.get_children():
		if _has_text(child):
			return true
	return false


## Visible world prompt bubbles (ContextPrompt) must not sit under a visible HUD panel.
static func check_hud_prompts(hud: Hud, prompts: Array, label: String) -> Array[String]:
	var errors: Array[String] = []
	var panels := hud.panel_rects()
	for p in prompts:
		if not is_instance_valid(p) or not (p as Node2D).is_visible_in_tree():
			continue
		var bubble := (p as ContextPrompt).bubble()
		if bubble == null:
			continue
		var rect := hud.screen_rect_of(bubble, Rect2(Vector2.ZERO, bubble.size))
		for panel_name: String in panels:
			var prect: Rect2 = panels[panel_name]
			if rect.grow(-WIDTH_SLACK).intersects(prect.grow(-WIDTH_SLACK)):
				errors.append("%s: prompt %s %s overlaps HUD panel %s %s" % [label, (p as ContextPrompt).prompt_id,
						rect, panel_name, prect])
	return errors
