extends RefCounted
## Records every script signal of an object (for example the EventBus) as [name, args] in emission order.

var _source: Object = null
var _events: Array = []
var _connections: Array = []


func _init(source: Object) -> void:
	_source = source
	for s in source.get_script().get_script_signal_list():
		var sname: String = s["name"]
		var cb := _make_callback(sname, s["args"].size())
		source.connect(sname, cb)
		_connections.append([sname, cb])


func _make_callback(sname: String, argc: int) -> Callable:
	match argc:
		0:
			return func() -> void: _events.append([sname, []])
		1:
			return func(a: Variant) -> void: _events.append([sname, [a]])
		2:
			return func(a: Variant, b: Variant) -> void: _events.append([sname, [a, b]])
		3:
			return func(a: Variant, b: Variant, c: Variant) -> void: _events.append([sname, [a, b, c]])
		_:
			return func(a: Variant, b: Variant, c: Variant, d: Variant) -> void: _events.append([sname, [a, b, c, d]])


## Returns [[name, args], ...] in emission order.
func events() -> Array:
	return _events.duplicate(true)


## Returns the signal names in emission order.
func names() -> Array:
	var result := []
	for e in _events:
		result.append(e[0])
	return result


## Returns the events whose name is in the given list.
func filtered(wanted: Array) -> Array:
	var result := []
	for e in _events:
		if wanted.has(e[0]):
			result.append(e)
	return result


func clear() -> void:
	_events.clear()


func disconnect_all() -> void:
	for c in _connections:
		if is_instance_valid(_source) and _source.is_connected(c[0], c[1]):
			_source.disconnect(c[0], c[1])
	_connections.clear()
