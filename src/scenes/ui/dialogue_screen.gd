## Talking to someone: portrait, Bond tier and mood; topics (1 AP each, greyed
## with a hint when Gated); gifts (1 AP); hanging out (2 AP); asking them to
## join. A misheard line shows what you meant, then what they heard.
## Story hooks can add options through `extra_options`.
extends "res://src/scenes/ui/modal.gd"

const VO := preload("res://src/core/vector_ops.gd")
const Dlg := preload("res://src/core/social/dialogue_check.gd")
const BondRules := preload("res://src/core/social/bonds.gd")
const DT := preload("res://src/core/data_tables.gd")

static var extra_options: Array = []   # Callables(npc_id) -> [{ "label", "run": Callable(screen), "disabled", "tip" }]

var npc_id := ""
var opts: Dictionary = {}


func _ready() -> void:
	var rec: Dictionary = DataDB.table("npcs/" + npc_id)
	build(str(rec.get("name", npc_id)), 410)
	_menu()


func _social(key: String, fallback: Variant) -> Variant:
	return DataDB.table("social").get(key, fallback)


func header() -> void:
	var rec: Dictionary = DataDB.table("npcs/" + npc_id)
	var r := row()
	var portrait := TextureRect.new()
	var path := str(rec.get("portrait", ""))
	if ResourceLoader.exists(path):
		portrait.texture = load(path)
	portrait.custom_minimum_size = Vector2(38, 38)
	r.add_child(portrait)
	var bond := float(GameState.bonds.get(npc_id, 0.0))
	var tier := Dlg.bond_tier(DataDB.all(), bond)
	var mood := Dlg.mood(DataDB.all(), GameState.run, npc_id, int(GameState.run.get("day_count", 0)))
	var info := UiTheme.label("%s\nBond %d (%s). They %s." % [rec.get("role", ""), roundi(bond), tier,
		str(_social("moodText", {}).get(mood, ""))], UiTheme.DIM)
	r.add_child(info)


func _greeting() -> String:
	var rec: Dictionary = DataDB.table("npcs/" + npc_id)
	var wl: Dictionary = rec.get("weekLines", {})
	if wl.has(str(Calendar.week())):
		return str(wl[str(Calendar.week())])
	if npc_id == "narrator":
		return Narrator.line("greeting")
	return str(rec.get("greeting", "..."))


func _menu() -> void:
	clear_body()
	header()
	var db: Dictionary = DataDB.all()
	var rec: Dictionary = DataDB.table("npcs/" + npc_id)
	text("\"%s\"" % _greeting())
	var ap_topic := int(_social("topicAp", 1))
	var ctx := GameState.ctx()
	for t in Dlg.topics(db, GameState.run, npc_id, ctx):
		var topic: Dictionary = t
		var lock := Dlg.topic_lock(db, GameState.run, npc_id, topic, ctx)
		var label := "%s (%d AP)" % [topic.get("label", "?"), ap_topic]
		if lock != "":
			label = "%s  [%s]" % [topic.get("label", "?"), lock]
		add_button(label, func() -> void: _say(topic), lock != "" or Calendar.ap() < ap_topic, "Risk: %d%%" % roundi(float(topic.get("baseRisk", 0.05)) * 100.0))
	var gift_ap := int(_social("giftAp", 1))
	if not rec.get("gifts", {}).is_empty() and _has_gifts():
		add_button("Give a gift (%d AP)" % gift_ap, _gift_menu, Calendar.ap() < gift_ap)
	if BondRules.can_hang_out(db, GameState.run, npc_id):
		var hang_ap := int(_social("hangoutAp", 2))
		add_button("Hang out (%d AP)" % hang_ap, func() -> void:
			if Calendar.spend_ap(hang_ap):
				show_result(BondRules.hang_out(DataDB.all(), GameState.run, npc_id, Rng.stream("dialogue"))), Calendar.ap() < hang_ap)
	if bool(rec.get("recruitable", false)) and GameState.character(npc_id).is_empty():
		var block := BondRules.recruit_block(db, GameState.run, npc_id, Calendar.week())
		add_button("Ask them to join your party", _recruit, block != "" or Calendar.ap() < 1, block)
	for hook in extra_options:
		for o in hook.call(npc_id):
			var opt: Dictionary = o
			add_button(str(opt["label"]), func() -> void: await opt["run"].call(self), bool(opt.get("disabled", false)), str(opt.get("tip", "")))
	add_button("Bye", func() -> void: finish(null))
	focus_first()


