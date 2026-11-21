class_name CastawayStep
extends RefCounted
## Result of one CastawayLogic tick that the scene shell carries out.

const MODE_WALK := "walk"
const MODE_BURST := "burst"

var velocity := Vector2.ZERO
## "walk" (slide along obstacles) or "burst" (dash or knockback, stops at the first obstacle).
var mode := MODE_WALK
## "none", "grab", "use" or "throw".
var intent := "none"
## Grab: the grabbed object; use: the use target; throw: the aim-snap target or null.
var intent_target: Object = null
## Use and throw: the object that left the castaway's hands.
var intent_object: Object = null
var throw_destination := Vector2.ZERO
var dash_started := false
var dash_direction := Vector2.ZERO
var dizzy_ended := false
## What the next interact press will do: "grab", "use", "throw" or "none".
var verb := "none"
## Grab and throw: kind of the object; use: target_kind of the target; none: empty.
var verb_target_kind := ""
