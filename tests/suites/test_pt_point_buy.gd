## PT Part 9: point-buy stats at run start.
extends "res://tests/suite.gd"

const PB := preload("res://src/core/progression/point_buy.gd")
const Char := preload("res://src/core/character.gd")


func test_costs_and_limits() -> void:
	var st := PB.blank(db())
	check(PB.spent(db(), st) == 0 and PB.left(db(), st) == 20, "all stats start at 3 with 20 points to spend")
	check(PB.stat_cost(db(), 8) == 5 and PB.stat_cost(db(), 9) == 7 and PB.stat_cost(db(), 10) == 9, "1 per point to 8, then 2 per point")
	var high := st.duplicate()
	high["str"] = 11
	check(PB.error(db(), high) != "", "nothing above 10 at creation")
	var over := PB.blank(db())
	for s in ["str", "dex", "con"]:
		over[s] = 10
	check(PB.error(db(), over) != "", "27 points is over budget")
	check(PB.step(db(), PB.blank(db()), "int", -1) == PB.blank(db()), "can't go below 3")


func test_recommended_random_bonus() -> void:
	for cls in ["mage", "fighter", "rogue", "healer", "bard"]:
		var rec := PB.recommended(db(), cls)
		check(PB.error(db(), rec) == "" and PB.left(db(), rec) == 0, "%s: Recommended is legal and spends everything" % cls)
	var rnd := PB.random(db(), seeded(4))
	check(PB.error(db(), rnd) == "" and PB.left(db(), rnd) <= 1, "Random is legal and spends (almost) everything")
	var final := PB.final_stats(db(), "mage", PB.blank(db()))
	check(int(final["int"]) == 4 and int(final["wil"]) == 4 and int(final["str"]) == 3, "the class adds its small bonus on top")
	var ch := Char.create(db(), "mage", seeded(1), { "stats": PB.final_stats(db(), "mage", PB.recommended(db(), "mage")) })
	check(int(ch["stats"]["int"]) == 10, "a character built from point buy keeps those stats")


func test_story_and_arena_runs() -> void:
	const RM := preload("res://src/core/run/run_model.gd")
	var final := PB.final_stats(db(), "rogue", PB.recommended(db(), "rogue"))
	var run := RM.new_run(db(), 1, "rogue", seeded(1), { "stats": final })
	check(int(run["player"]["stats"]["dex"]) == int(final["dex"]), "a story run starts with the point-buy stats")
	var ch := Char.create(db(), "fighter", seeded(2))
	ch["stats"]["str"] = int(ch["stats"]["str"]) + 2
	var before := int(ch["stats"]["str"])
	PB.apply_to(db(), ch, PB.blank(db()))
	var start := 0
	for c in db()["classes"]["classes"]:
		if c["id"] == "fighter":
			start = int(c["startStats"]["str"])
	check(int(ch["stats"]["str"]) == before + int(PB.final_stats(db(), "fighter", PB.blank(db()))["str"]) - start, "arena members keep their level-up gains")
