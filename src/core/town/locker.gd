## Your school locker (ROADMAP M13): items stored away from the inventory
## (run["locker"], item id -> count). Friends' notes live in run["lockerNotes"].
extends RefCounted


static func store(run: Dictionary, id: String) -> bool:
	var inv: Dictionary = run.get("inventory", {})
	if int(inv.get(id, 0)) <= 0:
		return false
	inv[id] = int(inv[id]) - 1
	if int(inv[id]) <= 0:
		inv.erase(id)
	var lk: Dictionary = run.get("locker", {})
	lk[id] = int(lk.get(id, 0)) + 1
	run["locker"] = lk
	run["inventory"] = inv
	return true


static func take(run: Dictionary, id: String) -> bool:
	var lk: Dictionary = run.get("locker", {})
	if int(lk.get(id, 0)) <= 0:
		return false
	lk[id] = int(lk[id]) - 1
	if int(lk[id]) <= 0:
		lk.erase(id)
	var inv: Dictionary = run.get("inventory", {})
	inv[id] = int(inv.get(id, 0)) + 1
	run["inventory"] = inv
	run["locker"] = lk
	return true
