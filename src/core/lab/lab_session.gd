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


static func reset_ab() -> void:
	ab = {}


## Start an A/B pair: stage 0 plays preset a, stage 1 plays preset b, same seed.
static func start_ab(fight: String, a: String, b: String) -> void:
	ab = { "fight": fight, "a": a, "b": b, "stage": 0 }


static func ab_preset() -> String:
	if ab.is_empty():
		return ""
	return str(ab["a"]) if int(ab["stage"]) == 0 else str(ab["b"])
