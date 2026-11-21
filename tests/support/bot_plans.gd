extends RefCounted
## Declarative level knowledge for the bot: per level the shipped scene and the task steps in play order.
## A step names its task, the entity kinds that serve it (tried in order), a zone whose members are already
## delivered (skip_zone) and the use target node the carried entity goes to.

const PLANS := {
	"l1_beach_camp": {
		"scene": "res://scenes/levels/l1_beach_camp.tscn",
		"json": "res://data/levels/l1_beach_camp.json",
		"hold_style": "staged",
		"steps": [
			{"task": "chickens_in_cage", "kinds": ["chicken"], "skip_zone": "cage", "target": "Actors/CageGate"},
			{"task": "coconuts_to_monkey", "kinds": ["coconut"], "skip_zone": "",
					"target": "Actors/Monkey1/DeliveryTarget"},
			{"task": "hat_on_goat", "kinds": ["hat"], "skip_zone": "", "target": "Actors/Goat1/WearTarget"},
		],
	},
	"l2_farm_meadow": {
		"scene": "res://scenes/levels/l2_farm_meadow.tscn",
		"json": "res://data/levels/l2_farm_meadow.json",
		"hold_style": "staged",
		"steps": [
			{"task": "feed_before_rain", "kinds": ["bucket"], "skip_zone": "", "target": "Actors/Trough"},
			{"task": "catch_pig", "kinds": ["pig"], "skip_zone": "pig_pen", "target": "Actors/PenGate"},
			{"task": "ducks_in_pond", "kinds": ["duck"], "skip_zone": "pond", "target": "Actors/PondJetty"},
		],
	},
	"l3_jungle": {
		"scene": "res://scenes/levels/l3_jungle.tscn",
		"json": "res://data/levels/l3_jungle.json",
		"hold_style": "staged",
		"steps": [
			{"task": "goat_before_stampede", "kinds": ["goat"], "skip_zone": "goat_pen", "target": "Actors/PenGate"},
			{"task": "parrot_to_perch", "kinds": ["parrot"], "skip_zone": "perch", "target": "Actors/PerchGate"},
			{"task": "frogs_to_pond", "kinds": ["frog"], "skip_zone": "pond", "target": "Actors/PondJetty"},
		],
	},
	"l4_lagoon": {
		"scene": "res://scenes/levels/l4_lagoon.tscn",
		"json": "res://data/levels/l4_lagoon.json",
		"hold_style": "staged",
		"steps": [
			{"task": "sandcastle_before_wave", "kinds": ["sand_pail"], "skip_zone": "", "target": "Actors/Sandcastle"},
			{"task": "hat_on_penguin", "kinds": ["hat"], "skip_zone": "", "target": "Actors/Penguin1/WearTarget"},
			{"task": "penguin_to_beach", "kinds": ["penguin"], "skip_zone": "beach", "target": "Actors/BeachFlag"},
			{"task": "ducks_in_lagoon", "kinds": ["duck"], "skip_zone": "lagoon", "target": "Actors/LagoonJetty"},
		],
	},
	"l5_volcano_cliffs": {
		"scene": "res://scenes/levels/l5_volcano_cliffs.tscn",
		"json": "res://data/levels/l5_volcano_cliffs.json",
		"hold_style": "staged",
		"steps": [
			{"task": "hat_on_pig", "kinds": ["hat"], "skip_zone": "", "target": "Actors/Pig1/WearTarget"},
			{"task": "feed_penguin", "kinds": ["bucket"], "skip_zone": "", "target": "Actors/Penguin1/DeliveryTarget"},
			{"task": "pig_to_mud_pool", "kinds": ["pig"], "skip_zone": "mud_pool", "target": "Actors/MudGate"},
			{"task": "shelter_flock", "kinds": ["chicken", "goat"], "skip_zone": "shelter",
					"target": "Actors/ShelterGate"},
		],
	},
}


static func plan(level_id: String) -> Dictionary:
	return PLANS.get(level_id, {})


static func level_ids() -> Array:
	var ids := PLANS.keys()
	ids.sort()
	return ids


static func step_of_task(level_id: String, task_id: String) -> Dictionary:
	for step in plan(level_id).get("steps", []):
		if step["task"] == task_id:
			return step
	return {}


## The level seed from the level JSON (0 when missing).
static func level_seed(level_id: String) -> int:
	var text := FileAccess.get_file_as_string(String(plan(level_id).get("json", "")))
	var data: Variant = JSON.parse_string(text)
	return int((data as Dictionary).get("seed", 0)) if data is Dictionary else 0
