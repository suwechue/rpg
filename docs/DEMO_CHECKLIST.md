# Demo checklist

The demo (VD Part 5): the intro through the week 1 boss, the Endless Arena from the title, a thanks screen, a survey and a Windows build. Started from `docs/PATCH_2.md` Part 4 (Oct 28); keep it current as items close.

| Area | Status | Notes |
| --- | --- | --- |
| Town life sim (AP day parts, classes, schedule, dialogue, Charisma gates, misheard lines, Bond, shops) | Have | Interiors still use drawn rectangles for furniture |
| Dungeon floors, Friday boss, Kelly tutorial floor | Have | Floors use generic rooms with a theme tint |
| Combat (2 Actions + 1 Quick, telegraphs, cover, statuses, Forge, class pools) | Have | Strike and Guard Quick bug fixed (P2 1.1); Binding tethers and hidden units are stubs |
| Endless Arena (waves, hazards, checkpoints, mutators, card and perk picks, score) | Have | Owner choice and effects strip done (P2 Parts 1 and 2); campfire later (AC) |
| Point buy, Party panel, pause menu, options | Have | Options open from the title screen (VD Part 5) |
| Art, audio and UI by asset id | Have | VD Part 1: VFX group, art chains, audio situations, ambience, events, audit test, `docs/CUSTOMIZE.md` |
| Advanced Vectors and Techniques | Have | PT Part 8: 14 Techniques active, 10 planned (potions, acting constructs) |
| Multi-Vector combos and the Compendium | Have | VD Part 2: 15 pairs, 3 three-Vector combos, discovery, Compendium. party combos at Close Bond (Together, TL Part 5) |
| Spark quiz | Have | VD Part 3: during the intro, before the first night; direct pick on later runs |
| Visual card builder and crafting juice | Have | VD Part 4: live preview card, footprint, combo ???, grade, card flip; minigame particles are not built |
| Cutscene system | Have | P2 Part 3 (M14); docs/CUTSCENE_GUIDE.md |
| Intro and tutorial day | Have | P2 Part 3 (M15): moving day, name, intro night, a beat per Monday day part; illustrations are placeholders until art lands |
| A friendship scene in week 1 | Have | TL Part 5: Wednesday lunch with Dex and Theo (data/cutscenes/town_life.json, w1_lunch_friends); sit with one or push the tables together |
| Title logo slot and animated title background | Have | `art_logo` (drop assets/custom/ui/art_logo.png; text title until then); the skyline background animates; version label |
| Demo mode, thanks screen, export preset | Have | `data/demo.json` (or the "demo" feature tag), thanks screen, `export_presets.cfg` "Demo". The Windows build itself needs export templates installed (docs/PLAYTEST.md) |
| Feedback (F8, survey, log summary) | Have | F8 and Options > Send feedback; survey after the thanks screen; zips in user://feedback/ (docs/PLAYTEST.md) |
| Keyboard and controller navigation on every screen | Have | tests/smoke_ui.gd opens every screen and checks focus, handlers and on-screen buttons |
| Juice pass (hit effects, shake, UI sounds, fades, footsteps) | Have | VFX on casts and combos, shake, damage numbers, card hover and play sounds, UI clicks, music crossfades, footsteps, scene and day-part fades (TL Part 7) |
| End-to-end demo smoke test, zero errors in the log | Have | smoke_scenes plays week 1 through the Hollow Mascot; smoke_demo_end checks the thanks screen, survey zip and title |

**After the demo** (ROADMAP and AC, not demo blockers): M12, M12b, M13, M16 to M23, and the arena campfire (AC).
