# Progress log

Claude Code updates this at the end of every milestone and before stopping, so a new session can pick up where the last one ended.

| Milestone | Status | Notes |
| --- | --- | --- |
| M0 Project skeleton | Done | Autoloads, DataDB, input map, sandbox scene, run_tests.bat |
| M1 Vector core | Done | VectorOps (8 operations), RngStreams, CalendarLogic; 70 checks pass |
| M2 Characters, cards, decks | Done | Character model, derived stats, cards with MP cost and Tier caps, hybrids, Deck with Fatigue, leveling with pity; seeded mage reaches level 5 identically |
| M3 Grid combat | Done | 2.5D grid combat: all 11 Forms, Vector effects, Contest, Instability, Vector Wheel, initiative timeline, disposition AI, flee, downed/death, MP carry-over. F1 > Fights |
| M4 Calendar and AP | Not started | |
| M5 Town | Not started | |
| M6 Social system | Not started | |
| M7 The Upside-Down | Not started | |
| M8 Alpha content and polish | Not started | |

## Next step

Start M4 (calendar, AP, schedule, class events, skipping and detention, Night crafting).

## How to check

- Tests: `& $godot --headless --path . -s res://tests/run_tests.gd` (exit 0 = pass). Suites live in `tests/suites/*.gd` and extend `tests/suite.gd`; `run_tests.gd` runs its own `test_` methods and then every suite.
- Load check: `& $godot --headless --path . --quit`.
- Screenshots (needs a window, not headless): `& $godot --path . -- --scene=res://... --debug --shot=C:/out.png --frames=30` (handled in `DebugMenu._dev_args`).
- Scene smoke tests (autoloads + real scenes): `& $godot --headless --path . -s res://tests/smoke_scenes.gd` (exit 0 = pass). Add a `smoke_*` method per scene.
- Dev flags after `--`: `--seed=N --class=mage` (fresh run), `--scene=res://...`, `--autoplay` (AI plays the party), `--debug`, `--shot=PATH --frames=N`.
- F1 opens the debug menu in any scene.

## Milestone notes

### M2 (done)
- `src/core/data_tables.gd` is the pure JSON loader; `DataDB` and the tests both use it. Core functions take the whole tables Dictionary as `db`.
- `src/core/character.gd`: characters are Dictionaries (save as JSON). `create()`, `derived()` (formulas in `data/stats.json`), `collect_mods()` merges trait, perk, equipment and `extraMods` edits (numbers add, `*Mul` keys multiply).
- `src/core/card.gd`: spell designs have parseable ids (`sp:heat+cold:burst:minor`), so plain designs are never stored; crafted cards with Properties go in `GameState.cards`.
- `src/core/deck.gd`: Deck (draw pile, hand, discard, exhausted consumables).
- `src/core/progression/leveling.gd`: XP 20 x level, 3 stat points by Sample, Vector roll every level, Form roll on even levels, pity after 3 dry rolls, perks at 3/6/9, Knowledge Tier lines.
- Debug menu (F1): Character sheet, Leveling (+1 level, +50 XP, new run per class, perk picks).

### M3 (done)
- Core in `src/core/combat/`: `grid.gd` (CombatGrid: terrain from ASCII layouts, burning/steam, AStarGrid2D paths, LOS), `forms.gd` (targets + footprints for all 11 Forms), `unit.gd` (CombatUnit from a character or enemy record, props), `resolver.gd` (damage, Contest, MR, crit, flank, Instability, failure table, Wild Surge), `combat_state.gd` (turns, actions, effects, results), `enemy_ai.gd` (EV x Match(disposition, profile), Sample; also drives guests and `--autoplay`).
- Data: `data/rooms/combat_layouts.json` (map letters in `grid.gd`), `data/rooms/themes.json`, `data/ai.json`, `data/enemies/week1.json` (6 normal + 1 elite), `vectors.json` failures.
- Scene: `src/scenes/combat/` (combat.gd controller + HUD, combat_field.gd floor/overlays, unit_view.gd sprites, grid_projection.gd). `GameState.start_combat(setup)` / `finish_combat()` / `leave_combat()` hand fights in and out; the scene reads `GameState.pending_combat`.
- `Audio` autoload plays ids from `data/audio.json` (Ninja Adventure music and sfx).
- Balance snapshot (AI vs AI, 30 seeds): duo parties win 57 to 100% of week-1 fights; a solo Mage wins 13% against three enemies. Tune in M8.

## Decisions made during development

