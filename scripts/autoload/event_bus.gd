extends Node
## Global signal hub that decouples gameplay, feedback, audio and HUD.
## Contract: typed signals only, extended additively (never rename or retype a signal); no registry,
## no register() and no plugin or feature lookup. Emitters call EventBus.<signal>.emit(...).

@warning_ignore("unused_signal")
signal level_started(level_id: String)
@warning_ignore("unused_signal")
signal level_timer_tick(seconds_left: float)
@warning_ignore("unused_signal")
signal task_completed(level_id: String, task_id: String)
@warning_ignore("unused_signal")
signal all_required_done(level_id: String)
@warning_ignore("unused_signal")
signal level_won(level_id: String, stars: int)
@warning_ignore("unused_signal")
signal level_lost(level_id: String, open_tasks: Array)
@warning_ignore("unused_signal")
signal event_triggered(event_id: String)
@warning_ignore("unused_signal")
signal object_grabbed(kind: String)
@warning_ignore("unused_signal")
signal object_thrown(kind: String)
@warning_ignore("unused_signal")
signal object_bonked(kind: String, cause: String)
@warning_ignore("unused_signal")
signal settings_changed(key: String)
