# Combat Update (separate milestone: CU)

This is a **separate milestone, CU (Combat Update)**, outside docs/ROADMAP.md. Don't renumber or edit the roadmap for it. Do it as the next milestone after the one currently in progress, then return to the roadmap where you left off. Track it as its own row ("CU Combat Update") in docs/PROGRESS.md and commit it as "CU: combat update". If M11 (UI skin) is already done, use its skin for the new combat UI; if not, keep the UI changes simple and M11 will restyle them.

User playtest feedback (Oct 24): turn order feels wonky, you can't tell when enemies attack, clicking a card by accident locks you out of moving, MP is so high from the start that you can spam spells, nothing is telegraphed, and effects don't make movement matter. Combat is the core of every night, so fix it before the big map and story work. Rules go in `src/core/combat/`, numbers in data; keep it testable with `tools/sim_nights.gd`.

### 1. Turn structure: move, then one action
- Each unit's turn is **Move (up to Movement tiles) + 1 Action**, like Fractured but Whole. An action is a card, Strike, Guard or an improvised cast. Move and act in either order. Movement can be split around the action only if the unit hasn't used all its tiles.
- **Quick cards** (a `quick: true` flag on a card; for example Guard, small Light heals, some items and cheap Motion cards) don't use the action. Limit: 1 quick card per turn.
- **Undo move:** before acting, the player can undo the move this turn (the Back button or Esc returns the unit to its start tile).
- Rounds are explicit: every unit acts once per round, in initiative order. A "Round N" banner shows at the start of each round. The timeline shows this round and the next, with portraits, and the active unit is highlighted. The design's individual initiative stays.

### 2. MP that matters
- **Smaller pool:** Max MP becomes roughly 8 to 12 at level 1 (a new formula in `data/stats.json`, for example 6 + INT/2 + WIL/3), growing slowly with level. Regen drops to 1 per turn, plus rest rooms and deli food.
- **Costs stay meaningful:** Minor 1, Standard 2, Major 4, Grand 7 MP plus Form cost. Most turns should use a 0 to 2 MP card; a Major spell should be a big decision. MP still carries over across the night (DESIGN.md Section 18).
- **0-cost basics stay strong enough:** Strike and the class's basic attack card must remain a sensible choice so a low-MP turn never feels wasted.
- Re-run the simulators and tune until a duo party wins most week 1 fights without draining all MP by the second fight. Log the numbers in PROGRESS.md.

### 3. Clear selection and controls
- **Hover preview before clicking:** hovering a card in hand (mouse) or highlighting it (keyboard or controller) immediately shows, on the grid:
  - its range (every tile it can target from where you stand), as a light tint;
  - its area of effect at the most likely target (the hovered tile, or the nearest valid enemy), as a stronger tint in the card's Vector color;
  - the units it would hit, with predicted damage, healing and status;
  - where pushed or pulled units would land, and any collision damage.

  The preview disappears when the card is no longer hovered. No click is needed to see what a card does, so you can compare cards before committing.
- A small state machine for the player's turn: **Idle → Card selected (targets shown) → Target hovered (footprint and damage preview) → Confirm.**
- **Deselect:** click the selected card again, right-click, or press Esc/B. You go back to Idle. Moving is always possible from Idle.
- Clicking a reachable floor tile while a card is selected deselects the card (it doesn't move you). A second click moves you, so a misclick never does something unexpected.
- Cards you can't afford, or that need an action you've already used, are greyed out with the reason on hover ("No action left", "Needs 4 MP").
- Hovering any tile shows what's there: unit stats, terrain, hazards, and which enemies threaten it.
- Every action has a keyboard and controller path.

### 4. Readable enemy turns
- Enemy turns play **one action at a time**:
  1. An "Enemy turn" banner.
  2. The camera nudges to the acting unit, which gets a highlight ring.
  3. It moves along its path visibly.
  4. A short wind-up (flash and sound).
  5. The hit: projectile or effect, damage numbers, hit flash, small shake.
  6. A one-line log entry.

  Pause about 0.3 to 0.6 s between steps.
- A **combat speed** option (normal, fast, instant) in data and later in Options (M22). Hold a key to fast-forward enemy turns.
- A scrollable combat log that names who did what to whom and why ("Frost Wolf hit New Kid for 6 (Cold, resisted)").

### 5. Telegraphs (enemy intents)
- At the start of each player turn, every enemy shows an **intent**:
  - An icon over its head: attack, buff, defend, move or special.
  - Its **target tiles** highlighted in red on the grid, for the attack it will make on its next turn.
  - Damage numbers on the threatened tiles.
- **The player can dodge:** moving out of a telegraphed tile avoids the attack. Enemy AI picks its intent at the start of the player's turn and commits to it; it re-aims only if its target is gone. Each enemy's `intents` in data choose between "locked tiles" (dodgeable area attacks) and "tracking" (single-target, follows the unit; used sparingly and shown with a different icon).
- **Big attacks charge up** for a full turn first (bosses especially), with a bigger, louder telegraph. Boss phases get unique telegraph patterns (lines, rings, checkerboards).
- Interrupts: some effects (Force push, Binding root, Light blind, Cold slow) can cancel or shift a charging attack. Show it in the preview when that will happen.

### 6. Movement that matters
- **Forced movement is a weapon:**
  - Force pushes and Motion pulls move enemies into hazards (burning tiles, water, glyphs).
  - They also move enemies **into other enemies' telegraphed tiles**, where enemies hit each other.
  - Collisions with walls or units deal damage to both.
  - The preview shows where a pushed unit will land and what it will hit.
- **Terrain combos:**
  - Cold freezes water into ice, and units pushed or moving onto ice slide until they hit something.
  - Heat on ice makes water.
  - Heat on water makes steam that blocks line of sight.
  - Binding can root an enemy inside a hazard or inside an ally's telegraph.
- **Positioning rewards:**
  - Back and flank attacks (Backstab and flanking rules), using the facing already in the design.
  - Half cover reduces ranged damage from the far side.
  - Line and Burst hit more when enemies are lined up or clustered, and the preview shows the count.
  - Standing next to a Friend-tier ally keeps the +5% adjacency bonus, shown as a link icon.
- **Enemies use space too:** melee enemies close in, ranged ones keep distance and use cover, some charge in straight lines (telegraphed), some create hazards, and bosses reshape the field between phases. Enemy movement shows its path.
- **Grid size check:** keep 9x5 by default, but confirm Movement values (3 + DEX/5) make the grid feel neither cramped nor trivial now that each turn is move + 1 action. Tune in data.

### Tests and checks
- Core tests for the move + action turn, quick cards, undo move, MP formulas, intent commit and dodge, forced movement landing and collisions, ice sliding and interrupting a charge.
- Smoke test: an autoplay fight still completes.
- Sim before and after (win rates, average turns per fight, MP left after fights 1 and 2), recorded in PROGRESS.md.
- Screenshots: a telegraphed enemy turn, a selected card with preview, a push into a hazard.

**Done when:** hovering any card shows its range and area of effect on the grid before clicking; in a week 1 fight you can see every enemy's next attack before your turn and dodge it by moving; a misclicked card can always be cancelled; each turn is clearly move + 1 action; MP lasts a night only if you spend it wisely; enemy actions play out one at a time and are easy to follow; and at least one push-into-hazard and one ice slide happen in the smoke-test fights.

