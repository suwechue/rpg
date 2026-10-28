## The workbench: design a new card (plays a minigame), copy a design you own,
## or edit any party member's deck. `craft_ap` is 1 at home at Night, 2 elsewhere.
extends "res://src/scenes/ui/modal.gd"

const Crafting := preload("res://src/core/progression/crafting.gd")
const CardRules := preload("res://src/core/card.gd")
const Char := preload("res://src/core/character.gd")
const Combos := preload("res://src/core/combos.gd")
const CardView := preload("res://src/scenes/combat/card_view.gd")

var craft_ap := 1
var place := "home"
## Where AP comes from: the day's AP by default; the arena passes its Arena AP.
var ap_left: Callable = func() -> int: return Calendar.ap()
var spend_ap: Callable = func(n: int, kind: String) -> bool: return Calendar.spend_ap(n, kind)
var deck_save_cost := -1  # AP per removed card; -1 = data/leveling.json removeCardCost (the arena sets its own)
var _filter := ""         # deck editor filter: "" or a Vector id or "quick"
var _vectors: Array = []
var _form := ""
var _magnitude := "standard"
var _deck_owner := "player"
var _deck: Array = []


func _ready() -> void:
	build(Strings.t("workbench.workbench") % place, 420)
	_menu()


func _menu() -> void:
	clear_body()
	text(Strings.t("workbench.ap_left_a_new_design") % [int(ap_left.call()), craft_ap, int(DataDB.table("minigames").get("copyAp", 1))], UiTheme.DIM)
	add_button(Strings.t("workbench.design_a_new_card"), _design, int(ap_left.call()) < craft_ap)
	add_button(Strings.t("workbench.copy_a_design_you_own"), _copy_menu, int(ap_left.call()) < int(DataDB.table("minigames").get("copyAp", 1)))
	var rc := int(DataDB.table("techniques").get("reconfigureCost", 1))
	add_button(Strings.t("technique.reconfigure") % rc, func() -> void:
		var owned: Array = GameState.player.get("techniques", [])
		if owned.is_empty() or not bool(spend_ap.call(rc, "technique")):
			return
		var ts := preload("res://src/scenes/ui/technique_screen.gd").new()
		ts.reconfigure_from = str(owned[0])
		visible = false
		await Flow.show_modal(ts)
		visible = true
		_menu(), int(ap_left.call()) < rc or GameState.player.get("techniques", []).is_empty())
	add_button(Strings.t("forge.title"), func() -> void:
		var fs := preload("res://src/scenes/ui/forge_screen.gd").new()
		fs.spend_ap = spend_ap
		fs.ap_left = ap_left
		visible = false
		await Flow.show_modal(fs)
		visible = true
		_menu())
	add_button(Strings.t("workbench.compendium"), func() -> void:
		visible = false
		await Flow.show_modal(preload("res://src/scenes/ui/compendium_screen.gd").new())
		visible = true)
	add_button(Strings.t("workbench.edit_decks_free"), func() -> void:
		_deck_owner = "player"
		_deck = GameState.player.get("deck", []).duplicate()
		_deck_editor())
	add_button(Strings.t("workbench.done"), func() -> void: finish(null))
	focus_first()


