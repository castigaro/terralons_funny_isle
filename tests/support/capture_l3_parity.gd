extends SceneTree
## One-off fixture tool: loads the shipped Jungle level and writes its gameplay parity snapshot to
## tests/fixtures/levels/l3_parity.json (run once on the unchanged scene of main).
## Usage: godot --headless --path . --script res://tests/support/capture_l3_parity.gd

const PARITY := "res://tests/support/level_parity.gd"
const LEVEL := "res://scenes/levels/l3_jungle.tscn"
const OUT := "res://tests/fixtures/levels/l3_parity.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var parity: Script = load(PARITY)
	var level: Node = (load(LEVEL) as PackedScene).instantiate()
	level.set("autostart", false)
	root.add_child(level)
	await physics_frame
	await physics_frame
	var snapshot: Dictionary = parity.call("collect", level)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(snapshot, "\t") + "\n")
	f.close()
	print("PARITY written %s (%d solids)" % [OUT, snapshot["solids"].size()])
	level.queue_free()
	await process_frame
	quit(0)