func _say(topic: Dictionary) -> void:
	if not Calendar.spend_ap(int(_social("topicAp", 1))):
		return
	var r := Dlg.say(DataDB.all(), GameState.run, npc_id, topic, Rng.stream("dialogue"), GameState.ctx())
	var lines: Array = []
	if bool(r["misheard"]):
		lines.append("You meant: \"%s\"" % r["said"])
		lines.append("They heard: \"%s\"" % r["heard"])
		var quip := Narrator.line("misheard")
		if quip != "":
			lines.append("(%s)" % quip)
	else:
		lines.append("You: \"%s\"" % r["said"])
	var reaction := str(r["text"])
	var rec: Dictionary = DataDB.table("npcs/" + npc_id)
	if bool(topic.get("lines_by_week", false)):
		reaction = _greeting()
	if bool(topic.get("hint", false)):
		reaction = Narrator.line("hint")
	lines.append(reaction)
	lines.append_array(r["lines"])
	if npc_id != "narrator" and r["outcome"] != "neutral" and Rng.stream("dialogue").randf() < 0.35:
		var c := Narrator.line("good_talk" if r["outcome"] == "good" else "bad_talk")
		if c != "":
			lines.append("(%s)" % c)
	EventBus.bond_changed.emit("player", npc_id, float(r["bond"]))
	if rec.has("name"):
		Narrator.say("%s: %s" % [rec["name"], reaction])
	show_result(lines)


func _has_gifts() -> bool:
	for id in GameState.run.get("inventory", {}):
		if str(DT.record(DataDB.all(), "items", str(id)).get("kind", "")) == "gift":
			return true
	return false


func _gift_menu() -> void:
	clear_body()
	header()
	text("Give what?", UiTheme.DIM)
	for id in GameState.run.get("inventory", {}):
		var iid := str(id)
		var it := DT.record(DataDB.all(), "items", iid)
		if str(it.get("kind", "")) != "gift":
			continue
		add_button("%s x%d" % [it.get("name", iid), int(GameState.run["inventory"][id])], func() -> void:
			if Calendar.spend_ap(int(_social("giftAp", 1))):
				var r := BondRules.give_gift(DataDB.all(), GameState.run, npc_id, iid)
				show_result(r["lines"]))
	add_button("Back", _menu)
	focus_first()


func _recruit() -> void:
	if not Calendar.spend_ap(1):
		return
	var ch := BondRules.recruit(DataDB.all(), GameState.run, npc_id, Rng.stream("npc"))
	var rec: Dictionary = DataDB.table("npcs/" + npc_id)
	Audio.play_sfx("secret")
	var lines: Array = [str(rec.get("recruitText", "\"I'm in.\""))]
	lines.append("%s joined your roster (Lv %d %s)." % [ch.get("name", ""), int(ch.get("level", 1)), str(ch.get("class", "")).capitalize()])
	if GameState.party_ids.has(npc_id):
		lines.append("They'll come with you tonight. Change the party at Night or with the Party screen.")
	show_result(lines)


## Called by option handlers to show a result and come back to the menu.
func show_result(lines: Array) -> void:
	clear_body()
	header()
	for l in lines:
		text(str(l))
	EventBus.stats_changed.emit("player")
	add_button("Continue", _menu)
	focus_first()
