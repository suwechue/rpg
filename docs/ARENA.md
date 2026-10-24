# Endless Arena and Combat Depth (separate milestone: AR)

This is a **separate milestone, AR (Arena)**, outside `docs/ROADMAP.md`. Don't renumber or edit the roadmap for it.

**Order:** CU (Combat Update, `docs/COMBAT_REWORK.md`), then **AR**, then VD (Vectors and Demo, `docs/VECTORS_DEMO.md`), then back to the roadmap where you left off. Track it as its own row ("AR Arena and combat depth") in `docs/PROGRESS.md` and commit it as "AR: ...". Where this doc changes a CU rule, this doc wins. VD's combos plug into the arena when VD is built, and VD's demo build includes the arena mode.

**Goal:** make combat harder and more tactical, add much more card, spell and enemy variety, and add an endless arena that shows all of it off. Follow the modularity rules: all content in data, all art and audio by asset id, all text in strings.

User playtest feedback (Oct 24): combat is too easy; after attacking you can't move, but the balance between moving and attacking still doesn't create tension; Burst's area is too wide; there isn't enough card and spell variety.

---

## Part 1: Turn rule, move OR act

- **New default turn rule:** each turn, a unit either **moves** (up to its Movement) **or acts** (one card, Strike, Guard or improvised cast), not both.
- **Enemies telegraph** (from CU) the attack they'll make on their next turn. Each turn the player decides: move out of the danger tiles and don't attack, or attack and try to kill or disable the enemy before it hits.
- **Exceptions that keep it from feeling stuck:**
  - **Quick cards** (1 per turn) can be used with either a move or an act.
  - **Lunge and dash cards:** some actions include movement (Part 3, for example Lunge: move up to 2 tiles in a line and Strike). Melee characters must have at least two in their starting decks.
  - **Disabling counts:** pushing an enemy out of range, rooting it, blinding it or killing it cancels or shifts its telegraphed attack, and the preview shows when that will happen (from CU).
