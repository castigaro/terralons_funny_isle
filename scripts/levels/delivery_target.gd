class_name DeliveryTarget
extends UseTargetBase
## Use target that takes a carried item as a delivery (for example coconuts for the monkey, a bucket for the
## trough): reports it to the session (delivered_to conditions) and sends the item back to its home point, so
## deliveries can repeat. As a child of an animal it rides along and takes the animal's kind.


func use(obj: Object) -> void:
	var lvl := level()
	if lvl != null:
		lvl.report_delivery(String(obj.get("kind")), target_kind)
	EventBus.fx_anchor.emit(String(obj.get("kind")), global_position)
	if obj.has_method("reset_to_home"):
		obj.call("reset_to_home")
