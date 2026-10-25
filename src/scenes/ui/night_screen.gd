## Night at home: 1 AP for the workbench, then sleep (ends the day).
extends "res://src/scenes/ui/modal.gd"

const Workbench := preload("res://src/scenes/ui/workbench_screen.gd")
const CharSheet := preload("res://src/scenes/ui/character_sheet.gd")


func _ready() -> void:
	build(Strings.t("night.night_at_home"), 340)
	Audio.play_music("night")
	_menu()


func _menu() -> void:
	clear_body()
	var lines: Array = []
	for line in Flow.night_lines():
		lines.append(str(line))
	if not lines.is_empty():
		text(" ".join(PackedStringArray(lines)), UiTheme.DIM)
	text(Strings.t("night.ap_left") % Calendar.ap(), UiTheme.DIM)
	add_button(Strings.t("night.workbench_craft_cards_edit_decks"), func() -> void:
		var wb := Workbench.new()
		wb.craft_ap = int(DataDB.table("minigames").get("craftAp", {}).get("night", 1))
		wb.place = "home"
		get_parent().add_child(wb)
		visible = false
		await wb.closed
		visible = true
		_menu())
	add_button(Strings.t("night.character_sheet"), func() -> void:
		var holder := preload("res://src/scenes/ui/modal.gd").new()
		get_parent().add_child(holder)
		holder.build(Strings.t("night.character"), 420)
		var sheet := CharSheet.new()
		holder.body.add_child(sheet)
		sheet.show_character(GameState.player, GameState.cards)
		holder.add_button(Strings.t("night.close"), func() -> void: holder.finish(null))
		visible = false
		await holder.closed
		visible = true
		_menu())
	add_button(Strings.t("night.party_recruited") % GameState.roster.size(), func() -> void:
		var ps := preload("res://src/scenes/ui/party_screen.gd").new()
		get_parent().add_child(ps)
		visible = false
		await ps.closed
		visible = true
		_menu())
	for extra in Flow.night_extras():
		var e: Dictionary = extra
		add_button(str(e["label"]), func() -> void:
			visible = false
			await Flow.run_night_extra(e)
			visible = true
			_menu(), bool(e.get("disabled", false)))
	add_button(Strings.t("night.go_to_sleep"), func() -> void: finish("sleep"))
	focus_first()
