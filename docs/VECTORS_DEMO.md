# Vectors and Demo (separate milestone: VD)

This is a **separate milestone, VD (Vectors and Demo)**, outside `docs/ROADMAP.md`. Don't renumber or edit the roadmap for it. Do it **after CU (Combat Update, `docs/COMBAT_REWORK.md`) and AR (Arena, `docs/ARENA.md`)**, then return to the roadmap where you left off. Combos (Part 2) must work in the arena, and the demo build (Part 5) includes the Endless Arena from the title screen. Track it as its own row ("VD Vectors and Demo") in `docs/PROGRESS.md` and commit it as "VD: ...". If a part depends on a roadmap milestone that isn't built yet (the intro from M15, cutscenes from M14), build a simple version now and note in PROGRESS.md what that milestone must upgrade.

**Goal:** make the Vector system the star of the game, and get a polished, shareable demo (the first hour, ending after the week 1 boss) that the user can send to people with feedback built in. **Everything added here must be modular.** The user will replace the art, music and sounds with their own, so nothing new may bypass the asset id system from M10.

---

## Part 1: Modular everything (do this first, and keep to it for every other part)

M10 already gives every sprite, portrait, tile, UI piece, icon, card art, music track and sound an id in `data/assets/manifest.json`, with `assets/custom/<type>/<id>.<ext>` overriding the pack file and `docs/ASSETS.md` generated from the manifest. Extend that so **every** piece of content the player sees or hears is swappable by name.

**Art**
- Fill the **VFX** group (currently empty): one id per Vector effect and per Form (`vfx_heat_burst`, `vfx_force_push`, `vfx_cold_freeze`...), plus hit sparks, heal glows, status icons, telegraph markers and combo effects (Part 2). Specs: frame size, frame count, frame rate, anchor.
- **Card art fallback chain:** `card_art_<combo_or_card_id>`, then `card_art_<vector1>_<vector2>`, then `card_art_<vector>_<form>`, then `card_art_<vector>`, then `card_art_default`. The user can draw one image per Vector and get full coverage, then add specific art over time.
- **Fonts** by id (`font_ui`, `font_dialogue`, `font_title`, `font_damage_numbers`) with size rules, swappable like any asset.
- **Palettes and colors** (Vector colors, UI colors, day-part lighting) stay in data files (`data/ui.json`, `data/display.json`), never in scripts.

**Audio**
- **Music map:** `data/audio.json` maps situations to music ids:
  - the title screen
  - the town by day part (morning, after school, night)
  - each zone, the school and the Upside-Down by week
  - combat, elite combat and each boss
  - victory and defeat jingles
  - cutscene moods (tense, sad, funny)

  Each track has a volume, loop and crossfade settings. Replacing a track = drop `assets/custom/music/<id>.ogg`.
- **Sound event map:** `data/audio_events.json` maps game events to sound ids:
  - `card_play_heat`, `card_hover`, `step_grass`, `door_open`, `ap_spent`, `level_up`, `telegraph_warning`, `enemy_windup`
  - and so on, for every event.

  Code only ever fires events, never sound files. Each event can list several ids (picked at random) and a pitch and volume range, so the user can add variations like `sfx_step_grass_2`.
- **Ambience:** looping background sound per zone and time (`amb_town_day`, `amb_school_hall`, `amb_upside_down_week2`).
- **Dialogue voice blips:** each character gets a short "voice" sound played per letter as text types out (`voice_kelly`, `voice_gary`, `voice_narrator`; fallback `voice_default`), with pitch per character in their NPC data. The user can record or make their own.
- **Hot reload for audio** in the F1 debug menu, like art. Missing audio plays nothing and logs a warning naming the id (never a crash).

**Text and content**
- All player-facing UI text (menus, buttons, tutorial prompts, HUD labels) moves to `data/strings.json` by key. Dialogue and story already live in data; keep it that way. This also makes translation possible later.
- Combos, cards, the spark quiz, enemies, classes and characters are all data (Parts 2 to 4).

**Guarantees**
- **An audit test** fails if:
  - any script or scene references `res://assets/packs/` directly, outside the manifest;
  - any sound or music is played by path instead of by id or event;
  - any player-facing string is hardcoded in a script.
