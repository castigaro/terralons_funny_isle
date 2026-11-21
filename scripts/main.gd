extends Node
## Entry scene stub; supports the headless smoke mode (-- --smoke).


func _ready() -> void:
	if "--smoke" in OS.get_cmdline_user_args():
		print("SMOKE OK")
		get_tree().quit(0)
