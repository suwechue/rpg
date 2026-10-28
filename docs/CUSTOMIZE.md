# Make it yours

This guide is for anyone who wants to swap the game's art, sound or text, or add new content, without touching code. You need a text editor and a folder. Godot is only needed to run the game.

Everything the player sees or hears has a name (an **id**). The full list, with sizes and what each is for, is in [ASSETS.md](ASSETS.md). Town map layouts are in `data/town/zones/` (see docs/TOWN.md; a MAP_GUIDE comes with M12's map editor).

**The one rule:** put your files in `assets/custom/`, named after the id. Your file wins over the built-in one. Delete it to go back.

---

## Replace art

1. Find the id in ASSETS.md, for example `portrait_kelly` (64x64).
2. Save your image as `assets/custom/portraits/portrait_kelly.png`. The folder is the id's type; `assets/custom/portrait_kelly.png` works too.
3. Press **F1 > Art > Reload custom art** in the game, or restart.

**Card art** falls back from specific to general, so one image per Vector covers every spell:

| Tried in order | Example |
| --- | --- |
| The card's own art | `card_art_card_fireball.png` |
| Its combo | `card_art_magma_ram.png` |
| Its two Vectors | `card_art_heat_force.png` |
| Its Vector and Form | `card_art_heat_bolt.png` |
| Its Vector | `card_art_heat.png` |
| Its kind, then the default | `card_art_spell.png`, `card_art_default.png` |

Drop card art in `assets/custom/cards/`. Only the ids in ASSETS.md need to exist; the specific names above are picked up when you add them.

**Effects (VFX)** work the same way. A sprite sheet is one row of frames. `vfx_heat_bolt` falls back to `vfx_heat`, then `vfx_form_bolt`, then `vfx_hit`; combos use `vfx_combo_<id>`, then `vfx_combo`. To change the frame count or speed of a general effect, edit its `frames` and `fps` in `data/assets/manifest.json`.

## Replace music, sounds, ambience and voices

- **Music:** drop `assets/custom/music/<id>.ogg`. Which track plays where is in `data/audio.json` under `music` (the title, the town by time of day, each zone, each week's Upside-Down, combat, elite, each boss, jingles, cutscene moods). Each has a volume, loop and crossfade.
  - Example: a new boss theme for the Hollow Mascot. Add `"boss_hollow_mascot": { "id": "music_mascot", "volumeDb": 0, "loop": true, "crossfade": 0.8 }`, list `music_mascot` in the manifest, then drop `assets/custom/music/music_mascot.ogg`.
- **Sound effects:** the game fires named events (`door_open`, `card_play_heat`, `level_up`). `data/audio_events.json` maps each event to one or more ids, picked at random, with a pitch and volume range.
  - Example: three footstep variations. Set `"step_grass": { "ids": ["sfx_step_grass", "sfx_step_grass_2", "sfx_step_grass_3"], "pitch": [0.9, 1.1] }`, then add the files.
- **Ambience:** looping background per place (`amb_town_day`, `amb_school_hall`, `amb_upside_down_week2`), mapped under `ambience` in `data/audio.json`.
- **Voice blips:** each character's `"voice": { "id": "voice_kelly", "pitch": 1.1 }` in `data/npcs/<id>.json`. One short sound plays per letter as their text types out.

Press **F1 > Art > Reload audio** to hear new files at once. A missing sound plays nothing and logs a warning naming the id.

## Fonts, colors and text

- **Fonts:** `font_ui`, `font_dialogue`, `font_title`, `font_damage_numbers`. Drop a `.ttf` in `assets/custom/fonts/`. Pixel fonts look best at their native size (`fontSize` and `titleSize` in `data/ui.json`, roles under `fonts`).
- **Colors:** UI colors and Vector colors are in `data/ui.json` (`colors`, `vectorColors`); screen size and tile size in `data/display.json`.
- **UI text:** every menu, button and prompt is in `data/strings.json` by key. Change the text, keep any `%s` and `%d`. This is also where a translation would go.

---

## Add content

All content is JSON in `data/`. The game checks it at start-up and prints problems naming the file and record (also in F1).

**A card** (`data/cards/*.json`):
```json
{ "id": "card_ember_jab", "name": "Ember Jab", "kind": "spell", "vectors": { "heat": 1.0 }, "form": "touch", "magnitude": "minor",
  "effects": [ { "op": "status_target", "status": "burning", "turns": 2 } ] }
```
Effect ops are listed in `src/core/combat/card_effects.gd` (`OPS`).

**A combo** (`data/combos.json`): two or three Vectors, a name, effects (same ops as cards), a hint for the Compendium and a narrator line.
```json
{ "id": "rust_lock", "name": "Rust Lock", "vectors": ["corrosion", "binding"], "description": "Roots and shreds armor.",
  "hint": "Something rotten, something that holds.", "effects": [ { "op": "root_area", "turns": 1 }, { "op": "shred", "defense": 2 } ],
  "vfx": "vfx_combo_rust_lock", "sound": "combo_cast", "art": "card_art_rust_lock", "narrator": "It holds. It also falls apart. Both, somehow." }
```
To use a Tier 3 Vector in the Compendium grid, add it to `axes` in the same file.

**An enemy** (`data/enemies/*.json`): copy a record, change its `id`, `name`, `stats`, `signature` (its Vector mix, which decides the weeks it fits) and `sprite`. The sprite id must be in the manifest.

**A character** (`data/npcs/<id>.json`): name, schedule, topics, `portrait`, `sprite` and `voice`. See docs/characters.md for the cast.

**A spark quiz question** (`data/intro/spark_quiz.json`):
```json
{ "text": "A dog follows you home. You...", "answers": [
  { "label": "Name it", "weights": { "binding": 2 } },
  { "label": "Race it", "weights": { "motion": 2 } } ] }
```
Sparks (name, trait, first card, reveal text) are in `data/sparks.json`; spark traits are in `data/traits.json` with `"spark": true`.

**A cutscene:** see [CUTSCENE_GUIDE.md](CUTSCENE_GUIDE.md).

**A building:** add a location in `data/town/locations.json` (see docs/TOWN.md): its door tile, hours, door line and what you can do inside.
