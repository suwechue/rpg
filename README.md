# Project Vector

A top-down pixel-art RPG about a new kid in a small town. By day you live a high-school week: go to class (or skip it), make friends, work jobs, chase a mystery. By night you fight through the Upside-Down, a twisted mirror of the town, with spell cards you build from the Vector magic system.

Built with Godot 4.7 and statically typed GDScript. Game content lives in JSON under `data/`.

## Where the project stands

**Act 1 is playable from start to finish: five in-game weeks, ending at the fountain and the Mirror Town.** It is a work in progress and needs more human playtesting, especially for balance.

| Area | State |
| --- | --- |
| Story mode (Act 1) | Playable to the end. Act 2 is only a design stub (`docs/ACT2.md`) |
| Endless Arena | Playable from the title screen, with bosses, a walkable campfire camp, a merchant and a blacksmith |
| Combat | Done: 2 Actions + 1 Quick a turn, telegraphed enemy attacks, 220 cards, combos, gear |
| Town life | Done: 45 named characters, a generated crowd, skipping class, favors, timed events, the phone, the mystery board |
| Art and audio | Placeholder CC0 packs, all swappable by asset id (`docs/CUSTOMIZE.md`) |
| Windows build | Export presets are ready; no build has been made yet (needs Godot's export templates) |

What's next: outside playtests and balance from their results, plus the small leftovers listed in `docs/PROGRESS.md`.

## Play it

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. In the Project Manager, choose **Import**, pick `project.godot` in this folder, then **Import & Edit**.
3. Press **F5**. The first import takes a little while.

### A new run

Type a name, click a class (Mage, Fighter, Rogue, Healer or Bard), choose how hard you want it, then **Start the run**.

| Difficulty | What it means |
| --- | --- |
| Story (easy) | Gentle fights. In the Upside-Down, the fight is lost only if your whole party falls |
| Normal | The intended game. Once a fight in the Upside-Down, a Last Stand saves you from a killing blow |
| Hard | Stronger enemies and no safety net |

Separately, the run mode sets what happens when you die: **Permadeath** ends the run, **Narrator's Mercy** rewinds the day, and **Story** is the easy path. **Clear data** on the title screen wipes unlocks, settings or saves.

### A week

- **Monday:** pick your classes.
- **School days:** attend class, or skip it for free time in a town that's awake, at the risk of getting caught.
- **Before school, lunch, after school:** spend AP on talking, shopping, training and jobs.
- **Weekday evenings:** the Upside-Down. Friday is the boss. You pick a new card on the way out.
- **Weekends:** free time and town events.

Some cards only come from timed events around town, often during class. The morning paper and the **What can I do?** panel (G) tell you what's on.

### Controls

| Where | Keys |
| --- | --- |
| Town and dungeon | WASD or arrows walk, E or Enter interact, Space ends the day part, G What can I do?, P pause |
| Menus | Mouse, or arrows + Enter; Esc closes |
| Combat | Click a tile to move; click a card, then a target |
| Combat keys | 1-7 cards, S Strike, H Hold, Y Together, F Flee, Space end turn, hold T threat view, hold Shift fast-forward, P pause |
| Anywhere | F8 save a feedback zip, F1 debug menu |

## Run the tests

Run from this folder, using the path to your Godot console executable (`run_tests.bat` runs the core tests on Windows).

```
godot --headless --path . -s res://tests/run_tests.gd       # core rules, under a minute or two
godot --headless --path . -s res://tests/smoke_ui.gd        # every screen: buttons work, nothing off screen
godot --headless --path . -s res://tests/smoke_scenes.gd    # real scenes, a played week (slow)
godot --headless --path . -s res://tests/smoke_arena.gd     # autoplays the arena (slow)
godot --headless --path . -s res://tests/smoke_full_run.gd  # a whole 5-week run (slowest)
```

Exit code 0 means everything passed.

Balance tools run the same way:

| Tool | Measures |
| --- | --- |
| `tools/sim_nights.gd -- --campaign --difficulty=normal` | Whole 5-week campaigns played by the AI |
| `tools/sim_arena.gd` | How far the AI gets in the arena |
| `tools/sim_balance.gd -- --week=3 --level=5 --gear=2` | Actions to kill, and how hard enemies hit |
| `tools/sim_days.gd` | Whether a player's AP covers what they want to do in a week |

## How the code is laid out

| Folder | What's there |
| --- | --- |
| `src/core/` | The game's rules, as plain classes with no scenes, so they run headless in tests |
| `src/scenes/` | Screens and scenes. They display state and forward input |
| `src/autoload/` | Global services: game state, saving, the day flow, cutscenes, UI theme, art lookup |
| `src/world/` | Town zone scenes and the markers used to build them |
| `data/` | All content and tuning numbers, as JSON: cards, enemies, people, events, difficulty |
| `tests/`, `tools/` | Test runners, balance sims and world-building tools |
| `assets/packs/` | Third-party art and audio, unmodified. Licenses are in `CREDITS.md` |

Most changes to content or balance need no code: edit the JSON in `data/`.

## Which doc do I read?

**Start here**

| Doc | For |
| --- | --- |
| `docs/MECHANICS.md` | Every rule and number as the game works now. The best description of the game |
| `docs/COMBAT_LAB.md` | The Combat Lab plan: rules as switches, hand-made fights, and picking what's fun |
| `docs/LAB_TUNER.md` | The Lab Tuner plan: AI sweeps, fun proxies, agent playtesters and a shortlist for the user |
| `docs/LAB_TUNING.md` | The Lab Tuner's results: baseline, lever effects, pairs, the shortlist, the agent playtest |
| `docs/PROGRESS.md` | What's done, what was decided, what's left, balance results |
| `docs/CHANGELOG.md` | What changed in each version |
| `docs/PLAYTEST.md` | How to playtest and report how it felt; no Godot knowledge needed |

**Design and world**

| Doc | For |
| --- | --- |
| `docs/DESIGN.md` | The full game design (section 18 has the final decisions) |
| `docs/vector_system.md` | The Vector magic system |
| `docs/characters.md` | The cast |
| `docs/TOWN.md` | The town plan |
| `docs/ACT2.md` | What comes after Act 1 |

**How to change things**

| Doc | For |
| --- | --- |
| `docs/CUSTOMIZE.md` | Swapping in your own art and sound |
| `docs/ASSETS.md` | Every asset id (generated by `tools/gen_assets_doc.gd`) |
| `docs/MAP_GUIDE.md` | Editing town maps |
| `docs/CUTSCENE_GUIDE.md` | Writing cutscenes |
| `docs/ART_INVENTORY.md` | Which art is in use and which is free |
| `docs/PRESS_KIT.md`, `docs/DEMO_CHECKLIST.md` | Preparing a release |

**History: the plans each milestone was built from.** These explain why things are the way they are, but they may not match the game today. If one disagrees with `docs/MECHANICS.md`, the game and MECHANICS win.

`docs/ROADMAP.md`, `docs/PROMPT_alpha_run.md`, `docs/PROMPT_phase2.md`, `docs/COMBAT_REWORK.md`, `docs/COMBAT_TUNING.md`, `docs/ARENA.md`, `docs/ARENA_CAMPFIRE.md`, `docs/PATCH_1.md`, `docs/PATCH_2.md`, `docs/VECTORS_DEMO.md`, `docs/TOWN_LIFE.md`, `docs/character_brief.md`

`CLAUDE.md` holds working notes for Claude Code, which helps build this project.

## Credits

All third-party art and audio is CC0. Packs and links are in `CREDITS.md`. Your own art goes in `assets/sprites`, `assets/tiles`, `assets/ui`, `assets/audio` and `assets/fonts`.
