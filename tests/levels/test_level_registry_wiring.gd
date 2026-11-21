extends "res://tests/support/level_case.gd"
## LevelBase owns the EntityRegistry: castaway, protection and the level_bounds contract are wired in _ready.


func before_each() -> void:
	await open_level()


func test_registry_child_and_castaway() -> void:
	var reg := level.entity_registry()
	check(reg != null and reg.get_parent() == level, "EntityRegistry child")
	check(reg.castaway == castaway, "registry castaway is the level castaway")
	check_eq(reg.entities().size(), 2, "chicken and coconut tracked")


func test_protection_follows_the_session() -> void:
	var reg := level.entity_registry()
	var chicken := level.get_node("Actors/Chicken1") as Animal
	check_false(reg.is_protected(chicken), "not protected before the task")
	chicken.relocate_to(level.zone("zone_a").global_position)
	await physics_frames(2)
	check(reg.is_protected(chicken), "protected after its in_zone task is done")
	check(reg.confine_for(chicken) == level.zone("zone_a"), "confined to zone_a")


func test_level_bounds_contract() -> void:
	check(level.is_in_group(EntityRegistry.BOUNDS_GROUP), "level in group level_bounds")
	check_eq(level.get_bounds_rect(), Rect2(128, 128, 22 * 128, 12 * 128), "bounds rect")


func test_entity_outside_the_bounds_respawns_home() -> void:
	var reg := level.entity_registry()
	var chicken := level.get_node("Actors/Chicken1") as Animal
	var b := level.get_bounds_rect()
	chicken.relocate_to(b.position - Vector2(300, 300))
	check_eq(reg.unreachable_reason(chicken), EntityRegistry.REASON_BOUNDS, "bounds reason")
	var delay := chicken.cfg.respawn_delay
	await physics_frames(int(ceil(delay * 60.0)) + 10)
	check(chicken.global_position.distance_to(level.home_point("chicken_1")) < 1.0,
			"respawned at HomePoints/chicken_1: %s" % chicken.global_position)