- `docs/ASSETS.md` regenerates with the new groups (VFX, fonts, ambience, voice blips, combo card art) and keeps its "replaced so far" counts.
- **`docs/CUSTOMIZE.md`** ("Make it yours"): one plain-language guide for someone new to Godot covering how to:
  - replace art, music, sounds, ambience, voice blips, fonts, colors and UI text;
  - add a new card, combo, enemy, character, spark quiz question or building.

  Use a worked example for each. Link to ASSETS.md and MAP_GUIDE.md.

---

## Part 2: Multi-Vector combinations

Hybrid cards already exist (two Vectors, +1 MP) but only blend damage. Make every pair its own spell.

**Pair effects:** every pair of the six Tier 1 and 2 Vectors (15 pairs) has a named combo with a unique effect, defined in `data/combos.json` (name, Vectors, effect script id, description, VFX id, sound event, card art id). Starting set (names and numbers are tunable):

| Pair | Combo | Effect |
| --- | --- | --- |
| Heat + Cold | Thermal Shock | Ignores half of resistances; shatters frozen or slowed targets for bonus damage; leaves a steam cloud that blocks sight |
| Heat + Force | Magma Ram | Push that leaves a burning trail on every tile the target slides across |
| Heat + Motion | Comet Dash | Caster dashes in a line, hitting units passed and burning those tiles |
| Heat + Binding | Branding Chains | Root; the target burns each turn while rooted |
| Heat + Light | Solar Flare | Blinds everything in the area and sets it burning |
| Cold + Force | Glacier Slam | Push; if the target hits a wall or unit, it's frozen in place (rooted) |
| Cold + Motion | Glacier Slide | Lays an ice path and slides the target to the end of it |
| Cold + Binding | Frost Shackles | Root for 2 turns, then slowed |
| Cold + Light | Prism Frost | Hits the target, then refracts to the 2 nearest enemies, slowing all |
| Force + Motion | Slingshot | Pulls the target through you and launches it out the other side; collisions deal double |
| Force + Binding | Tether Slam | Chains two enemies together and pulls them into each other |
| Force + Light | Radiant Shockwave | Knockback ring around the target; allies inside it are healed |
| Motion + Binding | Anchor Swap | Swap places with an ally; enemies next to your arrival tile are rooted |
| Motion + Light | Flash Step | Teleport yourself or an ally; enemies next to the destination are blinded |
| Binding + Light | Halo Chains | Root; allies next to the target heal each turn it stays rooted |

- The pair effect replaces the plain blend on hybrid cards and improvised casts. Effects must work with CU's previews, telegraphs and forced-movement rules. The hover preview shows the combo's full result.
- **Three-Vector combos (Tier 3 knowledge):** build the framework (3 Vectors, +2 MP, a stronger effect) with 3 example combos in data. More can be added later.
- **Party combos** at Close Bond use the pair effect of the two members' main Vectors, cast together (both spend their action).
- **Tier 3 Vectors** (Transmutation, Vitality, Corrosion) can join pairs later; leave room in the data format.

**Discovery and the Vector Compendium**
- A combo is **discovered** the first time the player crafts, improvises or party-casts it. Discovery triggers a short reveal: the combo name, its effect, and a narrator line.
- **Compendium screen** (from the pause menu and the workbench):
  - a 6x6 grid of Vector pairs, with discovered combos showing their name, art and effect;
  - undiscovered ones show "???" with a vague hint ("Something hot, something heavy");
  - counts of discovered combos.
- Discoveries persist in the run, and the **Narrator's Journal** records them across runs (a completion goal).

---

## Part 3: Your spark (choosing a Vector alignment)

At the start of a run, the player discovers their **spark**: their strongest Vector.

