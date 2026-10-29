## Exams and the report card (ROADMAP M16, data/exams.json): each class in
## your schedule is graded from its stats against the difficulty, plus your
## Grade (attendance) with its teacher. The report card applies the letters'
## effects and your guardian's reaction.
extends RefCounted

const Char := preload("res://src/core/character.gd")
const School := preload("res://src/core/run/school.gd")


static func cfg(db: Dictionary) -> Dictionary:
	return db.get("exams", {})


## A class's exam score (0..100) for this run's player.
static func score(db: Dictionary, run: Dictionary, cls: Dictionary) -> int:
	var st := Char.effective_stats(db, run["player"])
	var stats: Array = cls.get("statGains", [])
	var avg := 0.0
	for s in stats:
		avg += float(st.get(str(s), 5))
	avg = avg / float(maxi(1, stats.size()))
	var grade := float(run.get("grades", {}).get(str(cls.get("professor", "")), 0.0))
	var c := cfg(db)
	var v := 50.0 + float(c.get("statWeight", 6)) * (avg - float(c.get("difficulty", 6))) + float(c.get("gradeWeight", 0.4)) * grade
	return clampi(roundi(v), 0, 100)


static func letter(db: Dictionary, s: int) -> Dictionary:
	for l in cfg(db).get("letters", []):
		if s >= int(l.get("min", 0)):
			return l
	return { "letter": "F", "gpa": 0 }


## The report card: one row per class in the schedule, the GPA and the
## guardian's reaction. { "rows": [{ class, name, professor, score, letter }], "gpa", "parent" }
static func report(db: Dictionary, run: Dictionary, schedule: Array) -> Dictionary:
	var rows: Array = []
	var total := 0.0
	var seen := {}
	for cid in schedule:
		if seen.has(str(cid)):
			continue
		seen[str(cid)] = true
		var cls := School.class_rec(db, str(cid))
		if cls.is_empty():
			continue
		var s := score(db, run, cls)
		var l := letter(db, s)
		rows.append({ "class": str(cid), "name": str(cls.get("name", cid)), "professor": str(cls.get("professor", "")), "score": s, "letter": str(l["letter"]) })
		total += float(l.get("gpa", 0))
	var gpa := total / float(maxi(1, rows.size()))
	var parent := {}
	for p in cfg(db).get("parent", []):
		if gpa >= float(p.get("minGpa", 0)):
			parent = p
			break
	return { "rows": rows, "gpa": gpa, "parent": parent }


## The effects of a report card: each letter's effect with its teacher, then
## the guardian's reaction. Returns effects dictionaries in order, each with
## the professor in "ctx" (for "grade").
static func report_effects(db: Dictionary, rep: Dictionary) -> Array:
	var out: Array = []
	for r in rep["rows"]:
		var fx: Dictionary = cfg(db).get("letterEffects", {}).get(str(r["letter"]), {})
		if not fx.is_empty():
			out.append({ "effects": fx, "ctx": { "professor": str(r["professor"]) } })
	if not rep["parent"].is_empty():
		out.append({ "effects": rep["parent"].get("effects", {}), "ctx": {} })
	return out
