# Demo checklist

The demo (VD Part 5): the intro through the week 1 boss, the Endless Arena from the title, a thanks screen, a survey and a Windows build. Started from `docs/PATCH_2.md` Part 4 (Oct 28); keep it current as items close.

| Area | Status | Notes |
| --- | --- | --- |
| Town life sim (AP day parts, classes, schedule, dialogue, Charisma gates, misheard lines, Bond, shops) | Have | Interiors still use drawn rectangles for furniture |
| Dungeon floors, Friday boss, Kelly tutorial floor | Have | Floors use generic rooms with a theme tint |
| Combat (2 Actions + 1 Quick, telegraphs, cover, statuses, Forge, class pools) | Have | Strike and Guard Quick bug fixed (P2 1.1); Binding tethers and hidden units are stubs |
| Endless Arena (waves, hazards, checkpoints, mutators, card and perk picks, score) | Have | Owner choice and effects strip done (P2 Parts 1 and 2); campfire later (AC) |
| Point buy, Party panel, pause menu, options | Have | Check that options open from the title screen (VD Part 5) |
| Art, audio and UI by asset id | Mostly | VD Part 1: audio situation map, voice blips, `docs/CUSTOMIZE.md`, audit test |
| Advanced Vectors and Techniques | Have | PT Part 8: 14 Techniques active, 10 planned (potions, acting constructs) |
| Multi-Vector combos and the Compendium | Missing | VD Part 2 |
| Spark quiz | Missing | VD Part 3 (standalone screen until M15) |
| Visual card builder and crafting juice | Missing | VD Part 4 |
| Cutscene system | Have | P2 Part 3 (M14); docs/CUTSCENE_GUIDE.md |
| Intro and tutorial day | Have | P2 Part 3 (M15): moving day, name, intro night, a beat per Monday day part; illustrations are placeholders until art lands |
| A friendship scene in week 1 | Missing | One scripted scene with the cutscene system (Dex or Theo at lunch); the full system is M18 |
| Title logo slot and animated title background | Missing | `art_logo` asset id with a placeholder (VD Part 5) |
| Demo mode, thanks screen, export preset | Missing | `data/demo.json`, `export_presets.cfg` "Demo" (VD Part 5) |
| Feedback (F8, survey, log summary) | Missing | VD Part 6 |
| Keyboard and controller navigation on every screen | Partial | The focus fix (P2 1.2) is done (nav vs mouse mode); audit each screen |
| Juice pass (hit effects, shake, UI sounds, fades, footsteps) | Partial | VD Part 5 |
| End-to-end demo smoke test, zero errors in the log | Missing | VD Part 5 |

**After the demo** (ROADMAP and AC, not demo blockers): M12, M12b, M13, M16 to M23, and the arena campfire (AC).
