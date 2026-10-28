## Your spark (docs/VECTORS_DEMO.md Part 3): the player's strongest Vector,
## found by the narrator's quiz (data/intro/spark_quiz.json) or picked directly
## once the Journal unlocks it. Sparks are in data/sparks.json.
extends RefCounted

const VO := preload("res://src/core/vector_ops.gd")
const DT := preload("res://src/core/data_tables.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("sparks", {})


static func quiz(db: Dictionary) -> Dictionary:
	return db.get("intro/spark_quiz", {})


static func all(db: Dictionary) -> Array:
	return cfg(db).get("sparks", [])


static func find(db: Dictionary, id: String) -> Dictionary:
	for s in all(db):
		if str(s.get("id", "")) == id:
			return s
	return {}


## Summed Vector weights for the chosen answer index of each question.
static func weights(db: Dictionary, answers: Array) -> Dictionary:
	var parts: Array = []
	var qs: Array = quiz(db).get("questions", [])
	for i in mini(answers.size(), qs.size()):
		var opts: Array = qs[i].get("answers", [])
		var pick := int(answers[i])
		if pick >= 0 and pick < opts.size():
			parts.append(opts[pick].get("weights", {}))
	return VO.blend(parts)


## The spark the answers point to: the strongest weight among the sparks that
## exist, ties by the axis order in spaces.json.
static func result(db: Dictionary, answers: Array) -> String:
	var w := weights(db, answers)
	var order: Array = []
	for axis in db.get("spaces", {}).get("arcane", {}).get("axes", []):
		if not find(db, str(axis)).is_empty():
			order.append(axis)
	if order.is_empty():
		return ""
	var best := str(order[0])
	for axis in order:
		if float(w.get(axis, 0.0)) > float(w.get(best, 0.0)):
			best = str(axis)
	return best


## Give a character their spark: affinity blended up, the Vector known, its
## first card in the deck and collection, and the spark trait.
static func apply(db: Dictionary, run: Dictionary, ch: Dictionary, spark_id: String) -> Dictionary:
	var s := find(db, spark_id)
	if s.is_empty():
		return {}
	ch["spark"] = spark_id
	ch["vectorAffinity"] = VO.blend([ch.get("vectorAffinity", {}), { spark_id: float(cfg(db).get("affinityBoost", 3)) }])
	var known: Array = ch.get("knownVectors", [])
	if not known.has(spark_id):
		known.append(spark_id)
		ch["knownVectors"] = known
	var card := str(s.get("card", ""))
	if card != "":
		var deck: Array = ch.get("deck", [])
		deck.append(card)
		ch["deck"] = deck
		var coll: Dictionary = run.get("collection", {})
		coll[card] = int(coll.get(card, 0)) + 1
		run["collection"] = coll
	var tr := str(s.get("trait", ""))
	if tr != "":
		var traits: Array = ch.get("traits", [])
		if not traits.has(tr):
			traits.append(tr)
			ch["traits"] = traits
	return s


## Problems in the spark and quiz tables (DataDB and tests).
static func problems(db: Dictionary) -> Array:
	var out: Array = []
	var axes: Array = db.get("spaces", {}).get("arcane", {}).get("axes", [])
	var traits := DT.index_under(db, "traits", "traits")
	for s in all(db):
		var id := str(s.get("id", ""))
		if not axes.has(id):
			out.append("spark %s: not a Vector" % id)
		if not traits.has(str(s.get("trait", ""))):
			out.append("spark %s: unknown trait '%s'" % [id, s.get("trait", "")])
	for q in quiz(db).get("questions", []):
		for a in q.get("answers", []):
			for axis in a.get("weights", {}):
				if find(db, str(axis)).is_empty():
					out.append("spark quiz: '%s' weights '%s', which has no spark" % [a.get("label", "?"), axis])
	return out
