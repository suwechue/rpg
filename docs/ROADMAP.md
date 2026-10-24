# Project Vector: Phase 2 Roadmap

**Status when this was written (Oct 24, 2026):** The alpha (M0 to M8) is built. A full 5-week run completes, with 35 characters, 134 dialogue topics, 5 bosses, 2.5D combat, the town, the Upside-Down and the Narrator's Journal. It still feels like a prototype. The Upside-Down doesn't look like the town, combat is hard to read, NPCs clump together, buildings look alike, you're dropped into the game with no intro, and the story ends at week 5.

**Phase 2 goal:** turn the alpha into a game that's fun and fully yours. That means replaceable art, a map you can build by hand, a real opening, cutscenes, a living town, a balanced day, and week 5 becoming the end of **Act 1** instead of the end of the game.

Save this file as `docs/ROADMAP.md`. The Claude Code prompt is at the bottom.

## Decision: 32x32 tiles and a 640x360 base resolution

Decided Oct 24, 2026. This overrides the 16x16 / 480x270 setup in DESIGN.md Sections 1 and 16.

| Setting | Before (alpha) | Now |
| --- | --- | --- |
| Tile size | 16x16 | **32x32** |
| Base resolution | 480x270 | **640x360** (about 20x11 tiles on screen) |
| Scaling | Integer, nearest | Integer, nearest: 2x = 1280x720, 3x = 1920x1080, 4x = 2560x1440 |
| Characters | 16x16 | **32x32 for townsfolk**, with room for 32x48 for taller characters and bosses |
| Portraits | Pack faces | **64x64** |
| Combat units | Pack sprites drawn at 2x | Drawn at 1x (already 32 px); bosses can be 64x64 or larger |

Why: 32x32 gives faces and expressions room while staying clearly pixel art and drawable by one person. 64x64 was ruled out because only about 10x6 tiles would fit on screen and every asset would be four times the drawing work.

Rules:
- **No hardcoded 16 or 32 anywhere.** Tile size, base resolution, character size and portrait size live in `data/display.json` and every scene, map, camera, projection and UI reads them from there. Add a test that fails if a literal tile size appears in `src/`.
- **Pack art is a placeholder.** The 16x16 packs are scaled 2x (nearest neighbour) at import into the 32x32 grid until the user's art replaces them. That happens through the M10 asset pipeline: the manifest records each asset's native size and the scale applied, and an `assets/custom/` file at the real 32x32 size replaces it with no other change.
- **Specs in ASSETS.md use the new sizes:** tiles 32x32; characters 32x32, 4 directions x 4 frames; portraits 64x64; card art 48x48; icons 16x16 (UI) or 32x32 (items).
- **The UI is rebuilt for 640x360** (M11): text at the pixel font's native size or an integer multiple, never fractional.
- **Combat projection** (2.5D grid) uses the tile size from display.json; check that the trapezoid cells, sprite anchoring and click-to-cell mapping still work.

---

## Order and why

Tools come first, because everything after them gets built with them. Then come the opening and the daily loop, then depth, then the Act 1 finale, then polish.

| # | Milestone | Depends on |
| --- | --- | --- |
| M9 | Stabilize | — |
| M10 | Replaceable art pipeline | M9 |
| M11 | Swappable UI skin and readable combat | M10 |
| M12 | Modular map building | M10 |
| M12b | Visual variety and full pack usage | M10, M12 |
| M13 | The new school | M12b |
| M14 | Cutscene system | M12 |
| M15 | Intro and tutorial day | M13, M14 |
| M16 | Class scenes, school calendar, clubs and exams | M13, M14 |
| M17 | Living town: random NPCs, party in town, a town that remembers | M12, M14 |
| M18 | Phone, friendship scenes and the mystery board | M14 |
| M19 | Day balance, unlock waves and difficulty modes | M15 to M18 |
| M20 | The Upside-Down as a mirror town, and combat feel | M12, M11 |
| M21 | Act 1 finale: the fountain | M14, M17, M20 |
| M22 | Polish and onboarding | everything |
| M23 | Release prep | everything |

---

## M9: Stabilize