func _design() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	var p: Dictionary = GameState.player
	if _vectors.is_empty() and not p["knownVectors"].is_empty():
		_vectors = [p["knownVectors"][0]]
	if _form == "" or not p["knownForms"].has(_form):
		_form = str(p["knownForms"][0]) if not p["knownForms"].is_empty() else ""
	text(Strings.t("workbench.pick_1_vector_or_2"), UiTheme.DIM)
	var vr := HFlowContainer.new()
	body.add_child(vr)
	vr.add_child(UiTheme.label(Strings.t("workbench.vectors")))
	for v in p["knownVectors"]:
		var a := str(v)
		var vb := UiTheme.button(("[%s]" if _vectors.has(a) else "%s") % a.capitalize(), func() -> void:
			if _vectors.has(a):
				if _vectors.size() > 1:
					_vectors.erase(a)
			elif _vectors.size() < 2:
				_vectors.append(a)
			else:
				_vectors = [_vectors[1], a]
			_design())
		vb.add_theme_color_override("font_color", UiTheme.vector_color(a))
		vr.add_child(vb)
	var fr := HFlowContainer.new()
	body.add_child(fr)
	fr.add_child(UiTheme.label(Strings.t("workbench.form")))
	for f in p["knownForms"]:
		var fid := str(f)
		fr.add_child(UiTheme.button(("[%s]" if _form == fid else "%s") % str(DataDB.record("forms", fid).get("name", fid)), func() -> void:
			_form = fid
			_design()))
	var mr := HFlowContainer.new()
	body.add_child(mr)
	mr.add_child(UiTheme.label(Strings.t("workbench.magnitude")))
	var cap := CardRules.magnitude_index(db, CardRules.max_magnitude(db, int(p.get("knowledgeTier", 1))))
	for m in db.get("vectors", {}).get("magnitudeOrder", []):
		var mid := str(m)
		var b := UiTheme.button(("[%s]" if _magnitude == mid else "%s") % mid.capitalize(), func() -> void:
			_magnitude = mid
			_design())
		b.disabled = CardRules.magnitude_index(db, mid) > cap
		b.tooltip_text = Strings.t("workbench.needs_a_higher_knowledge_tier") if b.disabled else ""
		mr.add_child(b)
	var err := CardRules.design_error(db, p, _vectors, _form, _magnitude)
	if err == "":
		var dir := {}
		for v in _vectors:
			dir[v] = 1.0
		var card := CardRules.make_spell(db, dir, _form, _magnitude)
		var arch := Crafting.archetype(db, Crafting.input_vector(db, _vectors, _magnitude))
		var pr := row()
		var cv := CardView.new()
		cv.setup(card, int(card["cost"]))
		cv.focus_mode = Control.FOCUS_NONE
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pr.add_child(cv)
		var dg := preload("res://src/scenes/ui/shape_diagram.gd").new()
		dg.setup(DataDB.record("forms", _form), _magnitude, UiTheme.vector_color(str(_vectors[0])), 5)
		pr.add_child(dg)
		var combo := Combos.for_vectors(db, dir)
		var desc := CardRules.describe(db, card)
		if not combo.is_empty() and not Combos.discovered(GameState.run, Journal.data, str(combo["id"])):
			# Undiscovered combos stay a mystery until crafted (VD Part 4).
			desc = desc.replace(Strings.t("card.combo") % [str(combo.get("name", "")), str(combo.get("description", ""))], Strings.t("workbench.combo_unknown") % str(combo.get("hint", "")))
		var dl := UiTheme.label(Strings.t("workbench.mp") % [card["name"] if combo.is_empty() or Combos.discovered(GameState.run, Journal.data, str(combo["id"])) else Strings.t("combo.unknown"), int(card["cost"]), desc])
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(240, 0)
		pr.add_child(dl)
		text(Strings.t("workbench.minigame_better_performance_rolls_properties") % arch.capitalize(), UiTheme.DIM)
	else:
		text(err, UiTheme.BAD)
	add_button(Strings.t("workbench.craft_ap") % craft_ap, _play_minigame, err != "" or int(ap_left.call()) < craft_ap)
	add_button(Strings.t("workbench.back"), _menu)
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
	text(Strings.t("workbench.performance") % roundi(perf * 100.0) + "  " + Strings.t("workbench.grade") % _grade(perf), UiTheme.ACCENT)
	Audio.event("level_up" if perf >= 0.75 else ("click" if perf >= 0.4 else "fail"))
	if card.has("error"):
		text(str(card["error"]), UiTheme.BAD)
	else:
		_reveal(card)
		text(Strings.t("workbench.you_made_mp") % [card["name"], int(card["cost"])], UiTheme.GOOD)
		var combo := Combos.for_vectors(db, card.get("vectors", {}))
		if not combo.is_empty() and Journal.discover_combo(str(combo["id"])):
			Audio.event("combo_discovered")
			text(Strings.t("workbench.combo_found") % str(combo.get("name", "")), UiTheme.vector_color(str(combo["vectors"][0])))
			text(str(combo.get("description", "")))
			Narrator.say(str(combo.get("narrator", "")))
		for prop in card.get("properties", []):
			var pr := DataDB.record("properties", str(prop))
			text(Strings.t("workbench.property") % [pr.get("name", prop), pr.get("text", "")])
		if bool(card.get("stepped", false)):
			text(Strings.t("workbench.a_perfect_craft_1_magnitude"), UiTheme.GOOD)
		if Crafting.add_to_deck(db, GameState.player, str(card["id"])):
			text(Strings.t("workbench.added_to_deck"), UiTheme.DIM)
		else:
			text(Strings.t("workbench.it_s_in_your_collection"), UiTheme.DIM)
		Narrator.say(Strings.t("workbench.a_new_card_the_workbench") % str(_vectors[0]))
	add_button(Strings.t("workbench.back"), _menu)
	focus_first()


