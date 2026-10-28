# Project Vector — notes for Claude Code

**Phase 2 is in progress:** follow `docs/ROADMAP.md` using `docs/PROMPT_phase2.md`, starting at M9. Track progress in a Phase 2 table in `docs/PROGRESS.md`.

Read `docs/DESIGN.md` before starting any task. The Vector system reference is `docs/vector_system.md`.

## Current state

The alpha (M0 to M8) is done:
- `src/core/vector_ops.gd` — all 8 operations plus total/spread/complexity/dominant_axis. Cosine "Match" is named `similarity()` because `match` is a GDScript keyword.
- `src/core/data_tables.gd` — pure JSON loader shared by `DataDB` and the tests; core functions take the whole tables Dictionary as `db`.
- `src/core/rng_streams.gd`, `src/core/calendar_logic.gd` — seeded streams, day parts and AP.
- `src/core/character.gd`, `card.gd`, `deck.gd`, `progression/leveling.gd` — characters as Dictionaries, derived stats, card costs and Tier caps, deck with Fatigue, leveling with pity.
- `src/autoload/` — EventBus, InputSetup, DataDB, Rng, Narrator, Calendar, GameState, SaveSystem, SceneRouter, UiTheme (project theme + UI helpers), DebugMenu (F1, plus the `--shot` screenshot hook).
- `tests/run_tests.gd` runs its own tests, then every suite in `tests/suites/` (each extends `tests/suite.gd`). `tests/smoke_scenes.gd` drives real scenes with autoloads; `tests/smoke_full_run.gd` plays a whole 5-week run (slow, run on its own).

Gotchas: JSON numbers load as floats, so `[3.0].has(3)` is false; compare with `int()`. New `class_name`s are not visible until the editor rescans, so reference scripts with `preload` constants. The UI font's native size is 9px (`UiTheme.FONT_SIZE`). `:=` on a Variant (dict.get, array[i]) is a parse error in this project; cast or type it. Python on Windows writes CRLF unless you pass newline=''; keep files LF.

Phase 2: M9 (stabilize, gameplay log), M10 (art pipeline, 640x360, 32x32) and M11 (UI skin) are done. CU (combat update), AR (arena and combat depth) and CT (combat tuning, with PT Parts 1 and 2 adopted: 2 Actions + 1 Quick, Cantrip, Hold, undo stack, hand of 3, just-in-time telegraphs, directional cover, class role cards, sealed exits, the tutorial floor in data/story/tutorial_floor.json driven by src/core/story/tutorial.gd) are done. PT Parts 3 to 9 and P2 Parts 1 to 3 are done, including cutscenes (M14: data/cutscenes/, src/core/story/cutscenes.gd, the `Cutscenes` autoload, docs/CUTSCENE_GUIDE.md) and the intro and tutorial day (M15). VD Parts 1 to 4 are done (combos in data/combos.json and src/core/combos.gd, the spark in src/core/progression/spark.gd, VFX and art fallback chains, docs/CUSTOMIZE.md; `--modal=res://...gd` with `--seed=1` opens a screen for screenshots). VD is done (Parts 5 and 6: demo mode in data/demo.json, the `Feedback` autoload with F8 zips, export_presets.cfg, tools/capture_shots.gd, docs/PRESS_KIT.md; `tests/smoke_ui.gd` audits every screen's buttons). Next: the roadmap from M12 (skip M14 and M15); AC after the demo ships. Keep docs/DEMO_CHECKLIST.md current. Balance tools: tools/sim_balance.gd (kill-time targets), tools/sim_ar.gd (win rates), tools/sim_nights.gd. Card effects are data ops run by src/core/combat/card_effects.gd; encounters are built by src/core/dungeon/encounters.gd; the arena is src/core/arena/ + src/scenes/arena/. Combat difficulty (Normal/Hard) lives in data/combat_rules.json. Slow test runner: `tests/smoke_arena.gd` (autoplay to wave 10). Combat turns are 2 Actions + 1 Quick (`actions_left`, `quick_used`, `CombatState.uses_actions/spend_action`; old modes stay in F1), enemies telegraph `intent`s (combat_state.gd "Intents" section, planned by EnemyAI.plan_intent). The UI theme is built in `UiTheme` from `data/ui.json` and skin asset ids; use its colors (`UiTheme.color("name")`, `UiTheme.vector_color(axis)`) and theme variations, never per-screen styleboxes. Art and sound are named by asset id (`data/assets/manifest.json`, loaded by the `Assets` autoload: `Assets.texture(id)`, `Assets.frame(id)`, `Assets.stream(id)`); sizes come from the `Display` autoload (`Display.tile`, `Display.base`). Never write a literal 16/32/480/270/640/360 in `src/` (a test checks). When any mechanic or number changes, update docs/MECHANICS.md. After changing the manifest, regenerate docs/ASSETS.md with `tools/gen_assets_doc.gd`. `Calendar.spend_ap(amount, kind)` takes an action kind for the gameplay log. Screenshots go in `tools/screenshots/` (gitignored). Push after every commit. Progress, decisions and stubs are tracked in `docs/PROGRESS.md`; the full alpha instructions are in `docs/PROMPT_alpha_run.md`. Final design decisions are in DESIGN.md Section 18. The cast is in `docs/characters.md` and the town plan in `docs/TOWN.md`; both are sources of truth.

## How this project is built

- Repo: https://github.com/suwechue/rpg.git (branch main). Commit and push after every milestone; never force-push.
- Combat is 2.5D (DESIGN.md Section 9): flat logic grid, projection only in the combat scene, unscaled pixel sprites.

- Engine: Godot 4.7, statically typed GDScript, tabs for indentation.
- Work one milestone at a time from DESIGN.md Section 17. Meet each milestone's "Done when" check, update docs/PROGRESS.md, commit and push, then continue to the next one (see docs/PROMPT_alpha_run.md) unless I ask you to stop.
- Display: 640x360 base resolution with 32x32 tiles (docs/ROADMAP.md, top). Sizes come from data/display.json via the `Display` autoload; never hardcode a tile size. `viewport` stretch, integer scaling, nearest filtering.
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
