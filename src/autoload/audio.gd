## Music, ambience, sound events and voice blips, all by id (VD Part 1).
## Music and ambience play by situation (data/audio.json: track id, volume,
## loop, crossfade); sound effects are events (data/audio_events.json: one of
## several ids at random, with pitch and volume ranges). Code never names a
## sound file. Missing sounds play nothing and log a warning once.
extends Node

const SFX_VOICES := 8

var _music: Array = []        # two players for crossfades
var _music_on := 0
var _music_id := ""
var _amb: AudioStreamPlayer
var _amb_id := ""
var _sfx: Array = []
var _next := 0
var _voice: AudioStreamPlayer
var _warned: Dictionary = {}
var muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var m := AudioStreamPlayer.new()
		add_child(m)
		_music.append(m)
	_amb = AudioStreamPlayer.new()
	add_child(_amb)
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)
	if DisplayServer.get_name() == "headless":
		muted = true


func _cfg() -> Dictionary:
	return DataDB.table("audio")


func _warn(what: String) -> void:
	if not _warned.has(what):
		_warned[what] = true
		push_warning("Audio: %s" % what)


func _stream(id: String, loop: bool) -> AudioStream:
	var s := Assets.stream(id)
	if s == null:
		_warn("no sound for id '%s' (add assets/custom/<type>/%s.ogg)" % [id, id])
		return null
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = loop
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if loop:
			(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
	return s


## Play the music for a situation ("title", "combat", "boss_cold_cut"...), crossfading.
func play_music(situation: String) -> void:
	if muted or situation == _music_id:
		return
	var rec: Variant = _cfg().get("music", {}).get(situation, null)
	if rec == null:
		_warn("no music for situation '%s'" % situation)
		return
	var t: Dictionary = rec if rec is Dictionary else { "id": str(rec) }
	var s := _stream(str(t.get("id", "")), bool(t.get("loop", true)))
	if s == null:
		return
	_music_id = situation
	var old: AudioStreamPlayer = _music[_music_on]
	_music_on = 1 - _music_on
	var new_p: AudioStreamPlayer = _music[_music_on]
	var vol := float(_cfg().get("musicVolumeDb", -10)) + float(t.get("volumeDb", 0))
	var fade := float(t.get("crossfade", 0.8))
	new_p.stream = s
	new_p.volume_db = vol if fade <= 0.0 else -40.0
	new_p.play()
	if fade > 0.0:
		var tw := create_tween()
		tw.tween_property(new_p, "volume_db", vol, fade)
		tw.parallel().tween_property(old, "volume_db", -40.0, fade)
		tw.tween_callback(old.stop)
	else:
		old.stop()


## The first situation that data/audio.json maps ("boss_cold_cut", then
## "battle_boss"), so specific tracks are optional (VD Part 1).
func play_music_first(situations: Array) -> void:
	for s in situations:
		if _cfg().get("music", {}).has(str(s)):
			play_music(str(s))
			return
	if not situations.is_empty():
		play_music(str(situations[-1]))


## Hot reload (F1, VD Part 1): reread sounds and restart the current music
## and ambience, so replaced files play at once.
func reload() -> void:
	Assets.reload_audio()
	_warned.clear()
	var m := _music_id
	var a := _amb_id
	_music_id = ""
	_amb_id = ""
	if m != "":
		play_music(m)
	if a != "":
		play_ambience(a)


func stop_music() -> void:
	for m in _music:
		(m as AudioStreamPlayer).stop()
	_music_id = ""


## A quiet background loop for a situation ("town_day", "upside_down_week2"); "" stops it.
func play_ambience(situation: String) -> void:
	if muted or situation == _amb_id:
		return
	_amb_id = situation
	if situation == "":
		_amb.stop()
		return
	var id := str(_cfg().get("ambience", {}).get(situation, ""))
	var s := _stream(id, true) if id != "" else null
	if s == null:
		_amb.stop()
		return
	_amb.stream = s
	_amb.volume_db = float(_cfg().get("ambienceVolumeDb", 0))
	_amb.play()


## Fire a sound event ("door_open", "card_play_heat"): one of its ids at random,
## with a little pitch and volume variation.
func event(event_name: String) -> void:
	if muted:
		return
	var rec: Dictionary = DataDB.table("audio_events").get("events", {}).get(event_name, {})
	if rec.is_empty():
		_warn("no sound event '%s' in data/audio_events.json" % event_name)
		return
	var ids: Array = rec.get("ids", [])
	if ids.is_empty():
		return
	var rng := Rng.stream("fx")
	var s := _stream(str(ids[rng.randi_range(0, ids.size() - 1)]), false)
	if s == null:
		return
	var p: AudioStreamPlayer = _sfx[_next]
	_next = (_next + 1) % _sfx.size()
	var pitch: Array = rec.get("pitch", [1.0, 1.0])
	var vol: Array = rec.get("volumeDb", [0.0, 0.0])
	p.stream = s
	p.pitch_scale = rng.randf_range(float(pitch[0]), float(pitch[1]))
	p.volume_db = float(_cfg().get("sfxVolumeDb", -6)) + rng.randf_range(float(vol[0]), float(vol[1]))
	p.play()


## Older name for event().
func play_sfx(event_name: String) -> void:
	event(event_name)


## One voice blip for a character (data/npcs/<id>.json "voice": id and pitch).
func voice(npc_id: String) -> void:
	if muted:
		return
	var v: Dictionary = DataDB.table("npcs/" + npc_id).get("voice", {})
	var s := _stream(str(v.get("id", "voice_default")), false)
	if s == null:
		return
	_voice.stream = s
	_voice.pitch_scale = float(v.get("pitch", 1.0)) * Rng.stream("fx").randf_range(0.96, 1.04)
	_voice.volume_db = float(_cfg().get("voiceVolumeDb", -10))
	_voice.play()
