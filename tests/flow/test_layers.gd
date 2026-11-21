extends "res://tests/support/flow_case.gd"
## Canvas layer order: the menus sit above the HUD, the announcer caption and the level error panel.


func test_menu_layer_is_on_top() -> void:
	await open_flow("layers")
	var ui_layer := flow.get_node("UiLayer") as CanvasLayer
	var menus := Balance.get_int("flow", "ui_layer")
	check_eq(ui_layer.layer, menus, "UiLayer uses Balance flow ui_layer")
	var hud := Balance.get_int("hud", "layer")
	var caption := Balance.get_int("audio", "caption_layer")
	var panel := (load("res://scenes/ui/level_error_panel.tscn") as PackedScene).instantiate()
	var error_layer := -1
	if panel is CanvasLayer:
		error_layer = (panel as CanvasLayer).layer
	else:
		for child in panel.get_children():
			if child is CanvasLayer:
				error_layer = (child as CanvasLayer).layer
	panel.free()
	check(error_layer > 0, "error panel layer found")
	check(menus > hud, "menus above the HUD")
	check(menus > caption, "menus above the caption")
	check(menus > error_layer, "menus above the level error panel")
