extends SceneTree
## One-off fixture tool: loads the shipped Volcano Cliffs level and writes the surface (get_surface_at) of every
## layout cell centre to tests/fixtures/levels/l5_surfaces.json (run once on the undressed scene of main).
## Usage: godot --headless --path . --script res://tests/support/capture_l5_surfaces.gd

const LEVEL := "res://scenes/levels/l5_volcano_cliffs.tscn"
const LAYOUT := "res://scenes/levels/layouts/l5_volcano_cliffs.layout.txt"
const OUT := "res://tests/fixtures/levels/l5_surfaces.json"
const CELL := 128


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node = (load(LEVEL) as PackedScene).instantiate()
	level.set("autostart", false)
	root.add_child(level)
	await process_frame
	var surfaces := collect(level, FileAccess.get_file_as_string(LAYOUT))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(surfaces, "\t", true) + "\n")
	f.close()
	print("SURFACES written %s (%d cells)" % [OUT, surfaces.size()])
	level.queue_free()
	await process_frame
	quit(0)


## {"x,y": surface} for every cell of the layout grid, sampled at the cell centre.
static func collect(level: Node, layout_text: String) -> Dictionary:
	var rows := layout_text.replace("\r", "").split("\n", false)
	var out := {}
	for y in rows.size():
		for x in rows[y].length():
			var centre := Vector2(x * CELL + CELL / 2.0, y * CELL + CELL / 2.0)
			out["%d,%d" % [x, y]] = String(level.call("get_surface_at", centre))
	return out
