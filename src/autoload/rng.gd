## Seeded random streams for the whole game. Always draw randomness from here:
##   var rng := Rng.stream("dungeon")
extends Node

const Streams := preload("res://src/core/rng_streams.gd")

var _streams = Streams.new(0)


func reseed(seed_value: int) -> void:
	_streams.reseed(seed_value)


func stream(stream_name: String) -> RandomNumberGenerator:
	return _streams.stream(stream_name)


func get_state() -> Dictionary:
	return _streams.get_state()


func set_state(state: Dictionary) -> void:
	_streams.set_state(state)
