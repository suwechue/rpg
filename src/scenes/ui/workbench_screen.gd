## The workbench: design a new card (plays a minigame), copy a design you own,
## or edit any party member's deck. `craft_ap` is 1 at home at Night, 2 elsewhere.
extends "res://src/scenes/ui/modal.gd"

const Crafting := preload("res://src/core/progression/crafting.gd")
const CardRules := preload("res://src/core/card.gd")
const Char := preload("res://src/core/character.gd")

var craft_ap := 1
var place := "home"
## Where AP comes from: the day's AP by default; the arena passes its Arena AP.
var ap_left: Callable = func() -> int: return int(ap_left.call())
var spend_ap: Callable = func(n: int, kind: String) -> bool: return Calendar.spend_ap(n, kind)
var deck_save_cost := 0   # the arena charges for swapping cards
var _vectors: Array = []
var _form := ""
var _magnitude := "standard"
var _deck_owner := "player"
var _deck: Array = []


func _ready() -> void:
	build("Workbench (%s)" % place, 420)
	_menu()


func _menu() -> void:
	clear_body()
	text("AP left: %d. A new design costs %d AP and a minigame; a copy costs %d AP." % [int(ap_left.call()), craft_ap, int(DataDB.table("minigames").get("copyAp", 1))], UiTheme.DIM)
	add_button("Design a new card", _design, int(ap_left.call()) < craft_ap)
	add_button("Copy a design you own", _copy_menu, int(ap_left.call()) < int(DataDB.table("minigames").get("copyAp", 1)))
	add_button("Edit decks (free)", func() -> void:
		_deck_owner = "player"
		_deck = GameState.player.get("deck", []).duplicate()
		_deck_editor())
	add_button("Done", func() -> void: finish(null))
	focus_first()


func _design() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	var p: Dictionary = GameState.player
	if _vectors.is_empty() and not p["knownVectors"].is_empty():
		_vectors = [p["knownVectors"][0]]
	if _form == "" or not p["knownForms"].has(_form):
		_form = str(p["knownForms"][0]) if not p["knownForms"].is_empty() else ""
	text("Pick 1 Vector (or 2 for a hybrid), a Form and a Magnitude.", UiTheme.DIM)
	var vr := HFlowContainer.new()
	body.add_child(vr)
	vr.add_child(UiTheme.label("Vectors:"))
	for v in p["knownVectors"]:
		var a := str(v)
		vr.add_child(UiTheme.button(("[%s]" if _vectors.has(a) else "%s") % a.capitalize(), func() -> void:
			if _vectors.has(a):
				if _vectors.size() > 1:
					_vectors.erase(a)
			elif _vectors.size() < 2:
				_vectors.append(a)
			else:
				_vectors = [_vectors[1], a]
			_design()))
	var fr := HFlowContainer.new()
	body.add_child(fr)
	fr.add_child(UiTheme.label("Form:"))
	for f in p["knownForms"]:
		var fid := str(f)
		fr.add_child(UiTheme.button(("[%s]" if _form == fid else "%s") % str(DataDB.record("forms", fid).get("name", fid)), func() -> void:
			_form = fid
			_design()))
	var mr := HFlowContainer.new()
	body.add_child(mr)
	mr.add_child(UiTheme.label("Magnitude:"))
	var cap := CardRules.magnitude_index(db, CardRules.max_magnitude(db, int(p.get("knowledgeTier", 1))))
	for m in db.get("vectors", {}).get("magnitudeOrder", []):
		var mid := str(m)
		var b := UiTheme.button(("[%s]" if _magnitude == mid else "%s") % mid.capitalize(), func() -> void:
			_magnitude = mid
			_design())
		b.disabled = CardRules.magnitude_index(db, mid) > cap
		b.tooltip_text = "Needs a higher Knowledge Tier." if b.disabled else ""
		mr.add_child(b)
	var err := CardRules.design_error(db, p, _vectors, _form, _magnitude)
	if err == "":
		var dir := {}
		for v in _vectors:
			dir[v] = 1.0
		var card := CardRules.make_spell(db, dir, _form, _magnitude)
		var arch := Crafting.archetype(db, Crafting.input_vector(db, _vectors, _magnitude))
		text("%s: %d MP. %s" % [card["name"], int(card["cost"]), CardRules.describe(db, card)])
		text("Minigame: %s. Better Performance rolls Properties; a perfect score adds a Magnitude step." % arch.capitalize(), UiTheme.DIM)
	else:
		text(err, UiTheme.BAD)
	add_button("Craft (%d AP)" % craft_ap, _play_minigame, err != "" or int(ap_left.call()) < craft_ap)
	add_button("Back", _menu)
	focus_first()


