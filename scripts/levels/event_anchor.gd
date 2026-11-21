class_name EventAnchor
extends Marker2D
## Marks where a level event happens: the FeedbackDirector plays the event_zone entries here and EventEffects
## starts and ends the event actors here. One anchor per event, below the level node EventAnchors.

## Id of the level event (the node name by default).
@export var event_id := ""


func _enter_tree() -> void:
	if event_id == "":
		event_id = String(name)
	add_to_group(FeedbackDirector.EVENT_ANCHOR_GROUP)
