# Playtest patch 2: fixes, effect indicators and the road to the demo (separate milestone: P2)

This is a **separate milestone, P2**, outside `docs/ROADMAP.md`. Don't renumber or edit the roadmap for it. Track it as its own row ("P2 Playtest patch 2") in `docs/PROGRESS.md` and commit it as "P2: ...".

**Order (user request, Oct 28):**
1. Finish and commit the PT Part 8 step you're on now, then do **P2 Parts 1 and 2** (bugs and indicators). They're small and they break playtests.
2. Finish **PT Part 8**.
3. **VD Parts 1 to 4.**
4. **P2 Part 3:** cutscenes (ROADMAP M14), then the intro and tutorial day (ROADMAP M15), pulled forward because the demo needs them. Mark M14 and M15 Done in PROGRESS.md when finished so the roadmap pass skips them.
5. **VD Parts 5 and 6:** the demo build and feedback tools.
6. Then the roadmap from M12, skipping M14 and M15.

**Later, not now:** the arena campfire (`docs/ARENA_CAMPFIRE.md`, milestone AC). Its doc says when it's scheduled.

Where this doc changes an earlier rule, this doc wins. Keep `docs/MECHANICS.md` up to date with every rule change.

---

## Part 1: Bug fixes

### 1.1 Strike and Guard are labeled Quick but behave like Actions

**User report:** Strike and Guard say QUICK, but they still feel like they take actions.

**What I found:**
- **The core is mostly right.** In `combat_state.gd`, `strike()` and `guard()` call `_use_quick_builtin()`, which sets `quick_used` under `two_actions` for the party and doesn't touch `actions_left`.
- **The scene gates Strike on the Action.** In `src/scenes/combat/combat.gd` around line 1019, the "strike" button handler does `if not u.action_used: mode = "strike"`. Once both Actions are spent, `action_used` is true, so Strike can't be used. The button may still look enabled, since line 475 checks `quick_block` correctly. So the Quick only works while you still have an Action left. That's exactly the "the quick version isn't working" feeling.
- **A second possible cause: the F1 "Turn rule" override.** `GameState.combat_turn_mode` silently applies to "this fight and the next ones". Any mode other than `two_actions` makes `_use_quick_builtin` spend the action, but the QUICK badges still show.

**Fix:**
- **The handler:** in the scene's "strike" handler, replace `not u.action_used` with `state.quick_block(u) == ""`.
- **Other scene checks:** grep `src/scenes/` for every `action_used` and `actions_left` check on a party unit and route each through the state helpers (`act_block`, `quick_block`, `uses_actions`). Scenes shouldn't re-derive the rules. Check the keyboard shortcuts (around line 840), the card tooltip code (around 541) and the Party panel too.
- **QUICK badges:** decide whether to show them with one state helper, `is_quick_now(u, card_or_builtin)`. When the rule isn't `two_actions`, the badges and tooltips say "Action" instead of "Quick", so the label never lies.
- **The F1 override:** while it's active, show a small amber tag in the combat corner, e.g. "Turn rule: move_or_act (F1 override)". Clear the override on new run, title screen and arena start. The F1 menu gets a "Reset to data" button.
- **Tests (core):** under `two_actions`, run these four cases:
  - spend 2 Actions (Move and a card), then Strike an adjacent enemy: it works, and `actions_left` stays 0;
  - Strike first: `actions_left` is still 2;
  - Strike then Guard in the same turn: the second is refused (one Quick);
  - Guard after 2 Actions: it works.
- **Tests (scene):** a scene-level test presses the Strike button after 2 Actions and checks that targeting mode starts.

### 1.2 A button stays yellow after clicking another one

**Cause:**
- Cards (`card_view.gd` line 30) and the combat buttons use `FOCUS_ALL`, and the theme's focus style is `ui_button_focus`, a yellow outline.
- Clicking a button gives it keyboard focus, and focus stays until something else takes it. So the last-clicked box keeps its yellow outline even after the selection moves.
- The real "selected" state (selected card, active mode) is a different thing that just looks the same.

