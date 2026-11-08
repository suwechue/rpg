## What the Lab has picked, across scene changes: the fight, the preset, lever
## changes, the party, and an A/B run in progress. Static on purpose (a dev tool,
## nothing to save). The real run is parked here while the Lab uses a throwaway one.
extends RefCounted

static var fight_id := ""
static var preset_id := ""
static var overrides: Dictionary = {}
static var picks: Array = []
static var ab: Dictionary = {}        # { "fight", "a", "b", "stage": 0 or 1 }
static var parked: Dictionary = {}    # the real run while in the Lab
static var parked_scene := ""
static var has_parked := false
static var mastery: Dictionary = {}   # cardMastery: card id -> uses across this Lab session
static var relics: Array = []         # storyRelics: relics dropped this Lab session


static func reset_ab() -> void:
	ab = {}


## Start an A/B pair: stage 0 plays preset a, stage 1 plays preset b, same seed.
static func start_ab(fight: String, a: String, b: String) -> void:
	ab = { "fight": fight, "a": a, "b": b, "stage": 0 }


## A series of A/B pairs (the Lab Tuner shortlist, docs/LAB_TUNER.md Part 6):
## steps [{ fight, a, b }]; "winner" as a or b means the preset picked last.
static func start_series(steps: Array) -> bool:
	if steps.is_empty():
		return false
	var first: Dictionary = steps[0]
	start_ab(str(first["fight"]), str(first["a"]), str(first["b"]))
	ab["queue"] = steps.slice(1)
	fight_id = str(first["fight"])
	return true


## After a pick: the next pair of the series ({} when it's over). A tie keeps a.
static func next_in_series(pick: String) -> Dictionary:
	var queue: Array = ab.get("queue", [])
	if queue.is_empty():
		return {}
	var won := pick if pick != "" else str(ab.get("a", ""))
	var step: Dictionary = queue[0]
	var a := won if str(step["a"]) == "winner" else str(step["a"])
	var b := won if str(step["b"]) == "winner" else str(step["b"])
	var rest := queue.slice(1)
	start_ab(str(step["fight"]), a, b)
	ab["queue"] = rest
	fight_id = str(step["fight"])
	return ab


static func ab_preset() -> String:
	if ab.is_empty():
		return ""
	return str(ab["a"]) if int(ab["stage"]) == 0 else str(ab["b"])
