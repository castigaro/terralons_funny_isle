class_name LevelCatalogue
extends RefCounted
## Shipped levels by convention: every data/levels/<id>.json has the scene scenes/levels/<id>.tscn; the order is the
## sorted file name (l1_…, l2_…). There is no index file.

const SCENE_DIR := "res://scenes/levels"


## Sorted level ids (file stems of data/levels/*.json).
static func ids() -> Array:
	var out: Array = []
	for path in LevelDef.list_level_files():
		out.append(String(path).get_file().get_basename())
	return out


static func scene_path(id: String) -> String:
	return SCENE_DIR.path_join("%s.tscn" % id)


static func json_path(id: String) -> String:
	return LevelDef.LEVELS_DIR.path_join("%s.json" % id)


## The first level of the campaign, "" without levels.
static func first_id() -> String:
	var all := ids()
	return String(all[0]) if not all.is_empty() else ""


## Scene of a known level id with an existing scene, else "".
static func scene_for(id: String) -> String:
	if not ids().has(id) or not ResourceLoader.exists(scene_path(id)):
		return ""
	return scene_path(id)