**Fix:**
- **Track the input mode:** `UiTheme` (or a small `InputMode` helper) tracks the last input device. Any mouse input switches to mouse mode; keyboard or controller input switches to nav mode.
- **Mouse mode:** clicking a button or card releases its focus, and the focus style is the empty stylebox, so nothing stays outlined.
- **Nav mode:** the focus outline shows, so keyboard and controller play still works. VD's demo checklist needs every screen reachable by keyboard and controller, so don't just set `FOCUS_NONE` everywhere.
- **Selection gets its own look:** a selected card or the active mode button (Strike targeting, Move, the Wheel) uses a "selected" theme variation that's visually different from focus. For example, a raised card with a Vector-colored glow, and a filled button background instead of an outline. Exactly one thing is "selected" at a time, and it clears when the mode is cancelled.
- **Apply it everywhere:** every screen with buttons (combat, arena, forge, party panel, point buy, shop, schedule, dialogue choices, modals).
- **Test:** a scene test clicks card A and then card B, then checks that A has neither the selected nor the focus look.

### 1.3 Card pick after a wave: choose whose deck it goes into

**Cause:** `Arena.pick_card()` (`src/core/arena/arena.gd`, around line 253) only adds the card to `run["collection"]` and the picks list, never to a member's `deck`. The scene (`src/scenes/arena/arena.gd` `_card_pick()`) offers no owner choice.

**Fix:**
- **Choosing the owner:**
  - Clicking an offered card opens an **owner row**: party portraits, each with deck size and a one-line fit hint ("knows Heat", "class pool", "basic card: anyone").
  - Eligible members are lit. Ineligible ones are greyed out with the reason as a tooltip, e.g. "Brick doesn't know Cold".
  - Eligibility uses the same rules as deck editing: class pool, known Vectors and Forms, or a basic card.
  - **Benched members:** members on the bench (not in this fight) are listed under a divider and are also valid.
  - **"Collection only (add at a checkpoint)":** always offered. It keeps today's behavior for players who want to decide later.
- **The core function:** `Arena.pick_card(db, arena, run, card_id, member_id := "")` appends the card to that member's `deck` and still counts it in the collection for the score. A new `Arena.eligible_owners(db, run, card)` returns members with reasons. The scene, the autoplay and the tests all use it.
- **Feedback:** a toast ("Ember Bolt added to Ash's deck") and the owner's portrait pulses. Undo is available until the next wave starts: return the card to the offer.
- **Autoplay:** gives the card to the eligible member with the smallest deck, ties broken by best tag fit (reuse the `deck_tags` scoring that `card_offer` already does).
- **Story mode:** use the same owner row anywhere a card is granted to the party, not just to the player: dungeon treasure cards, event rewards and boss rewards. Crafted cards still go to the crafter.
- **Tests:**
  - the card lands in the chosen deck;
  - ineligible members are refused;
  - "collection only" doesn't touch any deck;
  - autoplay's choice is deterministic for a seed.

### 1.4 Small fixes found along the way

- **The Lambda capture warning:** fix the "Lambda capture at index 1 was freed" warning in `tests/smoke_arena.gd`. The autoplay coroutine has to stop when its scene changes, e.g. by checking `is_inside_tree()` after each `await`. VD's demo goal is zero errors in the log.
- **The turn rule in the F1 menu** shows the effective rule (data or override), not a blank when the override is "".

---

## Part 2: Seeing your active effects (mutators, perks, Techniques)

**User report:** there's no on-screen sign that you have mutators or perks, and no way to see what they do.

### 2.1 The effects strip

A column of small icons on the left edge of the screen, in **combat, the arena between waves, dungeon floors and the town HUD** (whatever applies there).

**What it shows:**
- **Arena mutators:**
  - Each mutator's icon and a counter for waves left until the next checkpoint.
  - Risky mutators get a red border, helpful ones green.
  - "Double rewards, no rest next checkpoint" style mutators show both halves.
- **Run modifiers:** the combat difficulty (Normal or Hard), the minigame Easy setting, the Journal starting trait and any debug override (the F1 turn rule, in amber).
- **Story effects:** injuries, Kelly's Risk tier if it's a combat factor, day modifiers (rain, a festival) and anything else that changes rules today.

