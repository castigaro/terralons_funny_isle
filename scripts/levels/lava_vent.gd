class_name LavaVent
extends Node2D
## Decorative volcanic vent on rock: rising smoke, a few sparks and a pulsing glow; the sparks stay off under
## "reduce screen shake and flashes", the smoke keeps drifting. No physics, no gameplay.

@onready var smoke: CPUParticles2D = $Smoke
@onready var sparks: CPUParticles2D = $Sparks


func _ready() -> void:
	if FxSettings.read_reduce(_settings_path()):
		sparks.emitting = false


## Sum of the particle amounts of every emitting CPUParticles2D below root (the live particle budget).
static func live_budget(root: Node) -> int:
	var total := 0
	for node in root.find_children("*", "CPUParticles2D", true, false):
		if (node as CPUParticles2D).emitting:
			total += (node as CPUParticles2D).amount
	return total


func _settings_path() -> String:
	var data_dir := get_node_or_null("/root/DataDir")
	return String(data_dir.call("file", FxSettings.FILE)) if data_dir != null else ""
