## Player-facing text by key (data/strings.json), for rules code that has the
## data tables. Scenes use the Strings autoload, which reads the same table.
## A missing key shows the key itself, so nothing ever crashes over text.
extends RefCounted


static func t(db: Dictionary, key: String) -> String:
	var table: Dictionary = db.get("strings", {}).get("strings", {})
	return str(table.get(key, key))
