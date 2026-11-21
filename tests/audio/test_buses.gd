extends TestCase
## Audio buses from default_bus_layout.tres and the linear volume API (0 mutes the bus).


func _audio() -> Node:
	return root().get_node("Audio")


func _idx(bus: String) -> int:
	return AudioServer.get_bus_index(bus)


func test_buses_exist_and_send_to_master() -> void:
	check_eq(String(ProjectSettings.get_setting("audio/buses/default_bus_layout")), "res://default_bus_layout.tres",
			"layout setting")
	check_eq(AudioServer.get_bus_name(0), "Master", "bus 0")
	for bus in ["Music", "Effects"]:
		check(_idx(bus) > 0, "bus %s missing" % bus)
		if _idx(bus) > 0:
			check_eq(String(AudioServer.get_bus_send(_idx(bus))), "Master", "%s send" % bus)


func test_announcer_jingles_and_sfx_use_effects() -> void:
	var audio := _audio()
	check_eq(String(audio.get_node("Announcer").bus), "Effects", "announcer bus")
	check_eq(String(audio.get_node("Jingle").bus), "Effects", "jingle bus")
	for player in audio.call("sfx_players", "step"):
		check_eq(String(player.bus), "Effects", "sfx bus")
	for player in audio.call("music_players"):
		check_eq(String(player.bus), "Music", "music bus")


func _check_bus(name: String, key: String) -> void:
	var audio := _audio()
	var idx := _idx(name)
	audio.call("set_volume", key, -0.5)
	check_eq(audio.call("get_volume", key), 0.0, "%s clamp low" % key)
	check_true(AudioServer.is_bus_mute(idx), "%s muted at 0" % key)
	audio.call("set_volume", key, 1.5)
	check_eq(audio.call("get_volume", key), 1.0, "%s clamp high" % key)
	check_false(AudioServer.is_bus_mute(idx), "%s unmuted at 1" % key)
	check(absf(AudioServer.get_bus_volume_db(idx)) < 0.001, "%s 0 dB at 1" % key)
	audio.call("set_volume", key, 0.5)
	check(absf(AudioServer.get_bus_volume_db(idx) - linear_to_db(0.5)) < 0.001, "%s -6 dB at 0.5" % key)
	check(absf(AudioServer.get_bus_volume_db(idx) + 6.02) < 0.01, "%s about -6.02 dB" % key)
	check_false(AudioServer.is_bus_mute(idx), "%s unmuted at 0.5" % key)
	audio.call("set_volume", key, 0.0)
	check_true(AudioServer.is_bus_mute(idx), "%s muted again" % key)
	audio.call("set_volume", key, 0.3)
	check_false(AudioServer.is_bus_mute(idx), "%s unmuted at 0.3" % key)
	check(absf(AudioServer.get_bus_volume_db(idx) - linear_to_db(0.3)) < 0.001, "%s 0.3" % key)


func test_music_volume() -> void:
	_check_bus("Music", "music")


func test_effects_volume() -> void:
	_check_bus("Effects", "Effects")


func test_volumes_are_independent() -> void:
	var audio := _audio()
	audio.call("set_volume", "music", 0.0)
	audio.call("set_volume", "effects", 0.8)
	check_true(AudioServer.is_bus_mute(_idx("Music")), "music muted")
	check_false(AudioServer.is_bus_mute(_idx("Effects")), "effects not muted")
	check_false(AudioServer.is_bus_mute(0), "master untouched")


func test_unknown_bus_only_warns() -> void:
	var audio := _audio()
	var before_master := AudioServer.get_bus_volume_db(0)
	audio.call("set_volume", "voices", 0.2)
	check_eq(AudioServer.get_bus_volume_db(0), before_master, "master unchanged")
	check_eq(audio.call("warnings_logged").size(), 1, "one warning")
	check_eq(audio.call("last_errors"), [], "no errors")


func test_reset_restores_default_volume() -> void:
	var audio := _audio()
	audio.call("set_volume", "music", 0.0)
	audio.call("reset_for_tests")
	check_eq(audio.call("get_volume", "music"), 1.0, "default volume")
	check_false(AudioServer.is_bus_mute(_idx("Music")), "unmuted after reset")
