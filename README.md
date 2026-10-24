# Project Vector

Top-down pixel-art school-life RPG with Vector spell cards, tactical grid fights and a weekly Upside-Down dungeon. Design: `docs/DESIGN.md`. Notes for Claude Code: `CLAUDE.md`.

## Open it in Godot

1. Install **Godot 4.3 or newer** (standard build, not .NET) from https://godotengine.org/download
2. Godot Project Manager → **Import** → pick `project.godot` in this folder → **Import & Edit**.
3. Press **F5** (Run Project).

The first import takes a few seconds while Godot builds its `.godot/` cache.

## What runs right now (milestone M0 sandbox)

A placeholder town on a 16px grid that runs the day-part and Action Point loop:

| Key | Does |
| --- | --- |
| WASD / arrows | Walk (free) |
| E / Enter | Interact with a place (costs AP), attend class, enter the Upside-Down |
| Space | End the day part early / skip class |
| F5 / F9 | Save / load the run |

Places open and close by day part (see `data/locations.json`). Classes follow `defaultSchedule` in `data/school_classes.json`. The Output panel prints the Vector system worked examples as a smoke test.

## Run the tests

From this folder (use the path to your Godot executable):

```
godot --headless --path . -s res://tests/run_tests.gd
```

On Windows, for example: `"C:\Godot\Godot_v4.x-stable_win64_console.exe" --headless --path . -s res://tests/run_tests.gd`

## Prototype art

Third-party packs are unpacked, unmodified, in `assets/packs/` (one folder per pack). Licenses and links: `CREDITS.md`. Your own art goes in `assets/sprites`, `assets/tiles`, `assets/ui`, `assets/audio` and `assets/fonts`.

## Exporting later

Add `*.json` to the export preset's "Filters to export non-resource files" so `data/` ships with the game.
