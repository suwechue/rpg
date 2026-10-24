## Named, seeded random streams. One run seed; each system draws from its own
## stream ("dungeon", "combat", "events", "dialogue", "npc", "leveling") so a change
## in one system never shifts another system's results.
class_name RngStreams
extends RefCounted

var run_seed: int = 0
var _streams: Dictionary = {}


func _init(seed_value: int = 0) -> void:
	reseed(seed_value)


func reseed(seed_value: int) -> void:
	run_seed = seed_value
	_streams.clear()


func stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%s" % [run_seed, stream_name])
		_streams[stream_name] = rng
	return _streams[stream_name]


## Stream states are saved as strings: JSON numbers are doubles and would
## lose precision on 64-bit RNG states.
func get_state() -> Dictionary:
	var states := {}
	for stream_name in _streams:
		var rng: RandomNumberGenerator = _streams[stream_name]
		states[stream_name] = str(rng.state)
	return { "run_seed": run_seed, "streams": states }


func set_state(state: Dictionary) -> void:
	reseed(int(state.get("run_seed", 0)))
	var states: Dictionary = state.get("streams", {})
	for stream_name in states:
		var rng := stream(str(stream_name))
		rng.state = str(states[stream_name]).to_int()