**How it works:**
- **Hover:** shows a tooltip with the name, plain-language effect, source ("Mutator, picked at wave 5") and duration.
- **Click:** opens the full **Effects** page (2.3).
- **Combat effects show where they apply:** when a mutator changes a number in combat, the hover preview shows it. For example, "+50% (Cold Front)" appears in the damage breakdown, and the enemy info shows "+30% HP (Thick Skins)". That way the player sees the mutator working, not just an icon.

### 2.2 Perks and Techniques on the party

- **Small badges:** each party portrait (the combat timeline, the Party panel, the arena roster) shows small badges for that member's perks. After PT Part 8, it shows Techniques with their rank.
- **Hover a badge:** shows the effect text.
- **Turn banner:** the turn banner lists the active member's perks that matter this turn, e.g. "Guardian: Guard shields adjacent allies".
- **When a perk triggers in combat:** it floats its name over the unit ("Bulwark!") and writes a log line. That shows players it's working.

### 2.3 The Effects page

- **Where it is:** a new tab in the Party panel (pause menu, combat and arena), and the target of a click on the effects strip.
- **What it lists:**
  - Run-wide effects (mutators, difficulty, traits).
  - Then each member with their perks or Techniques, statuses that persist between fights, and equipment effects.
- **Every entry:** icon, name, full text, source and duration.

### 2.4 Data and assets

- **Icons:**
  - Icons use asset ids: `icon_mutator_<id>`, `icon_perk_<id>`, `icon_technique_<id>`, `icon_effect_<id>`.
  - The fallbacks are `icon_mutator_default`, `icon_perk_default`, `icon_technique_default` and `icon_effect_default`, so the user can draw them later.
  - Add them to the manifest and `docs/ASSETS.md`.
- **Text:** names and effect text come from the existing data records (`data/arena/mutators.json`, `data/perks.json` and so on) and `data/strings.json`. Every mutator and perk needs a player-facing `desc`; add a test that fails when one is missing.
- **A single source of truth:** `src/core/effects.gd` gathers "everything active right now" from the run, the arena, the party and the day. The strip, the page and the tests all read it.

**Tests:**
- `effects.gd` returns each mutator, perk and modifier for a known setup.
- Mutator damage shows up in the hover breakdown.
- Every mutator and perk has a desc and an icon id.

---

## Part 3: Cutscenes, then the intro and tutorial day (ROADMAP M14 and M15, pulled forward)

Do this after VD Parts 1 to 4 (see the order at the top).

### 3.1 The cutscene system: build ROADMAP M14 as written

M14 covers the data-driven steps, actors, skip and fast-forward, the debug menu, `--cutscene=id` and `docs/CUTSCENE_GUIDE.md`. Add these for the demo:

- **Step types:**
  - `portrait_talk`: a dialogue box with large portraits left and right, for scenes without a map.
  - `title_card`: big text, for "Week 1", "Wave 10" and so on.
  - `wait_input`.
  - `if_flag`: branches.
- **Combat cutscenes:** cutscenes can play **inside combat** at the start or on a trigger (boss phase change, a unit downed, a wave start). The board stays visible and the camera pans to the actor. Add combat-trigger hooks in the encounter data: `"cutscenes": {"start": "...", "phase2": "..."}`.
- **Voice blips** come from VD's audio map, and the typing speed from options.
- **First cutscenes to write:**
  - The Kelly tutorial floor: the intro, her betrayal or save branch, and the end.
  - The Hollow Mascot: the intro and phase 2.
  - The Endless Arena: the first entry, the first wave-10 boss and a new best score.
  - Convert the existing story beats in `data/story/*.json` that are text boxes today.
- **Asset ids:** all art, music and sounds go through asset ids. Backgrounds for map-less scenes use `art_cutscene_<id>`, with a fallback to a tinted blur of the current scene.

### 3.2 The intro and tutorial day: build ROADMAP M15 as written

- **The intro:** moving day, the narrator's hook, then character creation. The order is name and look, then the spark quiz (VD Part 3) and point buy (already built).
- **The tutorial day:** the full Monday table from M15. It ends with the existing Kelly tutorial floor.