- **Git remote:** adding `origin` was blocked by the Claude Code permission classifier in this session, so commits are local only. To push: `git remote add origin https://github.com/suwechue/rpg.git` then `git push -u origin main`. Art and audio under `assets/` are tracked with Git LFS.
- **Assets imported** with `godot --headless --import`; the `.import` files are committed. The pack font imports with antialiasing, hinting and subpixel positioning off.
- **UI font:** NormalFont.ttf has a 227.5-unit pixel grid (2048 per em), so its native size is 9px (18 for titles). Its space is 1px, so the theme uses a FontVariation with +2 space width (`assets/ui/theme.tres`, set as the project theme because theme inheritance stops at Node2D parents).
- **Starter decks are 10 cards** for every class (the Mage's "8-card deck" plus Strike and 2 Guard) so they meet the 10-card deck minimum.
- **Known Vectors ignore the Knowledge Tier.** The tier caps Magnitude and which new Vectors and Forms level-up rolls can teach. Class kits that start with a Tier 2 Vector (Healer: Light) can use it from day one.
- **Form tiers:** Tier 1: Bolt, Burst, Shield, Weapon Infusion, Touch, Projectile, Line, Aura (every class kit uses only these). Tier 2: Sphere, Construct, Glyph.
- **Knowledge Tier rises** at level 5 with INT 8 (Tier 2) and level 10 with INT 12 (Tier 3) (`data/leveling.json`). Boss rewards can also raise it (M8).
- **Leveling details** (ported from Nexus): XP to next level = 20 x level; a Vector learning roll every level and a Form roll on even levels; a known axis rolled again gains +2 affinity; pity after 3 dry rolls per table.
- **HP growth:** derived formula plus a per-class `hpPerLevel` (Mage 1, Fighter 3, others 2). MP grows only through stats.
- **Hand limit:** draws stop at 7 cards; the extra cards stay in the draw pile.
- **Combat rules picked where the design was open:** range is Manhattan distance; damaging AoEs only hit the caster's opponents (and props), healing only hits allies (no friendly fire). Line and Projectile aim in the 4 grid directions. Units block movement; downed party members stay on the grid as bodies and can be revived by any heal.
- **Turn order:** each turn draws 2 cards (including the first, so a full opening turn has 7). Statuses (slow, root, blind, haste, rally) last through the unit's next turn. Tile effects and constructs count down per round.
- **Forms:** Shield absorbs Magnitude for 2 of the target's turns; a Light or Vitality Shield also heals 80% of Magnitude. Aura follows the caster and ticks at the start of each of their turns for 3 turns (cast turn included). Construct is a sight-blocking barrier with HP = Magnitude for 3 rounds. Glyph is a trap for 6 rounds that fires the spell on an opponent who steps on it. Weapon Infusion adds half the Magnitude to the next 2 Strikes plus the Vector's Contest and effect.
- **Vector effects:** Heat burns tiles 2 rounds (3 damage on entry or turn start) and makes water into steam; Cold slows 1 turn and freezes water to ice; Force pushes 1 tile per 10 Magnitude (min 1), 4 collision damage to both; Motion pulls enemies 1 tile and gives allies +2 Movement; Binding roots; Light blinds (35% miss) and heals with Shield/Aura; Transmutation clears hazards and water; Vitality drains 50%; Corrosion shreds 2 Defense and 4 Magic Resistance.
- **Instability failures** are a weighted Sample: Fizzle 4, Backlash 3 (half damage to the caster), Misfire 2 (random valid target), Wild Surge 1 (random Vector from all 9, same target).
- **Perks in combat:** Overchannel (first improvise at normal cost), Second Wind (auto at <30% HP), Backstab (+50% from behind or a different row within 1 column), Triage (-1 MP on heals for allies under half HP), Hype (+4 initiative and +1 draw on turn 1 for the whole party).
- **Guests call for help** (Kelly, M6): when hurt below 60% or next to an enemy at the start of their turn. The call is answered if a player-controlled unit heals or shields them, or hits an enemy next to them, before their next turn.
- **Units are drawn at 2x** (integer scale) in combat; bosses at 1x since their sheets are already 50 to 60 px.
- **Magic Resistance as a percent:** each point of Magic Resistance is 2% spell damage reduction, capped at 60% (`stats.json` combat block).

## Stubs and known issues

- Combat: no tethering (Binding's second effect) and no hidden units yet (Light's reveal has nothing to reveal). Constructs are always barriers (no turrets or decoys).
- The combat timeline shows 2-letter name tags instead of portraits.
- Git: no remote configured (see Decisions); nothing has been pushed.

- The M0 sandbox (`src/scenes/main.tscn`) is still the main scene; it is replaced by the title screen and town in later milestones.
