extends Node
## Level progress in <DataDir>/progress.json (next to settings.json): the campaign of data/campaign.json and the
## ProgressModel (wins, best stars, best time). A win is saved at once; a missing or corrupt file means defaults.
## -- --campaign=<res path> swaps the campaign file (development and tests).

const FILE := "progress.json"
const DEFAULT_CAMPAIGN := "res://data/campaign.json"
const CLI_CAMPAIGN := "campaign"

var _campaign_path := DEFAULT_CAMPAIGN
var _campaign: Campaign = Campaign.new()
var _campaign_errors: Array = []
var _model: ProgressModel = ProgressModel.defaults([])
var _status := ""


func _ready() -> void:
	var cli: Variant = CliArgs.current().get(CLI_CAMPAIGN, "")
	if cli is String and cli != "":
		_campaign_path = cli
	_load_campaign()
	reload()


func _load_campaign() -> void:
	var res := Campaign.load_file(_campaign_path)
	_campaign = res["campaign"]
	_campaign_errors = res["errors"]
	for err in _campaign_errors:
		push_warning("Progress: %s" % err)


## Uses another campaign file and re-reads the progress (tests).
func use_campaign(path: String) -> void:
	_campaign_path = path
	_load_campaign()
	reload()


func campaign() -> Campaign:
	return _campaign


func campaign_errors() -> Array:
	return _campaign_errors.duplicate()


func model() -> ProgressModel:
	return _model


func file_path() -> String:
	return DataDir.file(FILE)


## Re-reads progress.json for the current campaign.
func reload() -> void:
	var res := JsonStore.read(file_path())
	_status = res["status"]
	_model = ProgressModel.from_dict(res["data"], _campaign.ids())


func last_status() -> String:
	return _status


func is_unlocked(level_id: String) -> bool:
	return _model.is_unlocked(level_id)


## Records a win and saves at once; returns the ProgressModel.record_win result.
func record_win(level_id: String, stars: int, completion_s: float) -> Dictionary:
	var result := _model.record_win(level_id, stars, completion_s)
	save()
	return result


func save() -> Error:
	return JsonStore.write_atomic(file_path(), _model.to_dict())


## Back to the real campaign and empty in-memory progress without touching any file (between tests).
func reset_for_tests() -> void:
	if _campaign_path != DEFAULT_CAMPAIGN:
		_campaign_path = DEFAULT_CAMPAIGN
		_load_campaign()
	_model = ProgressModel.defaults(_campaign.ids())
	_status = ""
