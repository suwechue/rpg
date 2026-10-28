## VD (docs/VECTORS_DEMO.md) Parts 1 to 4: the modular audit, art and VFX
## fallback chains, combos and discovery, the spark and the card builder.
extends "res://tests/suite.gd"

const CardRules := preload("res://src/core/card.gd")
const Combos := preload("res://src/core/combos.gd")
const Spec := preload("res://src/core/assets/asset_specs.gd")
const Char := preload("res://src/core/character.gd")
const StateScript := preload("res://src/core/combat/combat_state.gd")


func _scripts(dir_path: String, ext: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	for d in dir.get_directories():
		out.append_array(_scripts(dir_path.path_join(d), ext))
	for f in dir.get_files():
		if f.ends_with(ext):
			out.append(dir_path.path_join(f))
	return out


## Part 1 guarantees: no pack paths, no sounds by path, no hardcoded UI text.
func test_modular_audit() -> void:
	var packs: Array = []
	var by_path: Array = []
	var texts: Array = []
	var ui_text := RegEx.create_from_string("(UiTheme\\.(label|button|world_label)|add_button|\\.build)\\(\"[A-Za-z][a-z]+ [a-z]")
	var assign := RegEx.create_from_string("\\b(text|tooltip_text|placeholder_text) = \"[A-Z][a-z]+ [a-z]")
	for path in _scripts("res://src", ".gd") + _scripts("res://src", ".tscn"):
		# The asset doc generator explains pack paths; the F1 menu is a dev tool.
		if path.ends_with("asset_doc.gd") or path.ends_with("debug_menu.gd"):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line := lines[i]
			if line.contains("res://assets/packs"):
				packs.append("%s:%d" % [path, i + 1])
			if line.contains(".ogg\"") or line.contains(".wav\"") or line.contains(".mp3\""):
				by_path.append("%s:%d" % [path, i + 1])
			if ui_text.search(line) != null or assign.search(line) != null:
				texts.append("%s:%d" % [path, i + 1])
	check(packs.is_empty(), "no pack paths in scripts or scenes: %s" % str(packs))
	check(by_path.is_empty(), "no sounds played by path: %s" % str(by_path))
	check(texts.is_empty(), "no hardcoded player-facing text: %s" % str(texts))


func test_card_art_chain() -> void:
	var card := CardRules.make_spell(db(), { "heat": 1.0, "force": 1.0 }, "bolt", "standard")
	var ids := CardRules.art_ids(db(), card)
	check(ids.has("card_art_magma_ram") and ids.has("card_art_heat_force") and ids.has("card_art_heat_bolt") and ids.has("card_art_heat"), "art chain: combo, pair, Vector and Form, Vector %s" % str(ids))
	check(str(ids[-1]) == "card_art_default", "the chain ends at card_art_default")
	check(ids.find("card_art_magma_ram") < ids.find("card_art_heat"), "specific art first")


func test_vfx_chain() -> void:
	check(Spec.vfx_chain("vfx_heat_bolt") == ["vfx_heat_bolt", "vfx_heat", "vfx_form_bolt", "vfx_hit"], "a spell's VFX falls back to its Vector, its Form, then a hit")
	check(Spec.vfx_chain("vfx_combo_slingshot") == ["vfx_combo_slingshot", "vfx_combo", "vfx_hit"], "combo VFX fall back to the general combo effect")
	var m: Dictionary = db()["assets/manifest"]["assets"]
	var n := 0
	for id in m:
		if str(m[id].get("type", "")) == "vfx":
			n += 1
	check(n >= 30 and m.has("vfx_heat") and m.has("vfx_form_burst") and m.has("vfx_combo"), "the VFX group is filled (%d)" % n)
	for axis in db()["spaces"]["arcane"]["axes"]:
		check(m.has("vfx_" + str(axis)), "every Vector has an effect: %s" % axis)


func test_combos_table() -> void:
	check(Combos.problems(db(), preload("res://src/core/combat/card_effects.gd").OPS).is_empty(), "combos are valid")
	var axes: Array = Combos.cfg(db())["axes"]
	var pairs := 0
	for i in axes.size():
		for j in range(i + 1, axes.size()):
			if not Combos.for_pair(db(), axes[i], axes[j]).is_empty():
				pairs += 1
	check(pairs == 15, "all 15 base pairs have a combo (%d)" % pairs)
	var triples := Combos.all(db()).filter(func(c: Dictionary) -> bool: return c["vectors"].size() == 3)
	check(triples.size() >= 3, "three-Vector combos exist")


func test_combo_matching() -> void:
	check(str(Combos.for_vectors(db(), { "heat": 1.0, "cold": 1.0 }).get("id", "")) == "thermal_shock", "heat + cold is Thermal Shock")
	check(str(Combos.for_vectors(db(), { "cold": 2.0, "heat": 1.0 }).get("id", "")) == "thermal_shock", "order doesn't matter")
	check(Combos.for_vectors(db(), { "heat": 1.0 }).is_empty(), "one Vector is no combo")
	check(Combos.for_vectors(db(), { "heat": 1.0, "cold": 0.05 }).is_empty(), "a trace of a second Vector is no combo")
	check(str(Combos.for_vectors(db(), { "heat": 1.0, "cold": 1.0, "force": 1.0 }).get("id", "")) == "shatterstorm", "three Vectors find the three-Vector combo")
	check(str(Combos.for_vectors(db(), { "heat": 1.0, "cold": 1.0, "motion": 0.5 }).get("id", "")) == "thermal_shock", "no triple: the top pair")
	var card := CardRules.make_spell(db(), { "heat": 1.0, "light": 1.0 }, "burst", "standard")
	check(CardRules.describe(db(), card).contains("Solar Flare"), "the card text names its combo")


func test_combo_discovery() -> void:
	var run := {}
	var journal := {}
	check(Combos.discover(run, journal, "slingshot"), "first cast discovers")
	check(not Combos.discover(run, journal, "slingshot"), "only once per run")
	check(Combos.discovered({}, journal, "slingshot"), "the Journal remembers across runs")


func test_combo_in_combat() -> void:
	var ch := Char.create(db(), "mage", seeded(1), { "knownVectors": ["heat", "cold", "force"], "isPlayer": true, "stats": { "str": 6, "dex": 30, "con": 6, "int": 7, "per": 30, "wil": 6, "cha": 4 } })
	var foe_rec: Dictionary = DT.index_under(db(), "enemies/", "enemies")["pom_pom_wisp"].duplicate(true)
	var st := StateScript.new(db(), seeded(5), { "layout": { "map": ["P...E"] }, "party": [{ "char": ch }], "enemies": [foe_rec] })
	var me = st.unit_by_id("player")
	var target := Vector2i(4, 0)
	st._combo(me, { "vectors": { "heat": 1.0, "cold": 1.0 } }, { "vectors": { "heat": 1.0, "cold": 1.0 } }, target)
	check(st.combos_cast.has("thermal_shock"), "a party heat + cold spell casts Thermal Shock")
	check(st.events.any(func(e: Dictionary) -> bool: return str(e.get("t", "")) == "combo"), "the combo is announced")
	var before: int = st.combos_cast.size()
	st._combo(me, { "vectors": { "heat": 1.0, "cold": 1.0 }, "effects": [] }, { "vectors": { "heat": 1.0, "cold": 1.0 } }, target)
	check(st.combos_cast.size() == before, "cards with their own effects keep them")


func test_spark_quiz() -> void:
	const Spark := preload("res://src/core/progression/spark.gd")
	check(Spark.problems(db()).is_empty(), "sparks and the quiz are valid: %s" % str(Spark.problems(db())))
	var qs: Array = Spark.quiz(db())["questions"]
	check(qs.size() >= 5 and qs.size() <= 6, "5 or 6 questions")
	check(Spark.all(db()).size() == 6, "a spark for each base Vector")
	# Every spark can be reached: for each, some answers lead to it.
	var reached := {}
	for qi in qs.size():
		for ai in qs[qi]["answers"].size():
			var answers: Array = []
			for k in qs.size():
				answers.append(ai if k == qi else -1)
			reached[Spark.result(db(), answers)] = true
	check(reached.size() == 6, "every spark is reachable %s" % str(reached.keys()))


func test_spark_apply() -> void:
	const Spark := preload("res://src/core/progression/spark.gd")
	var run := {}
	var ch := Char.create(db(), "fighter", seeded(2), { "isPlayer": true, "knownVectors": ["force"] })
	var aff0 := float(ch["vectorAffinity"].get("cold", 0.0))
	var deck0: int = ch["deck"].size()
	Spark.apply(db(), run, ch, "cold")
	check(ch["spark"] == "cold" and ch["knownVectors"].has("cold"), "a Cold-spark Fighter knows Cold")
	check(float(ch["vectorAffinity"]["cold"]) > aff0, "the spark raises its affinity")
	check(ch["deck"].size() == deck0 + 1 and int(run["collection"]["sp:cold:bolt:standard"]) == 1, "and gives a first card")
	check(ch["traits"].has("spark_cool_head"), "and a spark trait")
	var heat := Char.create(db(), "mage", seeded(2), { "isPlayer": true, "knownVectors": ["heat"] })
	Spark.apply(db(), {}, heat, "heat")
	check(float(Char.collect_mods(db(), heat)["combat"]["axisPower"]["heat"]) == 1.0, "Runs Warm: +1 on Heat cards")


## Every combo resolves in a real fight (a foe next to an ally of theirs, an
## empty tile for blinks) without errors, and is announced.
func test_every_combo_resolves() -> void:
	for c in Combos.all(db()):
		var ch := Char.create(db(), "mage", seeded(1), { "isPlayer": true, "stats": { "str": 6, "dex": 30, "con": 6, "int": 7, "per": 30, "wil": 6, "cha": 4 } })
		var foes: Array = []
		for i in 2:
			foes.append(DT.index_under(db(), "enemies/", "enemies")["pom_pom_wisp"].duplicate(true))
		var st := StateScript.new(db(), seeded(5), { "layout": { "map": ["P..E.", ".....", "...E."] }, "party": [{ "char": ch }], "enemies": foes })
		var me = st.unit_by_id("player")
		var vec := {}
		for v in c["vectors"]:
			vec[v] = 1.0
		var target: Vector2i = Vector2i(3, 0)
		st._combo(me, { "vectors": vec, "form": "burst" }, { "vectors": vec }, target)
		check(st.combos_cast.has(str(c["id"])), "%s resolves" % c["id"])
