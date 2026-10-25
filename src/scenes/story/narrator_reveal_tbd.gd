## NARRATOR_REVEAL_TBD: the week 5 finale placeholder (DESIGN.md Section 18:
## the narrator's identity stays open). Plays the placeholder reveal, then the
## alpha ending, branching on story choices and Bonds, then credits. The run
## ends here: the Journal records the ending and the save is cleared.
extends Node2D

const Fx := preload("res://src/core/run/effects.gd")
const TITLE := "res://src/scenes/title/title.tscn"

var _t := 0.0


func _ready() -> void:
	Flow.set_hud(false)
	Audio.play_music("reveal")
	_play.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var view := Display.size_f()
	var bands := 18
	var band_h := ceilf(view.y / float(bands))
	for i in bands:
		var c := Color("0b0614").lerp(Color("3a1d4a"), float(i) / float(bands - 1))
		draw_rect(Rect2(0, i * band_h, view.x, band_h + 1), c)
	var glow := 0.5 + 0.5 * sin(_t)
	var center := Vector2(view.x / 2.0, view.y * 0.44)
	draw_circle(center, 30.0 + 6.0 * glow, Color(1.0, 0.9, 0.6, 0.12))
	draw_circle(center, 12.0, Color(1.0, 0.95, 0.8, 0.35))


func _play() -> void:
	var end: Dictionary = DataDB.table("endings").get("alpha", {})
	await Flow.show_event({ "title": "NARRATOR_REVEAL_TBD", "text": str(end.get("reveal", "NARRATOR_REVEAL_TBD")) })
	Audio.play_music("ending")
	var db: Dictionary = DataDB.all()
	var text := ""
	for b in end.get("branches", []):
		if Fx.conditions_met(db, GameState.run, b.get("cond", {}), GameState.ctx()):
			text = str(b["text"])
			break
	var lines: Array = [text]
	var bond_lines: Dictionary = end.get("bondLines", {})
	for id in bond_lines:
		if float(GameState.bonds.get(str(id), 0.0)) >= 41.0:
			lines.append(str(bond_lines[id]))
	lines.append(Strings.t("narrator_reveal_tbd.run_complete_level_days_seed") % [int(GameState.player.get("level", 1)),
		str(DataDB.record("classes", str(GameState.player.get("class", ""))).get("name", "")), int(GameState.run.get("day_count", 0)), GameState.run_seed])
	await Flow.show_event({ "title": Strings.t("narrator_reveal_tbd.the_mirror_town_after"), "text": "\n\n".join(PackedStringArray(lines)) })
	await Flow.show_event({ "title": "Credits", "text": str(end.get("credits", "")) })
	Journal.note_ending("alpha_complete")
	SaveSystem.delete_save()
	GameState.run = {}
	SceneRouter.goto(TITLE)