- Commit and push M8. Confirm https://github.com/suwechue/rpg actually has every commit (it was empty when last checked). Fix the push, including the Git LFS setup, if it fails.
- Fix known bugs: "They seems fine" (pronoun and verb agreement in the dialogue screen), status labels stacking over units in combat, and name tags overlapping in crowds.
- Write `docs/PLAYTEST.md`, a checklist for the user to play week 1 and week 5 and note how things feel.
- Add gameplay logging (local file only): AP spent per action type, fights won and lost, time per day. M19 balances from this data.

**Done when:** GitHub has every commit, all tests pass, and a playtest build runs from the title screen.

## M10: Replaceable art pipeline and the 32x32 switch

The user will replace pack art with their own. Make that drag-and-drop, and move the whole game to 32x32 tiles at 640x360 (see the decision at the top).

- **Resolution and tile switch first:** add `data/display.json` (tile size 32, base 640x360, character 32x32, portrait 64x64), update `project.godot` to 640x360 with integer scaling, and make every scene, TileSet, camera, map, NPC, projection and UI read sizes from it. The packs get imported at 2x as placeholders. Re-run all tests, smoke tests and screenshots at the new size before going on.

- **Asset IDs:** every sprite, portrait, tile, animation, sound, music track and icon is referenced by a logical id (`portrait_kelly`, `npc_gary_walk`, `tile_town_road`, `sfx_card_play`, `icon_vector_heat`) listed in `data/assets/manifest.json`. No script or data file points at a pack path directly.
- **Override folder:** `assets/custom/` mirrors the ids. A file there with the same id replaces the pack version automatically (`assets/custom/portraits/portrait_kelly.png`). No code changes, no manifest edits.
- **Specs per id:** size, frame layout (for example "16x16, 4 directions x 4 frames, rows: down, left, right, up"), anchor point and palette notes.
- **`docs/ASSETS.md`:** generated from the manifest by a tool script. It lists every asset grouped by type (characters, portraits, tiles, UI, VFX, audio) with its spec, its current source (pack or custom) and a checkbox for "replaced with my art".
- **Missing art** shows a labeled magenta placeholder with the id written on it, never a crash.
- **Debug menu Art viewer:** browse every id, see the current image and its spec, and hot-reload `assets/custom/` without restarting.
- **Sizes:** tiles 32x32, characters 32x32 (up to 32x48 for tall ones), portraits 64x64. The pipeline still supports a different size per id, so a 32x48 boss or a 16x16 icon works too.

**Done when:** the game runs at 640x360 on a 32x32 grid with no hardcoded sizes, replacing one portrait and one tile in `assets/custom/` shows up in game after a hot reload, and `ASSETS.md` lists every asset the game uses at its target size.

## M11: Swappable UI skin and readable combat

- **One skin folder:** `assets/ui/skin/` holds 9-slice panels, buttons, card frames, bars, cursors and the font. `data/ui.json` holds colors, font sizes and Vector colors. Every screen uses the Godot Theme built from these; no screen styles itself.
- **Card frames:** one template per Vector (color and icon) and per kind (spell, basic, item), with card art slots referencing asset ids (M10).
- **Combat readability:**
  - The initiative timeline shows small portraits, not two-letter names.
  - Cards show Vector color, icon, art, cost and a one-line effect.
  - Statuses are icons with tooltips, never stacked text.
  - Hovering a card previews its footprint and damage.
- **Accessibility hooks:** a colorblind-safe Vector palette option, plus icons and patterns so color never carries meaning alone.

**Done when:** swapping the panel image and one color in `data/ui.json` restyles every screen, and the combat screen passes a "can you tell what's happening at a glance" check in screenshots.

## M12: Modular map building

Replace the runtime-generated town with pieces the user builds in Godot's editor.

- **Pieces ("blocks"):** scenes in `src/world/blocks/`, built on the 32x32 grid, for road segments, intersections, house lots (several styles), shop lots, park pieces, fences and props. Each uses TileMapLayers and asset ids.
- **Markers:** `@tool` nodes the user drags in:
  - `DoorMarker`, linked to a location id from `data/town/locations.json`
  - `NpcSpot`, a place an NPC can stand, with tags like "bench", "counter" or "crowd"
  - `Interactable`
  - `ZoneExit`
  - `SpawnPoint`
  - `CameraBounds`

  Markers show labels and icons in the editor.
