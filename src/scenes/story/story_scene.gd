## Plays a non-inline story sequence (data/story/*.json) as a scene: events,
## narration, guests, the narrator's foreshadowing, fights (hands off to the
## combat scene and resumes here) and the Kelly panic check. Progress lives in
## run["story_pos"] = { "id", "step", "combat": step index or -1 }.
extends Node2D

const StoryRules := preload("res://src/core/story/story.gd")
const TOWN := "res://src/scenes/town/town.tscn"
const SELF := "res://src/scenes/story/story_scene.tscn"

var story: Dictionary = {}
var _t := 0.0


func _ready() -> void:
	Flow.set_hud(false)
	Audio.play_music("dungeon")
	var pos: Dictionary = GameState.run.get("story_pos", {})
	story = StoryRules.find(DataDB.all(), str(pos.get("id", "")))
	if story.is_empty():
		SceneRouter.goto(TOWN)
		return
	if int(pos.get("combat", -1)) >= 0:
		_after_combat(int(pos["combat"]))
	_run.call_deferred(int(GameState.run["story_pos"].get("step", 0)))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var theme: Dictionary = DataDB.record("rooms/themes", str(story.get("theme", "school")))
	var top := Color(str(theme.get("skyTop", "#1a1030")))
	var bot := Color(str(theme.get("skyBottom", "#4a2c5e")))
	var view := Display.size_f()
	var bands := 18
	var band_h := ceilf(view.y / float(bands))
	for i in bands:
		draw_rect(Rect2(0, i * band_h, view.x, band_h + 1), top.lerp(bot, float(i) / float(bands - 1)))
	var trunks := 9
	for i in trunks:
		var x := view.x * (0.06 + 0.11 * i)
		var h := 60.0 + 30.0 * sin(_t * 0.7 + i)
		draw_rect(Rect2(x, view.y - h, 18, h), Color(0, 0, 0, 0.35))


func _save(step: int, combat: int = -1) -> void:
	GameState.run["story_pos"] = { "id": str(story["id"]), "step": step, "combat": combat }
	GameState.run["resume_scene"] = SELF


func _after_combat(step_index: int) -> void:
	var step: Dictionary = story["steps"][step_index]
	var summary: Dictionary = GameState.last_combat
	var risk := StoryRules.combat_risk(step, summary, str(step.get("guest", "")))
	if risk != 0:
		GameState.run["kelly_risk"] = int(GameState.run.get("kelly_risk", 0)) + risk
	if int(summary.get("helpIgnored", 0)) > 0:
		Narrator.say("Kelly called for you. You were busy. She noticed.")
	elif int(summary.get("support", {}).get(str(step.get("guest", "")), 0)) > 0:
		Narrator.say("You covered her. She won't say it, but she saw.")
	_save(step_index + 1)


func _run(from: int) -> void:
	var steps: Array = story.get("steps", [])
	for i in range(from, steps.size()):
		_save(i)
		var step: Dictionary = steps[i]
		match str(step.get("type", "")):
			"event":
				await Flow.show_event(step["event"])
			"narrate":
				await Flow.show_event({ "title": "", "text": str(step["text"]) })
			"foreshadow":
				var l := Narrator.line("foreshadow")
				Narrator.say(l)
				await Flow.show_event({ "title": "The narrator", "text": l })
			"guest":
				if step.has("add"):
					StoryRules.make_guest(DataDB.all(), GameState.run, str(step["add"]), Rng.stream("npc"))
			"combat":
				_save(i, i)
				var setup := GameState.combat_setup(step.get("enemies", []), str(step.get("layout", "open_field")), { "intro": str(step.get("intro", "")) })
				GameState.start_combat(setup, SELF)
				return
			"kellyCheck":
				var outcome := StoryRules.kelly_outcome(DataDB.all(), GameState.run, str(story["id"]))
				var end: Dictionary = story.get(outcome, {})
				if outcome == "death":
					await Flow.show_event({ "title": "", "text": str(end.get("narrate", "")) })
					GameState.run["story_pos"] = {}
					EventBus.run_ended.emit(str(end.get("cause", "story")))
					return
				var lines := StoryRules.apply_survival(DataDB.all(), GameState.run)
				GameState.apply_effects({ "flag": end.get("flag", []) })
				await Flow.show_event({ "title": "", "text": str(end.get("narrate", "")) + "\n" + " ".join(PackedStringArray(lines)) })
	_finish()


func _finish() -> void:
	GameState.set_flag("story_done_" + str(story["id"]))
	StoryRules.clear_guests(GameState.run)
	GameState.run["story_pos"] = {}
	GameState.run.erase("resume_scene")
	GameState.advance_part()
	SceneRouter.goto(TOWN)