func _play_minigame() -> void:
	if not bool(spend_ap.call(craft_ap, "craft")):
		return
	var db: Dictionary = DataDB.all()
	var arch := Crafting.archetype(db, Crafting.input_vector(db, _vectors, _magnitude))
	var rec := DataDB.record("minigames", arch)
	var mg: Control = (load(str(rec.get("script", "res://src/scenes/minigames/precision_minigame.gd"))) as GDScript).new()
	mg.set("archetype", arch)
	mg.set("title", str(rec.get("name", arch.capitalize())))
	mg.set("hint", str(rec.get("text", "")))
	visible = false
	get_parent().add_child(mg)
	var perf: float = await mg.finished
	visible = true
	var card := Crafting.craft(db, GameState.run, GameState.player, _vectors, _form, _magnitude, perf, Rng.stream("crafting"))
	clear_body()
	text("Performance: %d%%" % roundi(perf * 100.0), UiTheme.ACCENT)
	if card.has("error"):
		text(str(card["error"]), UiTheme.BAD)
	else:
		text("You made %s (%d MP)." % [card["name"], int(card["cost"])], UiTheme.GOOD)
		for prop in card.get("properties", []):
			var pr := DataDB.record("properties", str(prop))
			text("Property: %s. %s" % [pr.get("name", prop), pr.get("text", "")])
		if bool(card.get("stepped", false)):
			text("A perfect craft: +1 Magnitude step!", UiTheme.GOOD)
		text("It's in your collection. Add it to a deck from Edit decks.", UiTheme.DIM)
		Narrator.say("A new card. The workbench smells faintly of %s." % str(_vectors[0]))
	add_button("Back", _menu)
	focus_first()


func _copy_menu() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	text("Copies keep the original's Properties and skip the minigame.", UiTheme.DIM)
	var coll: Dictionary = GameState.run.get("collection", {})
	var copy_ap := int(DataDB.table("minigames").get("copyAp", 1))
	for id in coll:
		var card := CardRules.resolve(db, str(id), GameState.cards)
		if not CardRules.is_spell(card):
			continue
		var cid := str(id)
		add_button("%s x%d (%d MP)" % [card.get("name", id), int(coll[id]), CardRules.cost(db, card)], func() -> void:
			if bool(spend_ap.call(copy_ap, "copy")) and Crafting.copy(GameState.run, cid):
				Narrator.say("Another %s for the pile." % card.get("name", cid))
			_copy_menu(), int(ap_left.call()) < copy_ap)
	add_button("Back", _menu)
	focus_first()


func _deck_editor() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	var owners: Array = ["player"] + GameState.party_ids.duplicate()
	var orow := HFlowContainer.new()
	body.add_child(orow)
	for o in owners:
		var oid := str(o)
		var ch := GameState.character(oid)
		orow.add_child(UiTheme.button(("[%s]" if oid == _deck_owner else "%s") % str(ch.get("name", oid)), func() -> void:
			_deck_owner = oid
			_deck = GameState.character(oid).get("deck", []).duplicate()
			_deck_editor()))
	var ch := GameState.character(_deck_owner)
	text("%s's deck: %d cards (%d to %d)." % [ch.get("name", "?"), _deck.size(), int(db["leveling"].get("deckMin", 10)), Char.deck_max(db, ch)], UiTheme.ACCENT)
	var ids: Array = []
	for id in GameState.run.get("collection", {}):
		ids.append(str(id))
	for id in _deck:
		if not ids.has(str(id)):
			ids.append(str(id))
	for any_id in ids:
		var id := str(any_id)
		var card := CardRules.resolve(db, id, GameState.cards)
		if card.is_empty():
			continue
		var in_deck := _deck.count(id)
		var r := row()
		var l := UiTheme.label("%s (%d MP)  %d in deck / %d owned" % [card.get("name", id), CardRules.cost(db, card), in_deck, Crafting.owned(GameState.run, ch, id)])
		l.custom_minimum_size = Vector2(300, 0)
		r.add_child(l)
		var cid := id
		r.add_child(UiTheme.button("-", func() -> void:
			_deck.erase(cid)
			_deck_editor()))
		r.add_child(UiTheme.button("+", func() -> void:
			_deck.append(cid)
			_deck_editor()))
	var err := Crafting.deck_error(db, GameState.run, ch, _deck)
	if err != "":
		text(err, UiTheme.BAD)
	add_button("Save deck" + (" (%d AP)" % deck_save_cost if deck_save_cost > 0 else ""), func() -> void:
		if deck_save_cost > 0 and not bool(spend_ap.call(deck_save_cost, "swapCard")):
			return
		Crafting.set_deck(DataDB.all(), GameState.run, GameState.character(_deck_owner), _deck)
		_menu(), err != "" or int(ap_left.call()) < deck_save_cost)
	add_button("Back (discard changes)", _menu)
	focus_first()

