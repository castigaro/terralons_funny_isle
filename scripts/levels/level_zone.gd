class_name LevelZone
extends Area2D
## Named task zone of a level: the node name is the zone id used by in_zone conditions.
## Membership is queried through the physics space (LevelBase.zones_at), never through body_entered.


func _ready() -> void:
	collision_layer = PhysicsLayers.ZONES
	collision_mask = 0
	monitoring = false
	monitorable = true


func zone_id() -> String:
	return String(name)