## A letter grade for minigame performance (VD Part 4).
func _grade(perf: float) -> String:
	for g in [[0.95, "S"], [0.8, "A"], [0.6, "B"], [0.4, "C"]]:
		if perf >= float(g[0]):
			return str(g[1])
	return "D"


## The finished card flips in, glowing in its Vector's color.
func _reveal(card: Dictionary) -> void:
	var holder := CenterContainer.new()
	body.add_child(holder)
	var cv := CardView.new()
	cv.setup(card, int(card.get("cost", 0)))
	cv.focus_mode = Control.FOCUS_NONE
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cv)
	var axes := CardRules.ordered_vectors(DataDB.all(), card.get("vectors", {}))
	var glow := UiTheme.vector_color(str(axes[0])) if not axes.is_empty() else UiTheme.ACCENT
	Audio.event("card_play_" + str(axes[0]) if not axes.is_empty() else "card_play_basic")
	cv.pivot_offset = cv.custom_minimum_size / 2.0
	cv.scale = Vector2(0.0, 1.0)
	cv.modulate = glow.lightened(0.5)
	var tw := cv.create_tween()
	tw.tween_property(cv, "scale", Vector2.ONE, 0.25)
	tw.tween_property(cv, "modulate", Color.WHITE, 0.4)


func _copy_menu() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	text(Strings.t("workbench.copies_keep_the_original_s"), UiTheme.DIM)
	var coll: Dictionary = GameState.run.get("collection", {})
	var copy_ap := int(DataDB.table("minigames").get("copyAp", 1))
	for id in coll:
		var card := CardRules.resolve(db, str(id), GameState.cards)
		if not CardRules.is_spell(card):
			continue
		var cid := str(id)
		add_button(Strings.t("workbench.x_mp") % [card.get("name", id), int(coll[id]), CardRules.cost(db, card)], func() -> void:
			if bool(spend_ap.call(copy_ap, "copy")) and Crafting.copy(GameState.run, cid):
				Narrator.say(Strings.t("workbench.another_for_the_pile") % card.get("name", cid))
			_copy_menu(), int(ap_left.call()) < copy_ap)
	add_button(Strings.t("workbench.back"), _menu)
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
	text(Strings.t("workbench.s_deck_cards_min") % [ch.get("name", "?"), _deck.size(), int(db["leveling"].get("deckMin", 8))], UiTheme.ACCENT)
	var st := Crafting.deck_stats(db, GameState.run, _deck)
	var curve: Array = []
	for c in range(0, 8):
		if st["curve"].has(c):
			curve.append("%dMP x%d" % [c, int(st["curve"][c])])
	var mix: Array = []
	for axis in st["mix"]:
		mix.append("%s %d" % [str(axis).capitalize(), int(st["mix"][axis])])
	text(Strings.t("workbench.deck_stats") % [", ".join(PackedStringArray(curve)), ", ".join(PackedStringArray(mix)), int(st["quick"])], UiTheme.DIM)
	var fr := row()
	for f in ["", "quick"] + GameState.player.get("knownVectors", []) + ["burning", "wet", "frozen", "marked"]:
		var key := str(f)
		var b := UiTheme.button(Strings.t("workbench.filter_all") if key == "" else key.capitalize(), func() -> void:
			_filter = key
			_deck_editor())
		b.disabled = key == _filter
		fr.add_child(b)
	var ids: Array = []
	for id in GameState.run.get("collection", {}):
		ids.append(str(id))
	for id in _deck:
		if not ids.has(str(id)):
			ids.append(str(id))
	var axis_order: Array = db.get("spaces", {}).get("arcane", {}).get("axes", [])
	ids.sort_custom(func(x: String, y: String) -> bool:
		var cx := CardRules.resolve(db, x, GameState.cards)
		var cy := CardRules.resolve(db, y, GameState.cards)
		var ax := CardRules.ordered_vectors(db, cx.get("vectors", {}))
		var ay := CardRules.ordered_vectors(db, cy.get("vectors", {}))
		var ix := axis_order.find(ax[0]) if not ax.is_empty() else 999
		var iy := axis_order.find(ay[0]) if not ay.is_empty() else 999
		if ix != iy:
			return ix < iy
		var kx := CardRules.cost(db, cx) if not cx.is_empty() else 0
		var ky := CardRules.cost(db, cy) if not cy.is_empty() else 0
		return kx < ky if kx != ky else x < y)
	for any_id in ids:
		var id := str(any_id)
		var card := CardRules.resolve(db, id, GameState.cards)
		if card.is_empty():
			continue
		if _filter == "quick" and not bool(card.get("quick", false)):
			continue
		var tg := CardRules.tags(db, card)
		if _filter != "" and _filter != "quick" and not card.get("vectors", {}).has(_filter) and not tg["setsUp"].has(_filter) and not tg["paysOff"].has(_filter):
			continue
		var in_deck := _deck.count(id)
		var r := row()
		var l := UiTheme.label(Strings.t("workbench.mp_in_deck_owned") % [card.get("name", id), CardRules.cost(db, card), in_deck, Crafting.owned(GameState.run, ch, id)])
		var badge := Combos.for_vectors(db, card.get("vectors", {})) if CardRules.is_spell(card) else {}
		if not badge.is_empty():
			l.text += " " + Strings.t("workbench.combo_badge") % str(badge.get("name", ""))
		l.custom_minimum_size = Vector2(300, 0)
		# Everything about the card on hover: full text, Form, Magnitude, Vectors, rarity, quick.
		l.tooltip_text = Strings.t("workbench.card_detail") % [CardRules.describe(db, card), str(card.get("form", card.get("kind", ""))).capitalize(),
			str(card.get("magnitude", "-")).capitalize(), ", ".join(PackedStringArray(card.get("vectors", {}).keys())), str(card.get("rarity", "common")).capitalize(),
			Strings.t("workbench.quick_yes") if bool(card.get("quick", false)) else ""]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		r.add_child(l)
		if CardRules.is_spell(card):
			var dg := preload("res://src/scenes/ui/shape_diagram.gd").new()
			dg.setup(DataDB.record("forms", str(card.get("form", ""))), str(card.get("magnitude", "standard")), UiTheme.vector_color(str(card.get("vectors", {}).keys()[0]) if not card.get("vectors", {}).is_empty() else "force"))
			r.add_child(dg)
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
	# Removing cards costs AP; adding is free (PT Part 2).
	var per := deck_save_cost if deck_save_cost >= 0 else int(db["leveling"].get("removeCardCost", 1))
	var cost := per * Crafting.removals(ch.get("deck", []), _deck)
	add_button(Strings.t("workbench.save_deck") + (Strings.t("workbench.ap") % cost if cost > 0 else ""), func() -> void:
		if cost > 0 and not bool(spend_ap.call(cost, "removeCard")):
			return
		Crafting.set_deck(DataDB.all(), GameState.run, GameState.character(_deck_owner), _deck)
		_menu(), err != "" or int(ap_left.call()) < cost)
	add_button(Strings.t("workbench.back_discard_changes"), _menu)
	focus_first()

