class_name SmokeContent
extends RefCounted
## Content check of the smoke mode: every animal and item sprite loads and every campaign level builds with only known kinds.

## Returns "" when all sprites load and all levels instantiate with resolved kinds, else the first problem found.
static func problem(host: Node) -> String:
	for kind in EntityDefs.animal_kinds():
		var reason := _sprite_problem("animal %s" % kind, EntityDefs.get_animal(kind))
		if reason != "":
			return reason
	for kind in EntityDefs.item_kinds():
		var reason := _sprite_problem("item %s" % kind, EntityDefs.get_item(kind))
		if reason != "":
			return reason
	for level_id in Progress.campaign().ids():
		var reason := await _level_problem(host, String(level_id))
		if reason != "":
			return reason
	return ""


static func _sprite_problem(label: String, def: Dictionary) -> String:
	var path := String(def.get("sprite", ""))
	if path == "" or not ResourceLoader.exists(path) or not load(path) is Texture2D:
		return "%s sprite missing: %s" % [label, path]
	return ""


static func _level_problem(host: Node, level_id: String) -> String:
	var entry: Dictionary = Progress.campaign().entry(level_id)
	var scene := load(String(entry["scene"])) as PackedScene
	if scene == null:
		return "level %s scene missing: %s" % [level_id, entry["scene"]]
	var level := scene.instantiate()
	host.add_child(level)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var reason := _kind_problem(level, level_id)
	host.remove_child(level)
	level.free()
	return reason


static func _kind_problem(node: Node, level_id: String) -> String:
	if node is Animal or node is Item:
		var def: Dictionary = node.get("def")
		if def.is_empty():
			return "level %s: unknown kind %s" % [level_id, node.get("kind")]
		var reason := _sprite_problem("level %s kind %s" % [level_id, node.get("kind")], def)
		if reason != "":
			return reason
	for child in node.get_children():
		var reason := _kind_problem(child, level_id)
		if reason != "":
			return reason
	return ""