**Done when:**
- A new story run opens with the intro cutscene.
- The tutorial day plays to the Kelly floor with cutscenes at each beat.
- The arena and the Hollow Mascot have their cutscenes.
- Every cutscene can be skipped.

---

## Part 4: What we have and what's missing for a complete demo

The demo is defined by VD Part 5: the intro through the week 1 boss, the Endless Arena from the title, a thanks screen, a survey and a Windows build. This audit is based on the code as of Oct 28. Use it as the checklist and keep it current in `docs/DEMO_CHECKLIST.md` (VD Part 5 creates it; start it now from this table).

| Area | Status | Notes |
| --- | --- | --- |
| Town life sim (AP day parts, classes, schedule, dialogue, Charisma gates, misheard lines, Bond, shops) | Have | Interiors still use drawn rectangles for furniture |
| Dungeon floors, Friday boss, Kelly tutorial floor | Have | Floors use generic rooms with a theme tint |
| Combat (2 Actions + 1 Quick, telegraphs, cover, statuses, Forge, class pools) | Have | Strike and Guard Quick bug (P2 1.1); Binding tethers and hidden units are stubs |
| Endless Arena (waves, hazards, checkpoints, mutators, card and perk picks, score) | Have | Owner choice (P2 1.3), effects strip (P2 2), campfire later (AC) |
| Point buy, Party panel, pause menu, options | Have | Check that options open from the title screen (VD Part 5) |
| Art, audio and UI by asset id | Mostly | VD Part 1: audio situation map, voice blips, `docs/CUSTOMIZE.md`, audit test |
| Advanced Vectors and Techniques | In progress | PT Part 8 |
| Multi-Vector combos and the Compendium | Missing | VD Part 2 |
| Spark quiz | Missing | VD Part 3 (needs the intro, so it runs as a standalone screen until M15) |
| Visual card builder and crafting juice | Missing | VD Part 4 |
| Cutscene system | Missing | P2 Part 3 (M14) |
| Intro and tutorial day | Missing | P2 Part 3 (M15). Today a new run starts directly in the game |
| A friendship scene in week 1 | Missing | VD's checklist wants one. Write one scripted scene with the cutscene system (Dex or Theo at lunch); the full system is M18 |
| Title logo slot and animated title background | Missing | `art_logo` asset id with a placeholder (VD Part 5) |
| Demo mode, thanks screen, export preset | Missing | `data/demo.json`, `export_presets.cfg` "Demo" (VD Part 5) |
| Feedback (F8, survey, log summary) | Missing | VD Part 6 |
| Keyboard and controller navigation on every screen | Partial | The focus fix (P2 1.2) is the base; audit each screen |
| Juice pass (hit effects, shake, UI sounds, fades, footsteps) | Partial | VD Part 5 |
| End-to-end demo smoke test, zero errors in the log | Missing | VD Part 5 |

**After the demo** (ROADMAP and AC, not demo blockers): modular maps and visual variety (M12, M12b), the new school (M13), class scenes (M16), living town (M17), the phone (M18), AP balance (M19), the mirror Upside-Down (M20), the fountain finale (M21), polish (M22), release (M23), and the arena campfire (AC).

---

## Tests and done when

**Tests:** the ones listed in each part, plus the full suite and `tests/smoke_arena.gd` with no new warnings.

**Done when:**
- **Part 1:**
  - Strike and Guard work as Quicks after both Actions are spent and never cost an Action.
  - Labels match the real rule, and the F1 override is visible and resettable.
  - No button or card stays outlined after clicking something else, and keyboard focus still shows in nav mode.
  - Every card pick goes to the member you choose (or the collection on purpose), in the arena and in story rewards.
- **Part 2:** mutators, run modifiers, perks and Techniques are always visible as icons with hover text, and have a full Effects page.
- **Part 3:** cutscenes play in the story and the arena, and a new run opens with the intro and tutorial day.
- **Part 4:** `docs/DEMO_CHECKLIST.md` exists, built from this table, and is updated as items close.
- **Screenshots in `tools/screenshots/`:**
  - the owner row;
  - the effects strip with a tooltip open;
  - the Effects page;
  - a combat cutscene.