- **The spark quiz:** during the intro (moving night, M15; or a standalone screen in character creation if M15 isn't built yet), the narrator asks 5 or 6 odd personality questions. Each answer adds weights to Vectors. Example:

  > "The moving truck is on fire. You..."
  > - grab the box marked FRAGILE (Binding)
  > - kick the door open (Force)
  > - film it (Light)
  > - ...

- **The result:**
  - Shown as a short reveal with the spark's name and the narrator's comment.
  - Sets the player's starting **affinity table** (a Blend of the class table and the spark, using Vector operations).
  - Grants a known Vector.
  - Gives a **first spell card** of that Vector.
  - Gives a small **spark trait** (for example Heat: "Runs warm", +1 damage on Heat cards; Light: "Bright idea", +1 PER in dialogue).
- **Class stays separate:** a Cold-spark Fighter or a Heat-spark Bard are both valid, which makes replays different.
- **Choose directly:** after the first run (unlocked in the Narrator's Journal), the player can skip the quiz and pick a spark.
- **Data:** questions, answers, weights, spark names, traits, starting cards and reveal text live in `data/intro/spark_quiz.json` and `data/sparks.json`. Spark icons and reveal art go through asset ids (`icon_spark_heat`, `art_spark_reveal_heat`).

---

## Part 4: Spell crafting as a showcase

Crafting is the game's most unique system; make it feel great.

- **Visual card builder** at the workbench:
  - Pick Vectors on a Vector wheel, choose a Form and choose a Magnitude.
  - A live preview card updates as you go, with its name (combo name if it's a pair), cost, art (fallback chain from Part 1) and effect text.
  - A mini grid shows its footprint and effect.
  - Undiscovered combos show "???" until crafted.
- **Minigame juice:** sound, particles and screen feedback in the 4 crafting minigames. A clear performance score at the end.
- **Card reveal:** the finished card flips in with a sound, glow in its Vector color, and Property names. A first-time combo triggers the discovery reveal (Part 2).
- **Deck view:** cards sorted by Vector and cost, with combo badges.

---

## Part 5: The demo build

- **Demo mode:** a flag (`data/demo.json` and an export preset "Demo") that:
  - ends the run after the week 1 boss (The Hollow Mascot);
  - shows a "Thanks for playing" screen with what's coming (Act 1, combos discovered, characters met);
  - then shows the feedback survey (Part 6).

  The full game is unaffected.
- **A polished first hour (checklist in `docs/DEMO_CHECKLIST.md`):**
  - Title screen with a logo slot (`art_logo`, replaceable) and a short animated background.
  - The narrator's hook within the first 5 minutes.
  - Intro, spark quiz, tutorial day, first night with Kelly, and the week 1 boss.
  - At least one friendship scene available in week 1.
  - No dead ends.
  - Every screen reachable by keyboard and controller.
  - Options (volume, controls, text speed, combat speed) available from the title screen.
- **Juice pass for the demo path:**
  - Hit effects, screen shake, damage numbers, card hover and play animations.
  - UI sounds on every button.
  - Music transitions.
  - Transition fades between scenes.
  - Footsteps.
- **Stability:**
  - Zero errors in the log over a full demo playthrough (add a smoke test that plays the demo end to end with autoplay).
  - Save and continue work at every day part.
- **Sharing kit (tools):**
  - `tools/capture_shots.gd` takes a set of good screenshots from scripted moments (town at sunset, a telegraphed boss attack, a combo spell, the spark reveal, Kelly's dialogue) into `tools/press_kit/`.
  - Document how to record GIFs and video with Godot's Movie Maker mode (`--write-movie`) using the same scripted moments.
  - `docs/PRESS_KIT.md` gets a one-paragraph pitch, feature bullets and the screenshot list.
- **Export:** Windows build of the demo, zipped, with a short README, ready for an itch.io page (draft the page text in `docs/PRESS_KIT.md`).

---

## Part 6: Feedback tools

- **Send feedback (F8 or a pause menu button):** the player types a note. The game saves the note, a screenshot, the gameplay log, the current save and the build version into a zip in `user://feedback/`, then shows the folder so they can send it to the user.
- **End-of-demo survey:** 5 to 7 quick questions (fun 1 to 5, the most confusing moment, favorite character, was combat clear, would you play more, anything else), saved to the same feedback folder. Questions live in `data/demo.json`.
- **Gameplay log summary** added to the zip: AP spent by action type, fights won and lost, turns per fight, cards used, combos discovered, time per day, where the player quit.
- **`docs/PLAYTEST.md`** gets a section on how to run a playtest with friends and read the feedback zips.

---

## Tests and done when

**Tests:**
- Core tests for every pair effect (landing positions, statuses, collisions, previews), discovery, three-Vector framework rules, spark weights and trait application, the card art fallback chain, the sound event fallback, and strings lookup.
- The modularity audit test (Part 1).
- The demo smoke test (Part 5).

**Done when:**
- All 15 pair combos work in combat with previews and VFX ids, and appear in the Compendium when discovered.
- The spark quiz sets a spark, affinity, first card and trait at the start of a run.
- The card builder shows live previews and the reveal.
- The demo build ends after the Hollow Mascot with the thanks screen and survey.
- F8 produces a feedback zip.
- The audit test passes.
- `docs/CUSTOMIZE.md` explains how to replace any art, music, sound, voice blip, font or text, and how to add a card, combo and enemy, each with a worked example.
