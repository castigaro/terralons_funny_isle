extends "res://tests/support/feedback_case.gd"
## Popup words and emotes are suppressed while the result screen is open: set_text_suppressed(true) releases the
## active ones and skips new ones while particles and puffs keep playing; reset_all() (level start or restart) clears
## the flag.


func test_suppression_releases_and_blocks_popups() -> void:
	make_director()
	emit("level_won", ["fx_level", 3])
	await frames(1)
	check(director.active_count("popup") > 0, "yay popup without suppression")
	director.set_text_suppressed(true)
	check_true(director.text_suppressed(), "flag set")
	check_eq(director.active_count("popup"), 0, "active popups released")
	var particles := director.played("particles")
	emit("level_won", ["fx_level", 3])
	emit("level_lost", ["fx_level", []])
	await frames(1)
	check_eq(director.active_count("popup"), 0, "no new popup while suppressed")
	check(director.played("particles") > particles, "particles still play")
	check(director.active_count("puff") > 0, "puffs still play")
	director.reset_all()
	check_false(director.text_suppressed(), "reset_all clears the flag")
	emit("level_lost", ["fx_level", []])
	await frames(1)
	check(director.active_count("popup") > 0, "popups again after the reset")


func test_unsuppress_lets_popups_play() -> void:
	make_director()
	director.set_text_suppressed(true)
	director.set_text_suppressed(false)
	emit("level_won", ["fx_level", 1])
	await frames(1)
	check(director.active_count("popup") > 0, "popup after unsuppress")


## QA-4: an emote (the laugh art reads "HA HA") must not stay frozen beside the loss panel, also one started in the
## same frame right before the panel opens, and none may start while the panel is open.
func test_suppression_releases_and_blocks_emotes() -> void:
	make_director()
	emit("castaway_dizzy_started", ["bonk"])
	check(director.active_count("emote") > 0, "emote without suppression")
	var nodes := director.active_nodes("emote")
	director.set_text_suppressed(true)
	check_eq(director.active_count("emote"), 0, "active emotes released")
	for node: CanvasItem in nodes:
		check_false(node.visible, "released emote hidden")
	emit("castaway_dizzy_started", ["bonk"])
	emit("level_lost", ["fx_level", []])
	await frames(1)
	check_eq(director.active_count("emote"), 0, "no new emote while suppressed")
	check(director.active_count("puff") > 0, "puffs still play")
	director.set_text_suppressed(false)
	emit("castaway_dizzy_started", ["bonk"])
	check(director.active_count("emote") > 0, "emotes again after unsuppress")
