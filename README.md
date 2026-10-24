# Project Vector

Top-down pixel-art school-life RPG with Vector spell cards, tactical grid fights and a weekly Upside-Down dungeon. Design: `docs/DESIGN.md`. Notes for Claude Code: `CLAUDE.md`.

## Open it in Godot

1. Install **Godot 4.7** (4.7.2 is what the project is built with) (standard build, not .NET) from https://godotengine.org/download
2. Godot Project Manager → **Import** → pick `project.godot` in this folder → **Import & Edit**.
3. Press **F5** (Run Project).

The first import takes a few seconds while Godot builds its `.godot/` cache.

## Playing the alpha

Title screen: **New run** (pick a class, optional seed), **Continue** (one autosave per run), **Narrator's Journal**.

| Where | Keys |
| --- | --- |
| Town and dungeon | WASD / arrows walk (free), E / Enter interact (doors, people, places), Space ends the day part |
| Menus | Mouse, or arrows + Enter; Esc closes |
| Combat | Click a cell to move, click a card then a target; 1-7 pick cards, S Strike, G Guard, V Vector Wheel, F Flee, Space end turn, right click / Esc cancel; arrows + E move a cursor |
| Anywhere | F1 debug menu (time travel, stats, fights, town teleports, Bonds, recruits) |

A week: pick classes on Monday, attend or skip periods, spend AP before school, at lunch and after school (talk, shop, train, work shifts), go into the Upside-Down every weekday evening (Friday is the boss), craft cards at night, then a free weekend. Dying ends the run. Five weeks end at the `NARRATOR_REVEAL_TBD` finale.

## Run the tests

From this folder (use the path to your Godot executable):

```
godot --headless --path . -s res://tests/run_tests.gd      # core rules (pure)
godot --headless --path . -s res://tests/smoke_scenes.gd   # real scenes, about 5 minutes
godot --headless --path . -s res://tests/smoke_full_run.gd # a whole 5-week run, a few minutes
```

Balance tools: `tools/sim_nights.gd` and `tools/sim_run.gd` (same command shape).

On Windows, for example: `"C:\Godot\Godot_v4.x-stable_win64_console.exe" --headless --path . -s res://tests/run_tests.gd`

## Prototype art

Third-party packs are unpacked, unmodified, in `assets/packs/` (one folder per pack). Licenses and links: `CREDITS.md`. Your own art goes in `assets/sprites`, `assets/tiles`, `assets/ui`, `assets/audio` and `assets/fonts`.

## Exporting later

Add `*.json` to the export preset's "Filters to export non-resource files" so `data/` ships with the game.
