# Progress log

Claude Code updates this at the end of every milestone and before stopping, so a new session can pick up where the last one ended.

| Milestone | Status | Notes |
| --- | --- | --- |
| M0 Project skeleton | Done | Autoloads, DataDB, input map, sandbox scene, run_tests.bat |
| M1 Vector core | Done | VectorOps (8 operations), RngStreams, CalendarLogic; 70 checks pass |
| M2 Characters, cards, decks | Done | Character model, derived stats, cards with MP cost and Tier caps, hybrids, Deck with Fatigue, leveling with pity; seeded mage reaches level 5 identically |
| M3 Grid combat | Not started | |
| M4 Calendar and AP | Not started | |
| M5 Town | Not started | |
| M6 Social system | Not started | |
| M7 The Upside-Down | Not started | |
| M8 Alpha content and polish | Not started | |

## Next step

Start M3 (grid combat, 2.5D).

## How to check

- Tests: `& $godot --headless --path . -s res://tests/run_tests.gd` (exit 0 = pass). Suites live in `tests/suites/*.gd` and extend `tests/suite.gd`; `run_tests.gd` runs its own `test_` methods and then every suite.
- Load check: `& $godot --headless --path . --quit`.
- Screenshots (needs a window, not headless): `& $godot --path . -- --scene=res://... --debug --shot=C:/out.png --frames=30` (handled in `DebugMenu._dev_args`).
- F1 opens the debug menu in any scene.

## Milestone notes

### M2 (done)
- `src/core/data_tables.gd` is the pure JSON loader; `DataDB` and the tests both use it. Core functions take the whole tables Dictionary as `db`.
- `src/core/character.gd`: characters are Dictionaries (save as JSON). `create()`, `derived()` (formulas in `data/stats.json`), `collect_mods()` merges trait, perk, equipment and `extraMods` edits (numbers add, `*Mul` keys multiply).
- `src/core/card.gd`: spell designs have parseable ids (`sp:heat+cold:burst:minor`), so plain designs are never stored; crafted cards with Properties go in `GameState.cards`.
- `src/core/deck.gd`: Deck (draw pile, hand, discard, exhausted consumables).
- `src/core/progression/leveling.gd`: XP 20 x level, 3 stat points by Sample, Vector roll every level, Form roll on even levels, pity after 3 dry rolls, perks at 3/6/9, Knowledge Tier lines.
- Debug menu (F1): Character sheet, Leveling (+1 level, +50 XP, new run per class, perk picks).

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
- **Magic Resistance as a percent:** each point of Magic Resistance is 2% spell damage reduction, capped at 60% (`stats.json` combat block).

## Stubs and known issues

- The M0 sandbox (`src/scenes/main.tscn`) is still the main scene; it is replaced by the title screen and town in later milestones.
