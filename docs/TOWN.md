# Town Plan: Project Vector

Every named character has a home on the map, and the town has room to grow: some places are open in the alpha, some are buildings you can walk up to but not enter yet, and some are closed with a story hook for later. Character details are in `docs/characters.md`. The town name is still a placeholder (`TOWN_NAME`).

## Status legend

| Status | In the alpha | Later |
| --- | --- | --- |
| **OPEN** | Enterable, NPCs, activities, costs AP as designed | — |
| **EXTERIOR** | Building on the map with a nameplate or mailbox. Trying the door gives a narrator line (or the resident, if they're home). Not enterable. | Interior gets built in an expansion |
| **CLOSED** | Fenced, boarded or signed shut. Interacting gives a narrator line that hints at the future. | Opens as new story content |
| **STORY** | Locked until a story flag, then opens | — |

Each location is a data record (`data/town/locations.json`) with: `id`, `name`, `zone`, `status`, `residents`, `hours` (by day part), `activities`, `doorLine` (what the narrator says at a locked door), `futureHook` (a design note, not shown in game), and `upsideDown` (whether it has a mirror version). Changing a status from EXTERIOR to OPEN must be a data change plus a new interior scene, nothing else.

## Zones

Four walkable zones joined by roads. The bus stop network (fast travel, week 2) connects them.

```
                 [Hillside]
                     |
[Outskirts] — [Downtown] — [School]
                     |
              [Residential]
```

Residential and Hillside are one zone for loading purposes ("residential"); Hillside is its uphill north end.

---

## School (zone: school)

| Place | Status | Who / when | Notes |
| --- | --- | --- | --- |
| Front steps | OPEN | Kelly and the cheer squad, Before School | Story scenes, first day |
| Hallways | OPEN | Dex (getting mildly in trouble between periods) | Lockers, notice board |
| Cafeteria | OPEN | Lunch: Kelly's center table, Dex mid-bit, Sam, Jon and Kris | Main Lunch social hub; future Schoolamon table |
| Gym | OPEN | Coach Byrne (PE); Phase, Mel after school | PE class |
| Field | OPEN | Cheer practice (Kelly, Kara, Kayla), team practice (Phase), basketball (Mel) After School | Week 1 boss source (pep rally) |
| Physics and Chemistry lab | OPEN | Ms. G; Theo after school | Physics, Chemistry |
| Earth Science room | OPEN | Earth Science Teacher | Earth Science; signature hints |
| Biology room | OPEN | Biology Teacher | Biology |
| History room | OPEN | Ms. Nonsense | History; lore |
| Drama room | OPEN | Mr. Mustard; drama club After School | Drama |
| Debate hall | OPEN | Mr. Mustard; Priya leads debate club After School; Baxter | Debate |
| Shop classroom | OPEN | Mr. J, often alone late After School | Shop Class; secret project hint |
| Art room | OPEN | Mara (periods) | Not a scheduled class; social spot |
| Admin office | OPEN | Mr. B, Before School to After School | Dialogue only; detention scenes |
| Teacher's lounge | CLOSED | — | "Staff only. Somebody has labeled every single mug." |
| Roof access | CLOSED | — | Future secret area; candidate for Sam, Unmasked |
| Boiler room (basement) | CLOSED | — | "Warm air leaks under the door. It shouldn't be warm." Future Upside-Down leak point |

**Nap spots (rotating, for Sam and Kris):** bleachers, back row of the library, art room supply closet, under the stairs, shop class sawdust corner, a bench at the park. Each day the game samples one spot per sleeper.

## Downtown (zone: downtown)

| Place | Status | Who / when | Notes |
| --- | --- | --- | --- |
| Town square | OPEN | Mayor (most parts), Innocent Bystander (always), Jake (early game), weekend crowds | Notice board for side quests, weekly town events |
| Gary's Deli | OPEN | Gary (all non-school hours, longer on weekends); Phase on shifts | Food buffs, shifts, gossip; week 2 boss source |
| Gary's apartment (above the deli) | EXTERIOR | Gary | Planned interior: old town photos, the recipe safe |
| Town Library | OPEN | Ms. Marlowe; students at Lunch (Theo, Priya, Baxter, Penny, Diane) | Shares a building with the high school, joined by a covered walkway, so students can reach it at Lunch |
| Arcade | OPEN | Dex, Jon (After School, weekends); Kelly and the squad (weekends) | DEX minigames; hangout |
| Hospital | OPEN | Dr. Reyes (Period 1 to After School), Nurse Patti (volunteer desk) | Healing items, volunteering, injuries |
| Hospital closed wing | STORY | — | Opens with the week 4 story flag; Night Ward source |
| Town hall | EXTERIOR | Mayor, Mr. B (weekend meetings) | Planned interior: Mayor's office, records room (Mr. B evidence later) |
| Bus stop (downtown) | OPEN from week 2 | — | Fast travel hub |
| Corner store | EXTERIOR | — | Planned: second shop for snacks and gifts |
| Movie theater | CLOSED | — | "Closed for renovations. The marquee still says the last film's title, but the letters keep changing." |
| Town museum | CLOSED | — | "Reopening soon." Future town-history and Upside-Down lore content |
| Post office | EXTERIOR | — | Planned: letters and deliveries side quests |

## Residential, Maple Street (zone: residential, south end)

Ordinary family homes and apartments.

| Home | Status | Resident(s) | Notes |
| --- | --- | --- | --- |
| Player's home | OPEN | Player, Parent/Guardian | Workbench, Night actions, save point |
| Theo's house | EXTERIOR | Theo | Planned interior. A telescope in the upstairs window |
| Mara's house | EXTERIOR | Mara | Planned interior. A painted mural on the garage door |
| Dex's house | EXTERIOR | Dex | Planned interior. A whoopee cushion on the doormat |
| Jon's house | EXTERIOR | Jon | Collectible figures in every window |
| Kris's house | EXTERIOR | Kris | Next door to Jon's. Lights out by 9, always |
| Jake's house | EXTERIOR | Jake | The garage is full of abandoned hobby projects; a new anvil out front |
| Phase's house | EXTERIOR | Phase | Basketball hoop, sports gear on the lawn |
| Mel's house | EXTERIOR | Mel | Hoop out back, and a stern note about homework on the door |
| Diane's house | EXTERIOR | Diane | Very tidy. The mailbox is labeled with a label maker |
| Kara's house | EXTERIOR | Kara | — |
| Kayla's house | EXTERIOR | Kayla | — |
| Todd's house | EXTERIOR | Todd | Lights never on. Nobody ever sees him leave or arrive |
| Innocent Bystander's house | EXTERIOR | Innocent Bystander | The most normal house on the street, on purpose |

## Residential, Elm Street apartments (zone: residential, middle)

Where most of the adult staff live.

| Home | Status | Resident(s) | Notes |
| --- | --- | --- | --- |
| Elm Street Apartments (building) | EXTERIOR | Nurse Patti, Ms. Marlowe, Mr. Mustard, Earth Science Teacher, Biology Teacher | One building, with a nameplate panel by the door listing every resident |
| Coach Byrne's house | EXTERIOR | Coach Byrne | Trophies visible in the window; a tire-flip area in the yard |
| Ms. G's house | EXTERIOR | Ms. G | A homemade antenna on the roof that hums |
| Mr. J's house and garage | EXTERIOR | Mr. J | Planned interior: the secret-project workshop. The garage light is on at night |
| Ms. Nonsense's house | EXTERIOR | Ms. Nonsense | Immaculate lawn. A "No Soliciting" sign, and a second "I Mean It" sign under it |

## Hillside (zone: residential, north end, uphill)

The wealthy end of town, which overlooks the abandoned mansion.

| Home | Status | Resident(s) | Notes |
| --- | --- | --- | --- |
| Kelly's house | EXTERIOR | Kelly | Planned interior (story-heavy). Big, quiet and too clean |
| Priya's house | EXTERIOR | Priya | Planned interior. Debate trophies in the window |
| Baxter's house | EXTERIOR | Baxter | Hedges trimmed into perfect cubes |
| Penny's house | EXTERIOR | Penny | Next door to Baxter's, which they both hate |
| Sam's family estate | EXTERIOR (gated) | Sam's family | Planned interior. Behind a big gate, which says a lot about "his family is more intense than he lets on". Possible link to Sam, Unmasked |
| Mayor's residence | EXTERIOR | Mayor | Planned interior: evidence of Mr. B's leverage |
| Mr. B's house | EXTERIOR | Mr. B | Planned interior: late-game infiltration. The curtains are always drawn |
| Dr. Reyes's house | EXTERIOR | Dr. Reyes | Near the hospital road. Her study light is on late |

## Outskirts (zone: outskirts)

| Place | Status | Who / when | Notes |
| --- | --- | --- | --- |
| The blacksmith's forge | OPEN | Blacksmith (Before School, After School, weekends all day); Jake once his questline starts | Gear, apprenticeship; week 3 boss source |
| Blacksmith's cottage | EXTERIOR | Blacksmith | Behind the forge |
| Park and woods edge | OPEN | Narrator (first appears here), Mara (sketching After School), Earth Science field trips | Upside-Down entrance; PER training |
| Bus stop (outskirts) | OPEN from week 2 | — | — |
| Abandoned lot | STORY | — | Secret area; hints at the Upside-Down's origin |
| Train station | CLOSED | — | "Service suspended until further notice." The departures board still flickers. Future: leaving town, new regions, Todd's disappearances (maybe) |
| Abandoned mansion | CLOSED | — | Gated, on the hill past Hillside. Future major area; candidate for deep Upside-Down history and Mr. B's past |
| Old factory | CLOSED | — | Fenced off. Use `kenney_tiny_factory`. Future dungeon or story site |
| Water tower | CLOSED | — | Ladder locked. Future lookout and secret |
| Cemetery | CLOSED | — | Gate chained. Future lore: names of people the Upside-Down took |
| Lake and boathouse | CLOSED | — | "Swimming season closed." Future fishing and summer content |

---

## Rules for building it (M5)

- Every resident in the tables above has a `home` field in their NPC record pointing at their home's location id. Characters go home outside their scheduled hours, so you can see them through the window or catch them at the door.
- At an EXTERIOR door, the resident can come to the door if they're home and it's not Night: a short doorstep conversation using their normal dialogue topics, at the usual AP cost. Otherwise the narrator gives the door line.
- CLOSED places show their state clearly: boards, a fence, a sign or a chain. Never an invisible wall.
- Upside-Down mirrors: the deli, forge, hospital, school field and town square have twisted versions in the matching weeks (DESIGN.md Section 10). Others can be added later by setting `upsideDown: true`.
- Tiles: Kenney Tiny City for downtown streets and cars, Kenney Tiny Town for houses and nature, Ninja Adventure interiors for the school, deli, hospital, forge and the player's home, and Kenney Tiny Factory for the old factory.
- Keep the map readable at 480x270: aim for each zone to be about 3 to 6 screens. Hillside and Maple Street can be dense; downtown should feel busy.