- **Enemies follow the same rule:** an enemy whose telegraphed target is out of its zone moves instead (and re-telegraphs). Enemies don't move and attack in one turn unless their data says so (rare, for fast elites).
- **One setting:** `data/combat_rules.json` gets `"turnMode": "move_or_act"` (default), `"move_then_act"` (CU's rule) or `"move_and_act"`. The F1 debug menu can switch it mid-fight for playtesting. All tests and simulations run in the default mode, and the sim reports win rates for all three.
- **Difficulty target:** a week 1 fight should be lost if the player ignores telegraphs, and won comfortably if they read them. Tune enemy damage, HP and telegraph timing in data until the sim shows that gap. Record it in PROGRESS.md.

## Part 2: Area of effect tuning

- **Burst:** Minor and Standard Magnitude are a **plus shape** (center + 4 tiles). Major and Grand are the full 3x3. Sphere and Aura are reviewed the same way. Footprints live in `data/forms.json` per Magnitude, not in code.
- **Damage per tile:** area attacks keep their lower multiplier. Add a rule that area attacks deal 25% less to every target beyond the second, so area spells reward positioning without deleting whole waves.
- The hover preview (CU) shows the exact tiles for the card's Magnitude.

## Part 3: Card and spell variety

The game has 12 card records plus generated spells. Add **at least 48 new cards**, about 8 per Tier 1 and 2 Vector, with effects beyond damage. Plus basic and weapon cards. All in `data/cards/`, each with a card art id (VD's fallback chain) and VFX and sound ids. Starting set (tunable):

| Vector | Cards |
| --- | --- |
| Heat | Ember Bolt (damage, burn), Fire Wall (Line of burning tiles that blocks paths), Kindle (quick: next Heat card +50%), Ignite (detonates every burning tile for damage), Heat Mirage (decoy that draws an enemy's telegraph), Smoke Screen (steam cloud), Cauterize (heal and remove a status, self burns), Flashover (Burst; larger if standing on fire) |
| Cold | Frost Bolt (slow), Ice Wall (Construct), Flash Freeze (turns an area to ice; units on it slide), Shatter (big damage to frozen or slowed), Chill Aura, Cold Snap (cancels a charging attack if it hits), Rime Armor (Shield + slow attackers), Hailstorm (random tiles over 2 turns, telegraphed for both sides) |
| Force | Shove (push 2), Quake (row knockback), Gravity Well (pulls everything 1 tile toward the center), Breach (destroys cover and Constructs), Brace (quick: immune to push this round), Hammerfall (delayed big hit next turn, telegraphed to enemies too), Recoil (push target, push self back), Pin (push into a wall roots the target) |
| Motion | Dash (quick: +2 move tiles), Blink (teleport 3), Swap (swap any two units in range), Haste (ally gets move and act next turn), Reposition (move an ally 2 tiles), Lunge (move 2 in a line and Strike), Afterimage (leave a decoy where you stood), Tailwind (all allies +1 Movement for a round) |
| Binding | Snare (Glyph that roots), Tether (link two enemies: damage to one hits both), Anchor (root), Lockdown (cancels a charge and roots), Leash (pull to you), Bind Wounds (heal over time), Net (root in a plus shape, no damage), Pact (link with an ally: share damage) |
| Light | Flare (blind area), Mend (heal), Beacon (taunt: enemies retarget to the caster), Sunbeam (Line damage that pierces), Reveal (shows hidden enemies and traps and the full telegraph timeline), Halo (Shield to adjacent allies), Dazzle (quick: blind one), Radiance (heal allies and damage enemies in a ring) |
| Basic and weapon | Lunge, Parry (quick: next melee hit against you is countered), Brace, Throw (hurl an item or prop), Second Breath (small heal, 0 MP, once per fight), Shove (basic 1-tile push), Taunt, Overwatch (hit the first enemy that enters a chosen tile) |

- **Card rarity** (common, uncommon, rare) for rewards and shops. **Upgraded versions** ("Ember Bolt+") through crafting or arena rewards.
- **Class starting decks** rebuilt so each class plays differently under move-or-act: Fighter (Lunge, Parry, Brace), Rogue (Dash, Blink, Afterimage), Mage (range and area), Healer (Mend, Halo, Beacon), Bard (Haste, Tailwind, Dazzle).
- **Tier 3 cards** (Transmutation, Vitality, Corrosion): at least 3 each, unlocked by Knowledge Tier 3.

## Part 4: Enemy variety

Add **at least 12 new enemy behaviors**, reusing existing sprites with palette swaps through asset ids until the user draws new ones. Each behavior is a data profile (AI weights, intents, movement style).

| Type | Behavior |
| --- | --- |
| Charger | Telegraphs a straight-line charge, then runs the whole line |
| Bomber | Telegraphs a 3x3 explosion around itself; dies doing it |
| Healer | Stays back and heals allies; telegraphs heals in green |
| Summoner | Spawns a minion every 2 turns |
| Shield bearer | Blocks attacks from the front; needs flanking or a push |
| Burrower | Disappears and resurfaces under a telegraphed tile |
| Sniper | Long-range Line attack, telegraphed 2 turns ahead |
| Splitter | Splits into two smaller enemies on death |
| Hazard maker | Leaves fire, ice or glyphs as it moves |
| Mirror | Copies the last card the player used |
| Leech | Drains MP instead of HP |
| Anchor | Roots everyone next to it each turn |

- Elites are a stronger base enemy plus 1 or 2 **affixes** from `data/enemy_affixes.json` (Hasted, Armored, Burning, Vampiric, Shielded, Explosive), shown as icons.

## Part 4b: Bigger, smarter multi-enemy encounters

An audit on Oct 24 found the encounter sizes too small: `data/dungeon.json` "enemiesPerFight" is 2 to 4, "enemyCapByWeek" caps week 1 at 2 and week 2 at 3, and "partyScale" halves the count and cuts power to 75% for a solo player (so a solo week 1 fight is often one enemy). That's a big reason combat feels easy.

**New counts (starting values, tune with the sim):**

| Week | Normal fights | Elite rooms | Boss floor |
| --- | --- | --- | --- |
| 1 | 3 to 4 | 4 (1 elite) | Boss + adds per phase |
| 2 | 4 to 5 | 5 | Boss + adds |
| 3 | 4 to 6 | 5 to 6 | Boss + adds + reinforcements |
| 4 | 5 to 6 | 6 | Boss + adds + reinforcements |
| 5 | 5 to 7 | 6 to 7 | Boss + adds + reinforcements |

- Remove "enemyCapByWeek", or raise it to match the table.
- **Party scaling** keeps a real fight for small parties:

  | Party size | Count | Power |
  | --- | --- | --- |
  | Solo | 0.75 (never below 2 enemies) | 0.85 |
  | Duo | 0.9 | 0.92 |
  | Trio | 1.0 | 1.0 |
  | Full party | 1.0 | 1.0 (count +1) |

**Minions:** add a weak "minion" tier (low HP, often one-hit, small telegraphs) so big groups are threatening without fights dragging. Every week's enemy pool gets 2 or 3 minion types (palette swaps via asset ids are fine). Minions count as half an enemy for encounter budgets.

**Encounter templates** (`data/encounters.json`): instead of random picks, fights are built from templates with role slots filled by enemies that match the week's signature. Each template has a weight per week:

| Template | Makeup and twist |
| --- | --- |
| Pack | 3 or 4 of one fast type that try to surround you |
| Front and back | A shield bearer or bruiser in front, with 2 snipers or casters behind |
| Swarm | 6 to 8 minions plus 1 leader; killing the leader scatters them |
| Healer core | 1 healer protected by 3 fighters; ignore the healer and the fight drags |
| Ambush | Enemies start on both sides of the party, which starts in the middle |
| Reinforcements | A smaller first group, then a second group arrives on round 3 at telegraphed spawn tiles |
| Summoner nest | 1 summoner plus 2 guards; the summoner adds minions every 2 turns |
| Hazard lords | Hazard makers on a layout full of fire or ice |
| Elite escort | 1 elite with affixes plus 2 or 3 normals |

Templates set the starting positions (formations), and the layout picks a bigger grid for big groups: 9x5 default, 11x6 for swarms and ambushes (from `data/rooms/combat_layouts.json`).

**Bosses:** every boss phase change brings adds (minions or a template group), and weeks 3 to 5 add a reinforcement wave mid-fight. Defined per boss phase in `data/enemies/bosses.json`.

**Enemy teamwork (AI):**
- Melee enemies try to surround (flank bonuses apply to them too).
- Enemies **stagger their telegraphs** so the safe tiles keep shrinking, rather than all hitting the same tile.
- Healers and summoners stay behind the front line.
- Enemies avoid standing in each other's telegraphs, unless pushed there (which stays the player's best trick).
- Focus fire: a wounded or isolated party member draws more attacks. This is weighted, not absolute, so it stays readable.

**Keeping big fights readable and quick:**
- Overlapping telegraphs on the same tile show combined damage.
- A **threat view** toggle (hold a key) shades every tile by how much damage it will take next enemy turn.
- Minions in a group act together in one step (one banner, simultaneous moves) to keep enemy turns short.
- The combat speed setting from CU applies.
- The timeline groups identical minions ("Gremlin x4").

**Arena:** waves use the same templates, growing from 3 enemies on wave 1 to 8 to 10 by wave 20, with mixed templates after wave 10.

**Sim targets** (record before and after in PROGRESS.md):
- A full party reading telegraphs wins about 85 to 90% of week 1 normal fights and about 60 to 70% of the week 1 boss.
- A party ignoring telegraphs wins under 40%.
- A solo player can still win week 1 fights with careful play, at about 50 to 60%.
- Average fight length is 5 to 9 rounds.

## Part 5: The Endless Arena

**Where it lives:**
- **Title screen: "Endless Arena."** Play with a preset party (one per class) or import the party from your current save.
- **In the story: the Rift,** a stable pocket of the Upside-Down behind the abandoned lot (or another TOWN.md location if it fits better), unlocked in week 2. Entering costs an After School part. Losing there isn't death: you're knocked out and wake up at home, injured, and lose the rest of the day. Story rewards (XP, money, shards, cards) are only kept up to your last checkpoint.

**Waves:**
- An endless sequence of waves, seeded per arena run.
- Wave enemies come from the enemy pool scaled by wave number (more enemies, more affixes, more health).
- **Every 5th wave** is an elite wave. **Every 10th wave** is a boss: one of the 5 bosses, remixed with affixes.
- Wave rules live in `data/arena/waves.json`.
- Between waves: a short breather (no healing, MP regen only).

**Terrain changes every wave:**
- A new layout from a pool of hand-made arena layouts plus generated variations (`data/arena/layouts.json`), with **hazard sets** so the player meets every hazard:
  - fire and burning ground
  - water and ice
  - pits (instant knockout for enemies; heavy damage for players)
  - cover
  - glyph traps
  - collapsing floor (tiles fall after being stood on twice)
  - conveyor tiles (move units 1 tile at round end)
  - darkness (only Light reveals tiles)
  - toxic puddles (Corrosion)
- The next wave's hazard set is announced at the checkpoint, so the player can prepare.

**Checkpoints, every 5 waves:**
- The player gets **Arena AP** (3 per checkpoint; unspent AP carries over) to spend on:

  | Action | AP |
  | --- | --- |
  | Swap a card in a deck | 1 |
  | Craft a card (quick version of the workbench, with its minigame) | 2 |
  | Swap a teammate from the roster | 2 |
  | Change equipment | 1 |
  | Rest (heal 50% HP and MP) | 2 |
  | Reroll the next mutator choice | 1 |

  Costs live in `data/arena/checkpoint.json`.
- **Mutators:** pick 1 of 3 risk and reward modifiers that last until the next checkpoint (`data/arena/mutators.json`). Examples:
  - "Cold is stronger: +50% Cold damage for everyone"
  - "Enemies telegraph 1 turn earlier, but have +30% HP"
  - "+1 MP regen"
  - "Fire spreads each round"
  - "Double rewards, but no resting at the next checkpoint"
- **Bank and leave:** in story mode, leave at a checkpoint to keep the rewards earned so far.

**Score and records:**
- Score = waves cleared, plus bonuses (no damage taken, combos used, fast clears).
- A local best-score table per party size and per mutator count.
- The Narrator's Journal records the best wave.
- The narrator comments every 5 waves (lines in `data/narrator.json`).

**As a tool:**
- Dev flag `--arena --seed=N --waves=N --autoplay`.
- `tools/sim_arena.gd` runs the AI through waves and reports the average wave reached per class and per party, and the hardest waves and hazards. Use it to balance Parts 1 to 4.

**Modularity:** arena music, backgrounds, hazard tiles, mutator icons, the checkpoint screen and the score screen all use asset ids. Waves, layouts, hazards, mutators, checkpoint costs and narrator lines all live in data.

---

## Tests and done when

**Tests:**
- Core tests for:
  - each turn mode;
  - quick cards with move or act;
  - lunge and dash actions;
  - telegraph cancel and shift by push, root, blind and kill;
  - Burst footprints per Magnitude;
  - the area diminishing rule;
  - each new card effect;
  - each enemy behavior and affix; encounter templates, formations, party scaling and reinforcement spawns;
  - wave generation from a seed;
  - hazards (collapsing floor, conveyors, pits, darkness);
  - checkpoint AP spending;
  - mutators.
- A smoke test: autoplay reaches wave 10 in the arena with no errors.
- Sim results before and after in PROGRESS.md.

**Done when:**
- Move OR act is the default and the debug switch works.
- Ignoring telegraphs loses week 1 fights in the sim, and reading them wins.
- Burst is a plus shape below Major.
- At least 48 new cards and 12 enemy behaviors are in play.
- Fights use encounter templates with the new counts, minions, boss adds and reinforcements, and the sim hits the Part 4b targets.
- The Endless Arena runs from the title screen and from the Rift, with new terrain and hazards every wave, checkpoints every 5 waves with Arena AP edits, mutators, bosses every 10 waves and a score screen.
- Screenshots of a hazard wave, a checkpoint and a boss wave are in `tools/screenshots/`.
