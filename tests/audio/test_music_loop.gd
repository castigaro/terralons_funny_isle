extends TestCase
## Every music track loads as a forward-looping WAV over its whole length (seamless loop, no gap).

const MUSIC_IDS := ["title", "level_1", "level_2", "level_3", "ending"]


func test_every_track_loops_forward() -> void:
	var map := AudioMap.load_file()
	check_eq(map.music_ids(), ["ending", "level_1", "level_2", "level_3", "title"], "music ids")
	for id in MUSIC_IDS:
		var stream := load(map.music_path(id)) as AudioStreamWAV
		check(stream != null, "%s is not an AudioStreamWAV" % id)
		if stream == null:
			continue
		check_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loop mode" % id)
		check_eq(stream.loop_begin, 0, "%s loop begin" % id)
		var frames := roundi(stream.get_length() * stream.mix_rate)
		var end := stream.loop_end
		check(absi(end - frames) <= 1, "%s loop end %d vs %d frames" % [id, end, frames])
		check(stream.get_length() > 1.0, "%s length" % id)
