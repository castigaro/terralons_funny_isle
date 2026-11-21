class_name PhysicsLayers
extends RefCounted
## 2D physics layer bits; names match [layer_names] in project.godot.

const WORLD_SOLID := 1
const WATER := 2
const BOUNDS := 4
const CASTAWAY := 8
const ANIMALS := 16
const ITEMS := 32
const ZONES := 64

## What the castaway body collides with: solid objects, the shoreline and the level bounds.
const CASTAWAY_MASK := WORLD_SOLID | WATER | BOUNDS
## What stops a thrown object in flight: solid objects and the level bounds, never water.
const THROW_MASK := WORLD_SOLID | BOUNDS