- **Zones** are scenes assembled from blocks (`src/world/zones/downtown.tscn` and so on). Doors and exits wire themselves from their marker ids.
- **Validation tool:** a script that checks every location in data has a door marker, every NPC home exists, and every exit leads somewhere. It runs in tests.
- **Building identity:**
  - Every building gets a sign (Gary's Deli, Hospital, Library).
  - Every house gets a nameplate or mailbox.
  - There are at least 4 house styles, and Hillside houses look wealthier.
- **Migration:** rebuild the current four zones with blocks, keeping every location and home from `docs/TOWN.md`.
- **`docs/MAP_GUIDE.md`:** a step-by-step guide for the user to add a street, a building and a new location.

**Done when:** the user can add a new building to downtown by placing a block and a door marker and adding one entry to `locations.json`, following `MAP_GUIDE.md`, with no code.

## M12b: Visual variety and full pack usage

An audit on Oct 24 found most downloaded art unused. Ninja Adventure is used for characters, monsters and audio, but its 20+ tilesets are barely touched. Kenney Tiny Town, City and Dungeon are each used for one stamping style. Tiny Battle, Tiny Factory, Tiny Creatures, DungeonTileset II, UI Pack Pixel Adventure and Input Prompts Pixel are not used at all. The town looks repetitive because of it.

- **Pack inventory:** a tool script that scans `assets/packs/` and writes `docs/ART_INVENTORY.md`. It lists every tileset and sprite sheet with a contact-sheet preview image (in `tools/inventory/`), what it suits (ground, buildings, props, characters, UI, VFX) and whether the game uses it yet. Every pack should be used somewhere by the end of this milestone, or listed as deliberately unused with a reason.
- **Tile variation:**
  - Every ground tile (grass, pavement, dirt, floor, sand) gets 3 to 6 variants (cracks, flowers, stones, wear, stains), using TileSet alternative tiles with weights so painting a large area never looks tiled.
  - Godot **terrain sets** (autotiling) handle transitions: grass to path, path to road, sidewalk edges, water shores, fences and walls. Edges and corners join automatically when painting.
- **Decoration layer:** a seeded **decorator** that scatters props by rules per zone and per block (grass gets flowers and pebbles, sidewalks get trash cans, lamps and benches near shops, yards get fences, bushes, mailboxes and toys). Results are baked into the block so the user can edit them by hand; the decorator can be re-run. Rules live in `data/world/decor_rules.json`.
- **Buildings with identity:**
  - At least 6 house styles mixing roof color, wall material, size, porch and garage from Kenney Tiny Town and Ninja Adventure's TilesetHouse.
  - Hillside uses the larger, fancier set; Maple Street mixes styles so no two neighbours match.
  - Every shop gets its own facade, awning color and sign.
  - The forge, hospital, school, train station, mansion and factory (Tiny Factory) each look unique.
- **Pack roles:**

  | Area | Packs |
  | --- | --- |
  | Downtown | Tiny City (roads, cars, storefronts) mixed with Ninja Adventure floors and props |
  | Residential | Tiny Town plus Ninja Adventure TilesetHouse and TilesetNature |
  | Outskirts | Ninja Adventure TilesetNature, Field, Relief and Water; Tiny Factory for the factory |
  | Interiors | Ninja Adventure Interior |
  | Upside-Down | Tiny Dungeon plus DungeonTileset II plus recolored town tiles (M20) |
  | Combat props and markers | Tiny Battle |
  | Extra creatures | Tiny Creatures for Upside-Down enemies |
  | UI | UI Pack Pixel Adventure (via the M11 skin) |
  | Input prompts | Input Prompts Pixel |

  Mixing packs is fine as long as each zone stays consistent. Write the choices into `docs/ART_INVENTORY.md` as a style guide.
- **Life and motion:**
  - Animated tiles: water, the fountain, flags, flickering streetlamps, smoke from the forge chimney, swaying trees (Ninja Adventure Backgrounds/Animated).
  - Ambient particles: falling leaves, dust, insects at dusk.
  - Parked and slow-moving cars downtown (Tiny City).
- **Time of day:** a lighting tint per day part (warm morning, neutral midday, orange after school, blue night) with lit windows and lamp glow in the evening. Driven by `data/display.json` colors.
- **People variety:** palette and accessory swaps for generated NPCs (also used by M17), so crowds don't look like clones.
- **Everything goes through asset ids** (M10). New variants and props are added to the manifest so the user can replace any of them.

**Done when:** `ART_INVENTORY.md` exists with every pack used or explained, a screenshot of each zone shows no obvious repeated tiling, every house on a street looks different from its neighbours, and the day-part lighting and animated tiles are visible in town.

## M13: The new school

Built with M12 blocks.

- **Layout:**
  - Front entrance and front steps.
  - Main hall with lockers.
  - A science wing (Physics/Chemistry lab, Biology, Earth Science) and an arts wing (Drama, Art room, Debate hall).
  - Shop class off the back.
  - History near the admin office (Mr. B).
  - Cafeteria, gym, the field and bleachers.
  - The covered walkway to the Town Library.
  - Closed: teacher's lounge, roof and boiler room.
- **Classrooms:** desks with a seating chart built from who is in that class this week (from schedules). The teacher at the board. Your seat is marked.
- **Your locker:** storage for items and gifts, and notes left by friends (ties into M18).
- **Bells:** a bell between periods, and students walking the halls during transitions.
- **Nap spots and hangouts** for Sam, Kris and Dex placed as `NpcSpot` markers.

**Done when:** a school day can be walked through end to end with everyone at the right desks and spots.

## M14: Cutscene system

- **Data-driven scripts** in `data/cutscenes/*.json` with steps such as:
  - Moving and actors: `move actor to marker`, `face`, `emote`, `wait`
  - Dialogue: `say` (speaker, portrait, line), `narrator`, `choice` (branches with effects)
  - Presentation: `camera pan/zoom/shake`, `fade`, `play music/sfx`, `show image` (a full-screen illustration by asset id)
  - Logic: `set flag`, `give item`, `start combat`
- Actors are NPCs, the player or temporary props. Positions use M12 markers.
- Skip and fast-forward. Lines have typed text with speed from options.
- **Debug menu:** play any cutscene. Dev flag `--cutscene=id`.
- **`docs/CUTSCENE_GUIDE.md`:** how the user writes a new cutscene in JSON.
- Existing story beats (Kelly's first night, Mr. B scenes, boss intros) are converted to cutscenes.

**Done when:** the existing story scenes play as staged cutscenes with characters moving and emoting.

## M15: Intro and tutorial day

The player is currently dropped straight into the game. Replace that with a real opening.

**Intro (cutscene):** moving day. The truck pulls into town at dusk past the fountain, the train station and the school. The narrator introduces himself and you ("Every town has a story. This one has a hole in it."). Then character creation (name, look, starting class) framed as unpacking your room. Night falls, with a hint of something wrong in the woods.

**Tutorial day (week 1 Monday morning to evening):**

| Day part | What happens | Teaches |
| --- | --- | --- |
| Before School | You oversleep; your parent yells that you're late. Your parent hands you lunch on the way out. Rush to school with a soft timer and the narrator heckling. | Movement and running, interacting, the HUD |
| Period 1 | First class: pick your seat, meet the teacher, a scripted class event. | Attending class and stat gains |
| Period 2 | The schedule screen: the narrator walks you through picking the week's classes. | The weekly schedule |
| Lunch | The cafeteria. Kelly's table, Dex mid-bit, Theo alone. | Dialogue topics, CHA gates, misheard lines, Bond |
| Period 3 | A class event with a choice. | Choices with consequences |
| After School | Walk the town; the narrator points out the deli and the forge. | Action Points, places opening and closing, shops |
| Evening | The existing Kelly tutorial floor in the Upside-Down. | Combat, cards, the Vector Wheel |
| Night | Home, first card crafted at the workbench. | Crafting and the deck |

- Tutorial prompts use input icons from asset ids (keyboard or controller).
- Optional "Skip tutorial" on later runs (unlocked in the Narrator's Journal).

**Done when:** a new run starts with the intro, the full tutorial day plays, and every core mechanic has been introduced before Tuesday.

## M16: Class scenes, school calendar, clubs and exams

- **Class cutscenes:** attending a class plays a short scene in the actual classroom (M13): the teacher at the board, classmates at desks. Then a class event from `data/events/class_events.json`, staged with M14, chosen at random when you stay in class. Seen events are tracked so repeats are rare. Each event type has a short version for repeats so it never drags.
- **More class events:** at least 8 per class per act, with each teacher's personality from `docs/characters.md` (Ms. G's tangents, Mr. Mustard's calm, Ms. Nonsense's grudges, Coach Byrne's drills).
- **School calendar:** fixed set-piece events, each a cutscene plus special activities:
  - Week 1: first day (the tutorial)
  - Week 2: pep rally (ties into the Hollow Mascot aftermath)
  - Week 3: club fair
  - Week 4: test week, then the report card
  - Week 5: school dance on Friday, interrupted by the fountain (M21)
- **Clubs:** join one or two (drama, debate, cheer, shop, art, science) at the club fair. Each costs a weekly commitment (one After School part on club days). In exchange you get stat bonuses, Bond with members and exclusive scenes.
- **Exams and grades:** test week checks stats against each class's difficulty, adjusted by Grade (attendance). The report card has effects: your parent's reaction, teacher Bonds, and unlocks such as advanced class requirements.

**Done when:** a week of school shows staged class scenes, the calendar events fire in their weeks, clubs can be joined, and the report card appears in week 4.

## M17: Living town

- **Random NPCs:** generated students and townsfolk using the design's rolled traits:
  - A name generator.
  - Palette and accessory swaps of base sprites, by asset id, so they look varied.
  - A disposition and traits rolled from data.
  - A small personal topic pool.
  - Rumors that hint at the week's Upside-Down signature.
  - Occasional small favors (fetch an item, deliver a note) for money or Bond.

  They spawn by zone and time of day. Students crowd the halls between periods; townsfolk fill the square on weekends.
- **Routines:** NPCs walk between `NpcSpot` markers instead of standing still. Named characters follow their schedules with walking between places.
- **No more clumping:** a location spreads its occupants across its spots by tag.
- **Ambient lines:** short barks when you walk past, by character and situation.
- **Party in town:** recruited friends can follow you. They comment on places and people you pass, and chat with each other (pair banter lines in data, unlocked by Bond).
- **A town that remembers:** persistent visual changes from choices and story:
  - The forge relit or left cold.
  - Shops opening or closing.
  - Posters for upcoming school events.
  - "Missing" flyers for people taken by the Upside-Down.
  - The fountain crater after week 5.

**Done when:** the town square on a weekend has a believable crowd, nobody overlaps, a party member follows you and comments, and at least 5 choice-driven town changes are visible.

## M18: Phone, friendship scenes and the mystery board

- **Phone** (opens from the HUD and at Night):
  - Texts: friends message you, invite you to hang out tomorrow (which sets up the day), react to events, and send hints.
  - A school feed: rumors and gossip posts, where the Upside-Down signature hints live.
  - Contacts with Bond levels and where to find people today.
  - A calendar of school events.
- **Friendship scenes:** each recruitable character gets an authored hangout cutscene at each Bond tier (Acquaintance, Friend, Close, Unbreakable), like Persona's confidants. Write them from `docs/characters.md`. Kelly and the Core Four need full sets; side students need at least Friend and Close scenes. Unbreakable unlocks their personal arc and unique card.
- **Mystery board** (in your room, and on the phone):
  - Clues about Mr. B, the disappearances, the Upside-Down's origin and the narrator are collected from dialogue, events, the library and the dungeon.
  - Linking two related clues forms a deduction, which unlocks dialogue options, story choices and lore.
  - The week 3 cover-up and week 4 trust choices get extra options with enough deductions.

**Done when:** texts arrive at Night and set up hangouts, every recruitable has at least two friendship scenes, and the mystery board can produce a deduction that changes a story choice.

## M19: Day balance, unlock waves and difficulty modes

- **AP balance target:** the player can do about 60% of what they want each day, so every part is a real choice but days never feel wasted. Use M9 logging plus simulated "greedy" and "social" players to tune:
  - AP per part
  - Costs per action
  - Which actions are free (walking, reading signs, short barks)
  - Weekend AP

  Consider small AP boosts from food, perks and traits.
- **Unlock waves:** week 1 is small on purpose; more opens each week.

  | Week | Opens up |
  | --- | --- |
  | 1 | Home, school, deli, forge, hospital, square |
  | 2 | Bus stops, clubs, the arcade, part-time jobs, side students start recruiting |
  | 3 | Library deep lore, more shops, the corner store, more recruits |
  | 4 | Test week, the hospital closed wing, more recruits |
  | 5 | The dance, then the fountain (M21) |

  The narrator announces what's new each Monday.
- **Part-time jobs:** deli (Gary), forge, hospital volunteering and the library, each with a tiny minigame or event, money and Bond.
- **Difficulty modes,** chosen at new run:
  - **Permadeath:** the default, as designed.
  - **Narrator's Mercy:** dying rewinds to the start of that day, with a narrator quip.
  - **Story:** easier fights.

  The Journal records which mode each run used.

**Done when:** the AP target is met in simulation and in the user's playtest notes, each week unlocks something visible, and all three difficulty modes work.

## M20: The Upside-Down as a mirror town, and combat feel

- **Mirror rooms:** hand-built room blocks (M12) that are twisted versions of real places. For example: a frozen deli with sausages hanging like icicles, the school hallway stretched with lockers breathing, the forge as a furnace maze, the hospital with endless corridors. Each week's floors mix generic rooms with the places that week's story touched and places the player visited that week.
- **The look:** a shader on Upside-Down scenes (palette shift toward the week's signature color, slight wobble, vignette, inverted shadows). Ambient sound.
- **Combat feel:**
  - An animation and VFX for each Vector (fire, frost, a push shockwave, motion trails, binding chains, light flares) and each Form.
  - Damage numbers.
  - Hit pause and screen shake on big hits.
  - **Enemy intent preview** (an icon over each enemy showing what it plans next turn).
  - A clear death and downed animation.
- **Balance:** re-run `tools/sim_run.gd` and the user's playtests. Target: an average player clears week 1 most of the time, and boss fights feel tense but fair.

**Done when:** each week's floors are recognizably the town, every Vector has a visible effect, and enemy intent is shown.

## M21: Act 1 finale, the fountain

Week 5 is no longer the end. It's the end of **Act 1**.

- **Friday of week 5:** the school dance (M16). Mid-dance, the town fountain explodes: the Upside-Down breaks into daylight. This is a big cutscene with the whole cast and the narrator going quiet for the first time. Then the Mirror Town boss fight, set in the square itself, half real and half twisted.
- **Aftermath (the weekend after):**
  - The fountain is a glowing crater, a permanent landmark.
  - Leak points open around town where small Upside-Down fights can happen in daylight.
  - The town reacts: closures, curfew posters, the Innocent Bystander's numbest line yet.
  - The fallout from Mr. B's reveal plays out.
- **Act 2 hook:** a short teaser of the new rules. Leak points in daylight, maybe the train station reopening, the abandoned mansion stirring. Then "End of Act 1" and save-to-continue.
- **Act 2 design stub:** write `docs/ACT2.md` with:
  - What changes: daylight fights, new town state, new locations opening (train station, mansion, factory, lake).
  - New weeks and bosses (placeholders).
  - Where the narrator reveal fits (still undecided).
  - Story threads to continue (each character's arc, Sam Unmasked, Todd).

  The narrator reveal stays open (`NARRATOR_REVEAL_TBD`) unless decided.

**Done when:** a run plays through the fountain explosion, the finale fight and the aftermath weekend, ends with "End of Act 1", and `docs/ACT2.md` exists.

## M22: Polish and onboarding

- **Options menu:** volumes (music, sfx), key and controller rebinding, window size and fullscreen, text speed, screen shake on/off, the colorblind palette (M11) and difficulty display.
- Full controller support in every screen.
- Save and continue clarity: what day it is, last save time, the mode.
- **Achievements in the Narrator's Journal** (endings seen, all friendship scenes, deductions found). Narrator's Journal completion unlocks small extras: skip tutorial, new starting traits, alternate narrator lines.
- A performance pass and a final bug sweep from the user's playtest notes.

## M23: Release prep

- Export presets for Windows, Mac and Linux (include `*.json` in non-resource filters).
- Version numbering shown on the title screen. A changelog in `docs/CHANGELOG.md`.
- Crash and error logs saved to a file. An in-game "report a bug" that saves a zip of the logs and the save.
- An itch.io page draft and a build the user can send to friends for playtesting.

---

## Optional later

These came up but are lower priority:

- **Schoolamon:** the lunch card minigame from the dossiers. Fits after M17, with Jon as the first opponent.
- **Sam, Unmasked** and the Complete Axiomatic Mage: needs the user's design first.
- **The classroom-scheme minigame** (Ms. Nonsense, Sam and Baxter).
- **Weather and seasons:** the Earth Science teacher predicts them.
- **New Game+** from the Narrator's Journal.

## Open decisions for the user

1. ~~Art sizes~~ **Decided:** 32x32 tiles, 640x360 base resolution, 32x32 characters (32x48 allowed), 64x64 portraits.
2. **The narrator's identity** (before M21's teaser, or leave it open for Act 2).
3. **Intro details** (M15): is the player's parent a mom, a dad, a guardian, or chosen at character creation?
4. **Act 2 scope** (after M21): how many weeks, and which closed places open first.
5. **Default difficulty:** keep Permadeath as the default, or default to Narrator's Mercy for new players?

---

## Claude Code prompt for Phase 2

Paste this into Claude Code (VS Code, on the project-vector folder). To resume later, send: "Continue Phase 2 from docs/PROGRESS.md, following docs/ROADMAP.md."

```text
Phase 2 of Project Vector. Read CLAUDE.md, docs/ROADMAP.md (this plan; note the 32x32 tile and 640x360 decision at the top, which overrides DESIGN.md's 16x16 / 480x270), docs/DESIGN.md (Section 18 decisions are final), docs/characters.md, docs/TOWN.md and docs/PROGRESS.md before doing anything.

Work through docs/ROADMAP.md milestones M9 to M23 in order (including M12b), the same way as the alpha:
1. Write a short plan for the milestone, then build it.
2. Rules in src/core with tests; content and tuning in data/; scenes only display and forward input; all art and sound by asset id once M10 exists.
3. Make it playable and reachable from the game or the F1 debug menu.
4. Run the full test suite, the load check and the smoke tests; fix every error you introduced; meet the milestone's "Done when".
5. Update docs/PROGRESS.md (add a Phase 2 table) and CLAUDE.md "Current state", take screenshots into tools/screenshots/, commit "Mx: <summary>" and push to origin main. Confirm the push succeeded; if it fails, stop and tell me why.
6. Continue to the next milestone without asking.

Write the user-facing guides the roadmap asks for (ASSETS.md, ART_INVENTORY.md, MAP_GUIDE.md, CUTSCENE_GUIDE.md, PLAYTEST.md, ACT2.md) in plain language for someone new to Godot.

If a decision in "Open decisions for the user" blocks you, use the default noted here and log it in PROGRESS.md: art sizes are decided (32x32 tiles, 640x360, 32x32 characters, 64x64 portraits; no hardcoded sizes); the narrator stays NARRATOR_REVEAL_TBD; the parent is chosen at character creation (mom, dad or guardian); Act 2 is a design stub only; Permadeath stays the default with Narrator's Mercy offered at new run.

Stop only for something that would delete or overwrite my work, or a failed push. When you stop, report milestones done, test results, what to try in the game, decisions made and the next step.
```
