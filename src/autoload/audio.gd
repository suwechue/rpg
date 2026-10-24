## Music and sound effects by id (data/audio.json). Music crossfades are kept
## simple: a new track replaces the old one; the same id keeps playing.
extends Node

const SFX_VOICES := 6

var _music: AudioStreamPlayer
var _music_id := ""
var _sfx: Array = []
var _next := 0
var muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.volume_db = float(DataDB.table("audio").get("musicVolumeDb", -10))
	add_child(_music)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = float(DataDB.table("audio").get("sfxVolumeDb", -6))
		add_child(p)
		_sfx.append(p)
	if DisplayServer.get_name() == "headless":
		muted = true


func play_music(id: String) -> void:
	if muted or id == _music_id:
		return
	var path := str(DataDB.table("audio").get("music", {}).get(id, ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music.stream = stream
	_music.play()
	_music_id = id


func stop_music() -> void:
	_music.stop()
	_music_id = ""


func play_sfx(id: String) -> void:
	if muted:
		return
	var path := str(DataDB.table("audio").get("sfx", {}).get(id, ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var p: AudioStreamPlayer = _sfx[_next]
	_next = (_next + 1) % _sfx.size()
	p.stream = load(path)
	p.play()
