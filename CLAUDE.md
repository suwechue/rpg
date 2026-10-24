# Project Vector — notes for Claude Code

Read `docs/DESIGN.md` before starting any task. The Vector system reference is `docs/vector_system.md`.

## Current state

M0 (skeleton) and most of M1 (Vector core) are in place:
- `src/core/vector_ops.gd` — all 8 operations plus total/spread/complexity/dominant_axis. Cosine "Match" is named `similarity()` because `match` is a GDScript keyword.
- `src/core/rng_streams.gd`, `src/core/calendar_logic.gd` — seeded streams, day parts and AP.
- `src/autoload/` — EventBus, InputSetup (input map registered in code), DataDB, Rng, Narrator, Calendar, GameState, SaveSystem, SceneRouter.
- `src/scenes/main.tscn` — a placeholder town sandbox exercising the day-part/AP loop.
- `tests/run_tests.gd` — headless tests, including the three worked examples from the Vector doc.

Next: M2. Progress, decisions and stubs are tracked in `docs/PROGRESS.md`; the full alpha instructions are in `docs/PROMPT_alpha_run.md`. Final design decisions are in DESIGN.md Section 18. The cast is in `docs/characters.md` and the town plan in `docs/TOWN.md`; both are sources of truth.

## How this project is built

- Repo: https://github.com/suwechue/rpg.git (branch main). Commit and push after every milestone; never force-push.
- Combat is 2.5D (DESIGN.md Section 9): flat logic grid, projection only in the combat scene, unscaled pixel sprites.

- Engine: Godot 4.7, statically typed GDScript, tabs for indentation.
- Work one milestone at a time from DESIGN.md Section 17. Meet each milestone's "Done when" check, update docs/PROGRESS.md, commit and push, then continue to the next one (see docs/PROMPT_alpha_run.md) unless I ask you to stop.
- Display: 480x270 base resolution, `viewport` stretch, integer scaling, nearest filtering, 16x16 tiles.
- Godot executable (4.7.2): `C:\Users\itzju\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- Run tests from the project folder (PowerShell):
  `& "C:\Users\itzju\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s res://tests/run_tests.gd` (exit code 0 = pass).
- Check the project loads without script errors: same command with `--headless --path . --quit`.

## Rules

1. **Game rules live in `src/core/`** as plain classes that never touch nodes, scenes or autoloads, so they run headless in tests. Other scripts reference them with `preload` constants (for example `const VO := preload("res://src/core/vector_ops.gd")`).
2. **Content lives in `data/` as JSON.** Never hardcode classes, cards, enemies, events, topics or tuning numbers in scripts. `DataDB` loads every file; add validation for new tables in `DataDB._validate()`.
3. **All randomness goes through `Rng` streams** (`Rng.stream("combat")`, etc.); core functions take a `RandomNumberGenerator` argument. Never call `randi()`/`randf()` or use an unseeded generator.
4. **Vectors are `Dictionary` (axis -> number), stored raw.** Normalize only when reading. Missing axis = 0. Break ties by the axis order in `data/spaces.json`.
5. **`GameState` is the single source of truth** for a run. Saving serializes it; writes are atomic. One save slot per run (roguelike).
6. **Scenes only display state and forward input.** Use `EventBus` signals instead of reaching across scenes.
7. **Tests:** add a `test_` method in `tests/run_tests.gd` (or a new runner) for every function in `src/core/`. Run the suite before finishing a task; don't finish with failures.
8. **Placeholder art is fine.** Use the packs in `assets/packs/` (see Art below). Never edit pack files; copy anything you modify into `assets/sprites`, `assets/tiles` or `assets/ui`. Never block on art.
9. When the design doc is ambiguous, choose the simplest option that fits it, note the decision in your summary, and add it to DESIGN.md Section 18 if it matters.

## Art (assets/packs, all CC0; see CREDITS.md)

All tiles are 16x16 on a 16x16 grid unless noted. Kenney "Tiny" packs share one style and size: use `Tilemap/tilemap_packed.png` (12x11 tiles, no spacing) for TileSets, or `Tiles/tile_NNNN.png` singles.

| Use for | Pack | Key paths |
| --- | --- | --- |
| Player, students, townsfolk (4-direction walk sprites) | `ninja_adventure` | `Actor/Character/<Name>/`, `Actor/CharacterAnimated/` |
| Upside-Down monsters and bosses | `ninja_adventure`, `tiny_creatures` | `Actor/Monster/`, `Actor/Boss/`; `tiny_creatures/Tiles/` |
| Town (modern: roads, cars, shops) | `kenney_tiny_city` | `Tilemap/tilemap_packed.png` |
| Town (houses, trees, fences, the deli/forge look) | `kenney_tiny_town`, `ninja_adventure` | `Tilemap/tilemap_packed.png`; `Backgrounds/Tilesets/TilesetHouse.png`, `TilesetNature.png`, `TilesetFloor.png`, `Interior/` |
| School, hospital and shop interiors | `ninja_adventure` | `Backgrounds/Tilesets/Interior/` |
| Upside-Down floors (twisted town) | `kenney_tiny_dungeon`, `dungeontileset_ii` | `Tilemap/tilemap_packed.png`; `atlas_floor-16x16.png`, `atlas_walls_low-16x16.png` (3x3 minimal autotile; `atlas_walls_high-16x32.png` uses a Y offset of 8, see its README) |
| Grid combat units, markers, highlights | `kenney_tiny_battle` | `Tilemap/tilemap_packed.png` |
| Card frames, panels, buttons, sliders | `kenney_ui_pixel_adventure` | `Tiles/`, `Tilesheets/` |
| Key and controller prompts ("[E]") | `kenney_input_prompts_pixel` | `Tiles/`, `Tilemap/` |
| Dialogue boxes, emotes, skill icons, items, FX | `ninja_adventure` | `Ui/Dialog/`, `Ui/Emote/`, `Ui/Skill Icon/`, `Items/`, `FX/` |
| Music and sound effects | `ninja_adventure` | `Audio/` |
| Pixel font for the HUD and dialogue | `ninja_adventure` | `Ui/Font/NormalFont.ttf` (use at integer sizes) |

Pick one look per area so styles don't clash: Kenney Tiny packs for tiles, Ninja Adventure for characters, monsters, UI and audio, unless a milestone says otherwise.
