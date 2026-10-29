## The phone (ROADMAP M18): texts (accept invites to hang out tomorrow), the
## school feed, contacts with Bond and whereabouts, the school calendar, and
## the mystery board. Opens from the HUD.
extends "res://src/scenes/ui/modal.gd"

const Phone := preload("res://src/core/social/phone.gd")

var tab := "texts"


func _ready() -> void:
	build(Strings.t("phone.title"), 400)
	_refresh()


func _refresh() -> void:
	clear_body()
	var db: Dictionary = DataDB.all()
	var tabs := row()
	for t in ["texts", "feed", "contacts", "calendar", "board"]:
		var key: String = t
		var b := UiTheme.button(Strings.t("phone." + key), func() -> void:
			if key == "board":
				visible = false
				await Flow.show_modal(preload("res://src/scenes/ui/board_screen.gd").new())
				visible = true
				return
			tab = key
			_refresh())
		b.theme_type_variation = "SelectedButton" if key == tab else ""
		tabs.add_child(b)
	var dc := int(GameState.run.get("day_count", 0))
	match tab:
		"texts":
			var texts: Array = GameState.run.get("texts", [])
			if texts.is_empty():
				text(Strings.t("phone.no_texts"), UiTheme.DIM)
			for i in range(texts.size() - 1, maxi(-1, texts.size() - 9), -1):
				var t: Dictionary = texts[i]
				var who := str(DataDB.table("npcs/" + str(t["from"])).get("name", t["from"]))
				text(Strings.t("phone.text_row") % [who, str(t["text"])], UiTheme.TEXT if int(t["day"]) == dc else UiTheme.DIM)
				if bool(t.get("skipInvite", false)) and int(t["day"]) == dc and not GameState.run.get("skipInvites", {}).has(str(t["from"])):
					var pal := str(t["from"])
					add_button(Strings.t("phone.accept"), func() -> void:
						Phone.accept_skip(GameState.run, pal, dc)
						Narrator.say(Strings.t("phone.skip_accepted") % who)
						_refresh())
				if bool(t.get("invite", false)) and int(t["day"]) == dc and not GameState.run.get("invites", {}).has(str(t["from"])):
					var from := str(t["from"])
					add_button(Strings.t("phone.accept"), func() -> void:
						Phone.accept_invite(GameState.run, from, dc)
						Narrator.say(Strings.t("phone.accepted") % who)
						_refresh())
		"feed":
			for line in Phone.feed(db, GameState.run, Calendar.week(), _feed_rng(dc)):
				text("- " + str(line))
		"contacts":
			for c in Phone.contacts(db, GameState.run, Calendar.day_name(), Calendar.part_id(), dc):
				text(Strings.t("phone.contact_row") % [str(c["name"]), str(c["tier"]), str(c["where"]) if str(c["where"]) != "" else Strings.t("phone.nowhere")])
		"calendar":
			for line in Phone.calendar(db):
				text(str(line))
	add_button(Strings.t("phone.close"), func() -> void: finish(null))
	focus_first()


## The feed is the same all day (seeded by the day), so reopening doesn't reshuffle it.
func _feed_rng(day_count: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("feed:%d:%d" % [GameState.run_seed, day_count])
	return r
