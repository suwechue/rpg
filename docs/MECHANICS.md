# Project Vector: Mechanics Reference

Every mechanic in the game as it works **right now** (rewritten for CT, the Combat Tuning milestone, with PT Parts 1 and 2 adopted inside it, Oct 28, 2026), with the numbers and the file where each one is set. Use it to explain the game to playtesters, to nitpick, and to decide what to change.

- **Part A** is a one-page "how to play" for playtesters.
- **Part B** is the full combat reference.
- **Part C** covers everything outside combat.
- **Part D** lists what is changing next (PT, `docs/PATCH_1.md`, Parts 3 to 9).

**Claude Code keeps this file current:** whenever a mechanic, number or file changes, update the matching row here in the same commit.

Most numbers live in `data/` (JSON). The main files:

| File | What's in it |
| --- | --- |
| `data/stats.json` | Stat formulas and combat constants |
| `data/combat_rules.json` | Turn mode, difficulty, area falloff |
| `data/vectors.json` | Magnitudes, improvising, failures |
| `data/forms.json` | Spell shapes |
| `data/cards/*.json` | Cards |
| `data/classes.json` | Classes and starting decks |
| `data/enemies/*.json` | Enemies and bosses |
| `data/encounters.json` | Fight sizes and templates |
| `data/dungeon.json` | Floors |
| `data/arena/*.json` | The arena |
| `data/calendar.json` | Day parts and AP |
| `data/social.json` | Dialogue math |
| `data/leveling.json` | Levels, XP and class change |

---

# Part A: How to play (for playtesters)

**The big picture.** You're the new kid in town. Every day is split into parts (Before School, three class periods, Lunch, After School, Evening, Night). Each free part gives you a few **Action Points (AP)** to spend: talking to people, shopping, training, crafting spells. Walking is free. Every weekday **Evening** you're pulled into **the Upside-Down**, a dungeon you fight through. Friday night is a boss. If you die, the run is over (permadeath).

**Controls:**

| Key | Does |
| --- | --- |
| WASD or arrows | Move |
| E or Enter | Interact or confirm |
| Space | End the day part / end your turn in combat |
| Esc or right-click | Cancel |
| F1 | Debug menu |
| F5 / F9 | Save / load |
| F8 | Send feedback (once VD is built) |

**Combat in 30 seconds:**
- Fights are on a grid. Each of your characters takes a turn in **initiative order** (the bar at the top).
- Every turn you get **2 Actions** (a Move, a card, Strike or Guard) and **1 Quick** (a quick card or a backpack item). Move + card, card + move, card + card and move + move are all fine.
- Casters always have a **Cantrip** (0 MP, 1 Action) in their first Vector.
- You draw **back up to 3 cards** every turn; unplayed cards are discarded at End Turn unless you **Hold** one (1 Action).
- **Undo** anything until a die rolls or something new is revealed.
- Enemies **telegraph** right before their turn: red tiles and a dotted move arrow show where they'll go and hit. Step out of the red, hide behind cover, block their path, or kill or disable them first.
- Cards cost **MP**. MP barely refills during a night, so spend it carefully.
- Every spell has a **Vector** (element). Enemies are **weak** (x1.5 damage) or **strong** (x0.6) against certain Vectors.
- **Hover a card** to see its range, area and damage before you play it.

---

# Part B: Combat

## B1. Turns and actions

| Mechanic | How it works now | Change it in |
| --- | --- | --- |
| Turn order | Every unit acts once per **round** in **initiative** order (DEX + PER/2). Party and enemies interleave. In the **arena's first round of a wave, the whole party acts first**. A "Round N" banner starts each round; the timeline shows past turns faded, the current portrait enlarged, and the next round | `data/stats.json` derived.initiative; `data/combat_rules.json` actions.partyFirstInArena |
| Turn rule | **2 Actions + 1 Quick** (PT Part 1). An Action is a **Move** (up to your Movement: 3 + DEX/5, so 4 for most) or a **non-quick card**. Any order: move + card, card + move, card + card, move + move. Older rules (move-or-act and friends) stay in F1 > Fights | `data/combat_rules.json` turnMode, actions.actionsPerTurn |
| Quicks | **1 per turn**: a **quick card** or a **backpack item**. The built-in **Strike** (adjacent, STR) and **Guard** (+3 Defense, +15% Magic Resistance until your next turn) cost an **Action** (user request, Oct 28; `builtinsQuick` true brings back the old Quick rule). Usable before or after moving and after your Actions. Strike and Guard are not cards any more | actions.quicksPerTurn; `data/stats.json` combat.guardDefense |
| Cantrip | Everyone who knows a Vector has a built-in **0 MP, 1 Action** single-target Bolt in their first Vector (range 4, 3 to 4 damage, no riders) | `data/combat_rules.json` cantrip |
| Hold | **1 Action:** keep 1 card in hand for next turn (a pin on the card). Everything else is discarded at End Turn | actions.holdCost, holdMax |
| Undo | Until End Turn, undo any step that didn't roll dice (crit, miss, Stability), draw a card or reveal something. From that point back the Undo button greys out and says why. Snapshots live in `CombatState` | — |
| Action pips | Two Action pips and one Quick pip above the buttons. Hovering a card says whether it uses an Action or your Quick | — |
| Movement cards | Dash and other "+Movement" cards: with an Action left, the next Move this turn goes further; with none left, it carries over to next turn (a "Movement saved" chip). Never wasted. Hit and Run and Smoke Bomb give a **free move** that costs no Action | `data/stats.json` hasteMoveBonus |
| Opportunity strike | Standing on the tile an enemy's telegraph says it will move to blocks its plan. If it ends up next to you, you get a **free Strike** (doesn't use your Quick). Hovering your tile says "Blocks X's path" | `data/combat_rules.json` opportunityStrike |
| Selection | Idle → card selected (targets shown) → hover a target (preview) → confirm. Click the card again, right-click or Esc to cancel | — |
| Previews | Hovering a card or target shows range, area (in the Vector's color), damage, cover ("in cover: x0.5"), statuses, push landings, collisions, hazards, slides and whether it interrupts a telegraph | — |
| Whose turn | The active unit is in full color with a pulsing ring and a small bob; everyone else is dimmed and desaturated (HP bars, icons, telegraphs and cover icons stay bright). Units that already acted this round get a check mark. The banner shows the portrait and "Quill's turn: 2 enemies act next". The hand shows whose cards they are, each card with a border in that character's color. Sounds: turn_start_party, turn_start_enemy | `data/ui.json` spotlight, partyColors; `data/audio_events.json` |
| Clarity (PT Part 3) | **Party panel** (Party button in combat and the arena, pause menu): every member's sheet, hand, draw pile and discard. **Character sheet** stats explain themselves on hover. **Shields** show their number and a segment on the HP bar. **Duplicate enemies** are numbered (Wisp 1, Wisp 2) on their HP bars and telegraph tiles; each enemy's telegraph has its own tint, an outline around the whole shape, a line from the attacker, and a pulse when it appears. Hovering a red tile highlights its attacker; hovering an enemy lists every action (name, shape diagram, range, damage, riders), its passive, affixes, matchups and its plan in words. Units in front of the hovered tile fade to 30%; the threat view ghosts everyone. **Quick cards** have a green edge and a QUICK badge; Strike and Guard sit beside the hand. **Cards** show a mini shape diagram and name their shape ("Plus shape, range 4"). Area flashes linger 0.6 s; burning, toxic and glyph tiles show turn counters. **Pause** (P): Resume, Party, Options, and in the arena Save and Quit (restarts the current wave on Continue) or Abandon | `data/ui.json` areaFlashSeconds |
| Labels and focus (P2 Part 1) | Strike and Guard say QUICK only when the turn rule makes them Quicks (ACTION otherwise); the F1 turn-rule override shows an amber "F1 override" tag and is cleared on new run, the title and arena start. Mouse clicks don't leave a yellow focus outline (keyboard and controller still show it); the selected card or active mode has its own filled, glowing look | — |
| Card owners (P2 Part 1) | A card picked after an arena wave, or granted by an event, treasure or boss, asks whose deck it goes into: party members (lit if eligible; greyed with the reason if not), the bench, or "Collection only". Eligible: basic cards for anyone, class pool cards for that class line, spells for whoever knows every Vector. The arena pick can be undone until the next wave | `src/core/progression/crafting.gd` eligibility |
| Effects strip (P2 Part 2) | Icons on the left edge (combat, arena, dungeon, town) for everything active: arena mutators (waves to the checkpoint; red border if risky, green if helpful), difficulty, Easy minigames, the starting trait, injuries, Kelly's Risk, and the F1 override (amber). Hover for details; click for the **Effects page** (Party panel tab). Party members show perk badges in the timeline, the turn banner names their perks, perks float their name when they trigger, and mutator bonuses show in the hover breakdown ("+50% (Cold is stronger)", "+50% HP (Thick skin)") | `src/core/effects.gd` |
| Enemy turns | Played one beat at a time: banner, highlight, move, wind-up, hit, log line. Combat speed setting; hold a key to fast-forward | — |
| Fleeing | Allowed in non-boss fights (not boss floors). The room stays uncleared | fight setup fleeAllowed |
| Ranged Strike and Guard (user request) | On **Hard**, ranged characters (Mage, Healer, Bard and their advanced classes) pay an **Action** for the built-in Strike and Guard instead of their Quick; melee characters keep the Quick. Normal keeps the Quick for everyone | `data/combat_rules.json` difficulties.rangedBuiltinsCostAction; classes `ranged` |
| Combat difficulty | Chosen at new run. Enemies get **2 Actions** like you: move + attack, or move + move when nothing is in reach. **Double attack chance** (an enemy already in reach attacks twice): Normal minion 40%, normal 50%, elite 35%, boss 50%; Hard 75%. **Hard** also gives enemies x1.2 HP and x1.25 damage | `data/combat_rules.json` difficulties.enemyDoubleAttackChance |

## B2. Cards, hand and MP

- **The deck cycles in batches of 3:** each fight starts with a fresh shuffle. Every turn you're dealt up to 3 cards; unplayed ones go to the discard pile (except one Held card). Only when the draw pile is empty is the discard shuffled back in (with Fatigue). When fewer than 3 are left, you get those, then the rest from the reshuffle. The hand's label shows **Draw N · Discard N**.
- **Deck synergies** (arena cards from wave 10): Rummage (Quick: draw 1), Second Look (recall your last discard, draw 1), Seek the Spark (Quick: a spell of your first Vector from the draw pile), Recall (wave 15: your last 2 discards back to hand), Battle Plan (wave 15, Quick: hand +1 for 3 turns, draw 1), Overflow (wave 20: draw 3). `data/cards/synergy_cards.json`.
- **Items:** potions and effect items are consumable cards: once used they leave the deck for good. **Backpack** items (`run.backpack`, up to 6) can be used by anyone in combat with the Pack button (a Quick, on yourself). **Relics** are worn by one character (2 slots) and add mods; if that character goes down in a fight, every relic they wore is lost. `data/items.json`, `data/cards/item_cards.json`, `data/merchant.json`.

| Mechanic | How it works now | Change it in |
| --- | --- | --- |
| Deck | Each character has their own deck: **at least 8 cards, no maximum** (a huge deck means more reshuffles, and Fatigue). Max 3 copies of a design (0 = no limit). Crafted cards go **straight into the deck**. Adding cards is free; **removing one costs 1 AP** (1 Arena AP at checkpoints) | `data/leveling.json` deckMin, deckMaxBase (0 = none), maxCopies, removeCardCost; `data/arena/checkpoint.json` costs.removeCard |
| Deck editor | Shows count, cost curve, Vector mix and quick count, filters (All, Quick, each Vector) and the full card details on hover | — |
| Hand | **Opening hand 3**; at the start of each of your turns **draw back up to 3**. Unplayed cards go to the discard pile at End Turn, except one **held** card | `data/stats.json` combat.openingHand, drawUpTo, handLimit |
| Running out | When the deck is empty, the discard pile reshuffles and that character takes **Fatigue** damage (1, then +1 each reshuffle) | combat.fatigueStart, fatigueStep |
| Max MP | 4 + INT/2 + WIL/3 + class bonus, +0.5 per level. Roughly 8 to 12 at level 1 | `data/stats.json` derived.maxMp; classes mpBonus |
| MP regen | **1 per turn**. MP is **not** refilled between fights in a night, only by rest rooms, food and sleeping | derived.mpRegen |
| Spell cost | Magnitude cost (Minor 1, Standard 2, Major 4, Grand 7) + Form cost (0 to 3) + 1 if hybrid | `data/vectors.json` magnitudes; `data/forms.json` |
| Magnitude | Minor 4 power, Standard 7, Major 14, Grand 25. Capped by Knowledge Tier (Tier 1: Standard, Tier 2: Major, Tier 3: Grand). Force pushes 1 tile per 7 power | `data/vectors.json`; `data/stats.json` pushPowerPerStep |
| Card kinds | **Spell** (Vector + Form + Magnitude), **basic** (Lunge, Dash, Shove...), **item**. 194 card records plus generated spell designs, including 42 for the new Vectors (`data/cards/advanced_vector_cards.json`). Every class has a **class card pool** of 10 to 15 cards (`data/cards/class_<id>.json`, only that class draws them as rewards) and there are 14 status setup and payoff cards (`data/cards/synergy_cards.json`). New Form: **Cone** (1-3-5 tiles, range 3 from the caster, x0.7, cost 2), also used by enemies | `data/cards/*.json`; `data/forms.json` |
| Card text | Every card's text says when it applies: quick cards start with "Quick.", movement cards say "or next turn", once-per-fight cards say so. Short lines use the real power (`{power}`). A test checks this | `tests/suites/test_pt_turns.gd` |
| Rarity and upgrades | Common, uncommon, rare. Upgraded versions ("Ember Bolt+") via crafting and arena rewards | card rarity, upgrade |
| Can't play | Unaffordable cards, or ones needing a spent Action, are greyed out with the reason on hover | — |

## B3. Damage and defense

- **Difficulty targets** (user request, Oct 28): a well-played full party should win about 75% of fights on Normal and 40% on Hard. Measured with tools/sim_ar.gd (30 to 40 runs): Normal 77 to 78%, Hard about 50%.
  - Normal: enemies deal 2.5x damage. Hard: 5x damage, 1.3x HP, 90% chance to attack twice, and up to 3 extra copies of regular enemies per fight (not boss fights).
  - **Ramp** (user decision): week 1 and arena wave 1 use 1x damage, normal HP and no extra enemies; the numbers climb to the full values by week 3 and wave 15. `data/combat_rules.json` ramp.
- **Flanking** (user request, Oct 28): a hit on a target that has a hostile unit on the far side from the attacker deals +25% (+30% on Hard). Both teams can flank, and enemies look for flanking spots. **Isolated** (Hard): a party member with no ally next to them takes +20%. The combat log notes "flanked". `data/combat_rules.json` tactics, difficulties.hard.tactics.

| Mechanic | How it works now | Change it in |
| --- | --- | --- |
| Spell damage | Power x Form multiplier x (1 + Vector affinity bonus) x **matchup** x (1 − target Magic Resistance %) x other bonuses | `src/core/combat/resolver.gd` spell_damage |
| Strike damage | Stat x card multiplier (+ infusion), minus target **Physical Defense** (CON/2 + armor). Always at least 1 | resolver strike_damage |
| Magic Resistance | WIL/2 points x 2% each, max 60% | combat.magicResistPctPerPoint, maxMagicResistPct |
| Crit | Every hit rolls: **high crit** (x2.0) at 1% + DEX/10 %, otherwise **crit** (x1.5) at 5% + DEX/2 %, otherwise normal. Both on the character sheet; high crits get their own popup and sound | derived.critChancePct, highCritChancePct; combat.critMultiplier, highCritMultiplier |
| **Typing (matchups)** | Each enemy is **weak to** some Vectors (x1.5) and **strong against** others (x0.6); everything else is x1.0. Shown with icons on the enemy | enemy weakTo, strongAgainst; `data/matchups.json` |
| Back attack | Hitting a unit from behind (relative to its facing): x1.15, for everyone | combat.backMul |
| Flank (Backstab) | Rogue perk: x1.5 from behind or from a different row within 1 column | combat.flankMul |
| Cover | **Directional half cover** (CT Part 3). Crates (8 HP) and low walls (15 HP) are destructible props. A unit **next to** a cover piece takes **x0.5 from ranged and area** and **x0.75 from melee** when the attacker is mostly across the cover. Attacks from the side or behind (45 degrees or wider) **flank** and ignore it. Walls block line of sight entirely. Telegraphs use the attacker's planned spot, so hiding is a way to answer a telegraph. Force deals x2 to cover; Heat x2 to crates; pushing a unit into cover is a collision. A shield icon marks units in cover from the current attacker; tiles next to cover are outlined while moving. Every combat layout has 3 to 6 cover pieces | `data/stats.json` combat.cover; layouts ("c" low wall, "x" crate) |
| Friend nearby | +5% damage when standing next to a Friend-tier ally | combat.adjacentFriendDamagePct |
| Area falloff | Area attacks hit the first 2 targets in full, then x0.75 to each extra target | `data/combat_rules.json` areaFalloff |
| Enemy damage | Every damaging enemy action has one **damage** number (before Defense and Magic Resistance), times the week scale and the difficulty multiplier (Normal x1.0, Hard x1.25). Previews, telegraphs, the threat view and the hit all use the same number. Enemy HP x1.0 (bosses x2.0) | enemy action `"damage"`; combat_rules enemyHpMul, bossHpMul, difficulties |
| Kill-time targets | Week 1, Normal (measured by `tools/sim_balance.gd`): a minion dies to 1 player action, a normal enemy to 2 or 3, an elite to 5 to 7. One normal enemy hit takes 20 to 30% of a party member's HP, a heavy or charged hit 35 to 50%, a boss's big charged hit 60 to 80% | `data/combat_rules.json` balanceTargets |
| Downed | A party member at 0 HP is **downed**: a heart icon and a **bleed-out counter (2 rounds)**; any heal revives them. Not revived in time, or nobody in the party can heal: **Out** for this fight (banner, removed from the timeline). Down or out when the fight ends = **injured** (misses the next dungeon). Hazards and damage over time can finish anyone (outside the tutorial's training floor) | `data/stats.json` combat.bleedOutRounds; `data/leveling.json` injuryDays |
| Death | **The player** at 0 HP ends the run (permadeath) | — |
| Second Wind | Fighter perk: heal 20% once per fight below 30% HP | combat.secondWind* |

## B4. Spell shapes (Forms)

| Form | Footprint | Range | Damage x | Cost | Tier |
| --- | --- | --- | --- | --- | --- |
| Touch | 1 adjacent tile | 1 | 1.5 | 0 | 1 |
| Bolt | 1 tile, needs line of sight | 5 | 1.0 | 0 | 1 |
| Weapon Infusion | Your next 2 Strikes gain the Vector and +½ Magnitude | self | 1.0 | 0 | 1 |
| Projectile | First unit along a straight line (4 directions) | 7 | 1.0 | 1 | 1 |
| Shield | Ally absorbs Magnitude damage for 2 of their turns (Light/Vitality Shields also heal 80%) | 3 | — | 1 | 1 |
| Line | Every tile in a straight line (4 directions) | 4 | 0.8 | 1 | 1 |
| Burst | **Plus shape** at Minor/Standard; **3x3** at Major/Grand | 4 | 0.7 | 2 | 1 |
| Aura | Plus around you (Minor/Standard) or radius 1 (Major+); ticks at the start of your turns for 3 turns | self | 0.4/tick | 2 | 1 |
| Sphere | Diamond radius 1 (Minor/Standard) or 2 (Major+) around you | self | 0.7 | 2 | 2 |
| Construct | A sight-blocking barrier with HP = Magnitude, lasts 3 rounds | 3 | — | 3 | 2 |
| Glyph | A trap for 6 rounds; fires the spell on an opponent who steps on it | 4 | 1.2 | 3 | 2 |

Change these in `data/forms.json`, including the footprint per Magnitude. Range is counted in tiles (Manhattan). Damaging areas only hit opponents; heals only hit allies (no friendly fire).

## B5. Vectors (elements) on the grid

| Vector | Effect |
| --- | --- |
| Heat | Burns tiles for 2 rounds (3 damage on entering or starting a turn there); water becomes steam (blocks sight); melts ice |
| Cold | Slow (−1 Movement) for 1 turn; freezes water into ice. **Units on ice slide** until they hit something. Delays a charging enemy attack |
| Force | Push 1 tile per 10 Magnitude (min 1). Collisions deal 4 damage to both units. Pushing a charging enemy shifts its attack |
| Motion | Pulls enemies 1 tile; gives allies +2 Movement |
| Binding | Root (can't move) for 1 turn |
| Light | Blind (35% miss) for 1 turn; heals with Shield or Aura; **cancels a charging attack**; reveals darkness |
| Transmutation (Tier 3) | Clears hazards and water |
| Vitality (Tier 3) | Drains 50% of damage as healing |
| Corrosion (Tier 3) | Shreds 2 Defense and 4 Magic Resistance |

Change these in `data/vectors.json` gridEffects and `data/stats.json` combat (burnDamage, slowTurns, collisionDamage...).

**Hybrid cards** (two Vectors, +1 MP) apply both Vectors' effects. Named pair combos (Magma Ram and so on) come with VD (`docs/VECTORS_DEMO.md`).

**The Vector expansion (PT Part 8):**
- **Base Vectors** (Tier 1, learnable from the start): Force, Heat, Cold, Motion, Light, Binding.
- **Advanced Vectors** join the level-up learning pool once the parents' affinity shares are high enough and the Knowledge Tier allows: Gravity (Force 30%), Lightning (Heat 20% + Motion 20%), Sound (Motion 30%), Shadow (Light 30%), Warding (Binding 30%) at Tier 2; Transmutation, Vitality, Corrosion, Poison, Psychic, Cognition at Tier 3; Entropy, Void, Time at Tier 4 (gated: no Knowledge Tier 4 yet). Probability is data only. Thresholds are in `data/vectors.json` "advanced".
- **On the grid:** Gravity pulls hit units 1 tile toward the impact (and Crushes the Rooted, +50%). Lightning arcs to one more enemy within 2 (half damage) and keeps chaining through Wet and Conductive units. Sound Dazes, cancels charges, and deals x2 to walls. Shadow deals no damage: it darkens tiles for 2 rounds and makes allies there Shadowed. Warding shields allies (refreshes to the better value) or Exposes enemies. Poison stacks. Psychic does nothing to mindless enemies. Cognition Marks and reveals plans for 2 rounds. Void strips shields, buffs, affixes, hazards, constructs and glyphs. Time pushes an enemy's turn to the end of the round (never extra turns). Entropy adds +1 to the Instability target.
- **Force is free but weak:** Force cards cost 1 less MP (minimum 0) and deal x0.7.
- **Fusion:** a two-Vector card pays a surcharge by Magnitude (Minor +1, Standard +1, Major +2, Grand +3; three Vectors pay it twice). **Synergistic pairs** (Heat+Motion, Cold+Binding, Light+Sound, Force+Gravity, Corrosion+Vitality, Lightning+Motion, Psychic+Sound, Warding+Vitality, Shadow+Binding, Void+Transmutation, Poison+Corrosion, Cognition+Light) halve it (rounded up) and resonate (+15% effect). **Antagonistic pairs** (Heat+Cold, Binding+Motion, Vitality+Entropy, Light+Corrosion, Lightning+Corrosion, Psychic+Binding, Warding+Entropy, Shadow+Light, Time+Entropy, Void+Warding, Cognition+Binding) add +1 MP. Damage is split between the Vectors, each checking its own matchup.
- **Instability by Magnitude:** a cast rolls when its final MP cost reaches the threshold (Minor never, Standard 4, Major 6, Grand 9); improvised casts always roll. Target 10 + (cost - threshold) / 2, +1 Entropy, +2 per antagonistic pair, -1 per synergistic pair, never below 10; roll d20 + Stability / 2. **Failures:** Reduced (half effect), Misfire (random valid target), Backlash (you take damage equal to the MP cost; it still resolves), Strain (that Magnitude can't be cast next turn), Wild Surge (resolves as a random Vector), Collapse (nothing; MP lost).

## B6. Improvising (the Vector Wheel)

- Build any legal spell on the spot from the Vectors and Forms you know.
- **Cost:** ceil(normal cost x 1.5) + 1 MP, and you **discard 1 card** as fuel.
- **Instability roll:** improvised casts always roll; prepared cards roll only when spending more than half your current MP. You succeed if d20 + Stability/2 reaches 10 + 10 x (cost ÷ current MP), with +3 for improvised. Stability = WIL + INT/2. The success chance is shown before you cast.
- **Failures** (weighted random): Fizzle 4 (MP spent, nothing happens), Backlash 3 (half damage to yourself), Misfire 2 (hits a random valid target), Wild Surge 1 (a random Vector from all 9, same target).
- Mage perk **Overchannel:** your first improvise each fight costs the normal amount.

Change these in `data/vectors.json` improvise and failures; `src/core/combat/resolver.gd` instability_target.

## B7. Telegraphs (enemy intents)

| Mechanic | How it works now |
| --- | --- |
| When | **Just in time** (CT Part 2): an enemy reveals its plan at the start of the **last party turn before its own**. Enemies that act back-to-back all reveal on the same party turn. On its turn it carries the plan out at once. An enemy that acts before any party turn in a fight only moves |
| The plan | Both Actions are shown: a **dotted move arrow** to where it will stand, and the **red tiles** it will hit from there (both hits counted when it attacks twice) |
| Last chance | The timeline draws a small red link after the party turn that is the last chance before enemies act, and the banner says "Kelly's turn: 2 enemies act next" |
| Intent icons | Attack, special, buff, defend, move, tracking, over the enemy's head |
| Locked tiles | The default. The attack hits **whoever stands there** when it resolves, including other enemies. Dodge by leaving the red, or hide behind cover |
| Blocking | If its planned tile is taken or it's rooted, it gets as close as it can and re-aims at the same target if still in reach, otherwise it **loses the attack**. A party member standing on the planned tile gets an opportunity strike |
| Tracking | Rare (3 enemies, marked in data): the attack follows its target and can't be dodged by moving, so it deals **60%** of a locked attack. Guard, cover, getting out of reach, and an **Afterimage decoy** (it takes the next tracking hit aimed at its caster) are the answers. The party AI knows moving doesn't dodge these |
| Charge-ups | Big attacks charge for a turn first, with a stronger pulse. Bosses use patterns (cross, ring, rows, checkerboard, line) |
| Interrupts | Light cancels a charge, Cold delays it, killing the enemy cancels it. **Blind never removes a telegraph**: it adds a 35% miss chance, shown on the telegraph. **Taunt** makes every enemy in range that can reach the taunter re-plan at it, at once. **Pushed before acting:** areas centered on the enemy move with it; attacks aimed at a tile still happen if it's still in range and sight, otherwise they're skipped ("Off balance!") |
| Overlaps | Tiles hit by several telegraphs show combined damage. Hold the threat key for the **threat view** (every tile shaded by incoming damage). Enemies planning in a row stagger their targets and avoid each other's red tiles |
| Damage | The telegraph shows the attack's real damage (from the enemy's planned spot, so cover counts) |

Change these in `src/core/combat/enemy_ai.gd`, `data/ai.json` and enemy action data.

## B8. Statuses

| Status | Effect | Lasts |
| --- | --- | --- |
| Burn | 3 damage on entering a burning tile or starting a turn on one | 2 rounds on the tile |
| Slow | −1 Movement | 1 turn |
| Root | No movement | 1 turn |
| Blind | 35% miss chance | 1 turn |
| Haste | Extra Movement | 1 turn |
| Rally | Damage bonus | 1 turn |
| Guard | +3 Defense, +15% Magic Resistance | Until your next turn |
| Shield | Absorbs damage | 2 of the target's turns |
| Decoy | Draws enemy attacks | Varies |
| Taunt (Beacon) | Enemies retarget to the caster | Varies |

**Setups and payoffs (PT Part 7):**

| Status | Comes from | Payoff | Lasts |
| --- | --- | --- | --- |
| Wet | Splash, Deluge, Soothing Rain, sprinklers, puddles; Heat melting a Frozen unit | Cold on a Wet unit **Freezes** it; Lightning arcs through it (PT Part 8) | 2 turns |
| Frozen | Cold on Wet, Freeze cards | Rooted; **Force or Sound shatters it for x1.5** | 1 turn |
| Burning (status) | Heat hits | 3 damage at the start of each turn; **Force or Motion spreads it** to the tiles around | 2 turns |
| Rooted | Binding | Gravity's **Crush** deals +50% (PT Part 8) | 1 turn |
| Poisoned | Poison (PT Part 8), Garrote | 2 damage per stack each turn (stacks to 5, duration doesn't refresh); **Corrosion doubles the stacks**; healing on it is halved | 3 turns |
| Marked | Light marks (Lantern Mark, Spotlight, Flare Mark), Cognition (PT Part 8) | All damage to it +25% | 1 round |
| Dazed | Discord, the Daze rider, Sound | Loses its Quick; 20% miss chance | 1 turn |
| Exposed | Corrosion, Crushing Blow, warding (PT Part 8) | No Magic Resistance; x1.25 from its weaknesses | 1 turn |
| Shadowed | Vanish, Smoke Pellet, Shadow (PT Part 8) | Can't be targeted from more than 2 tiles away; its attacks count as flanking (ignore cover) | 1 round |
| Conductive | Lightning, metal props (PT Part 8) | Lightning jumps to and from it | 2 turns |

Every card lists what it **sets up** and **pays off** ("Sets up: Wet. Pays off: Frozen."), shown in its text and used by the deck editor's filters and the arena's card offers.

Statuses last through the unit's next turn unless listed. Change them in `data/stats.json` combat, statusRules and synergyTags, and `data/ui.json` (names and icons).

## B9. Terrain and hazards

| Letter | Terrain | Effect |
| --- | --- | --- |
| `.` | Floor | — |
| `#` | Wall | Blocks movement and line of sight. **Breakable:** 25 HP; Strike can hit it; Force, Corrosion and Heavy Swing deal x2. Breaks into rubble |
| `B` | Boundary | An unbreakable wall (arena edges) |
| `r` | Rubble | Floor that gives half cover to units next to it |
| `c` | Low wall | A cover prop (12 HP). **Climb** over it into the free tile beyond for 1 Action; breaks into rubble |
| `h` | Hazard | 4 damage on entry |
| `w` | Water | Impassable until frozen |
| `i` | Ice | Slide until you hit something |
| `x` | Crate | Cover prop (8 HP), Heat burns it |

Lunge and other lunge cards pass **over** hazards and gaps without triggering them (not through walls or units); only the landing tile counts.

**Arena hazards:**

| Letter | Hazard |
| --- | --- |
| `f` | Fire |
| `p` | Pits (enemies are knocked out; players take heavy damage) |
| `g` | Glyph traps |
| `k` | Collapsing floor (falls after being stood on twice) |
| `R` | Conveyor rows (move units 1 tile at round end) |
| `d` | Darkness (only Light reveals) |
| `t` | Toxic puddles |

Change layouts in `data/rooms/combat_layouts.json` and `data/arena/layouts.json`.

## B10. Classes in combat (starting kits)

Strike and Guard are built-in Quicks for everyone, so no deck carries them (PT Part 1). Every deck is 8 to 10 cards (CT Part 5).

| Class (arena name) | Role | How it plays | Starting deck | Perk |
| --- | --- | --- | --- | --- |
| Mage (Ash) | Area and control, glass cannon | Shapes the field with areas and pushes; fragile, so cover matters most | 2+2 Standard Bolts (two Vectors), Minor Burst, Minor Line, Minor Shield, Blink (a Quick), Shove | Overchannel |
| Fighter (Brick) | Front line: holds space and soaks | Stands in enemy paths (opportunity strikes), takes hits for allies, breaks cover | **Intercept**, 2 Heavy Swing, Shoulder Shove, 2 Lunge, Brace, Parry, Taunt, Standard Weapon Infusion | Second Wind |
| Rogue (**Quill**) | Skirmisher and assassin: moves **and** hits | Attacks carry movement; flanking ignores cover and triggers Backstab | 2 **Hit and Run** (strike, then a free move 2), **Shadow Step** (teleport behind and strike), 2 Quick Stab (quick), Lunge, Throw, **Smoke Bomb** (blind adjacent, free move 1), Dash, 1 Bolt | Backstab |
| Healer (**Sage**) | Protector: stops damage before it lands, then heals | Reads telegraphs: shields the target, pulls allies out of the red, makes a safe zone | 2 **Ward** (shield 8, doubled against a telegraph), 2 Mend (heal 14), **Guiding Light** (pull an ally 3), **Sanctuary** (telegraphed hits x0.5 nearby), Beacon (taunt), 2 Sunbeam, **Cleanse** (quick) | Triage |
| Bard (Lyric) | Tempo: makes allies' turns better | Haste (+2 tiles per Move next turn), Tailwind, blinds, Rally, and **Encore** (an ally who already acted takes another turn now with 1 Action at half effect, once per fight) | Haste, Tailwind, 2 Dazzle, Rally, **Encore**, 3 Standard Bolts | Hype |

Change these in `data/classes.json` starterDeck, `data/cards/class_cards.json` and `src/core/arena/arena_party.gd` (arena names).

Advanced classes (Class Change at levels 5 and 12): Elementalist, Kinetic Logician, Spellblade, Guardian, Trickster, Medic, Idol, Deli Knight, Smith-Mage, Upside-Touched. Each has its own perk and keeps the base class deck.

## B11. Enemies

| Mechanic | How it works now | Change it in |
| --- | --- | --- |
| Stats | HP, Movement, initiative, Defense, Magic Resistance, weak/strong Vectors, actions with an explicit damage number (heals and shields use power), a disposition | `data/enemies/week1..5.json` |
| AI | Scores actions by expected value x how well they suit its personality, picks with some randomness. Surrounds, staggers telegraphs, protects healers, focuses wounded or isolated targets, avoids its own allies' telegraphs | `data/ai.json`, `src/core/combat/enemy_ai.gd` |
| Behaviors (12) | Charger, Bomber, Healer, Summoner, Shield bearer, Burrower, Sniper, Splitter, Hazard maker, Mirror, Leech, Anchor | enemy behavior |
| Elite affixes | Hasted, Armored, Burning, Vampiric, Shielded, Explosive (icons over the enemy) | `data/enemy_affixes.json` |
| Minions | Weak, often one-hit; count as half an enemy | `data/encounters.json` minionWeight |
| Encounters | Built from templates: Pack, Front and back, Swarm, Healer core, Ambush, Reinforcements, Summoner nest, Hazard lords, Elite escort. Count per week (raised for 2 Actions): 4–5, 5–6, 5–7, 6–7, 6–8 (elite rooms 4, 4–5, 5, 5–6, 6; elites get 1 affix). Smaller parties face fewer, weaker enemies | `data/encounters.json` |
| Bosses | 5 (Hollow Mascot, Cold Cut, Forge Revenant, Night Ward, Mirror Town), with phases, adds and reinforcements from week 3 | `data/enemies/bosses.json` |

**Variety (PT Part 7):** every normal and elite enemy has **2 to 4 actions** with different shapes (single, line, cone, burst, ring, cross, charge, buff), some leaving statuses on whoever they hit (Wet, Marked, Exposed). 14 new base-Vector enemies (`data/enemies/patch_enemies.json`): Puddle Imp, Frost Fang, Ember Tick, Root Weaver, Spotlight Drone, Acid Drip, Gym Rope, Locker Leaper, Fire Alarm, Mop Golem (elite), Hall Monitor, Rust Bucket, Cinder Swarm, Frost Chorister (elite), palette swaps until there's art. Every elite has a **signature mechanic** by its Vector (Firebrand leaves fire, Permafrost makes you Wet, Juggernaut can't be pushed, Blur moves and attacks, Glare marks, Anchor roots, Rot exposes, Leech heals). Each boss has a new status attack (Foam Flood, Deep Freeze, Slag Spray, Sedative Mist, Spotlight Glare). The new Vectors' enemy families and combo encounter templates come with PT Part 8.

**New Vectors' families (PT Part 8):** Static Imp (Lightning, chains through Wet), Hush Moth (Sound, scream Dazes), Gloom (Shadow), Sludge Slug (Poison, toxic trail), Grav Rock (Gravity), Ward Totem (shields allies; break it first), Mask of Whispers (Psychic), Echo (Cognition, copies your last card), Rust Hound (Corrosion), Entropic Wisp (Entropy, blows itself up). Slimes, golems and totems are **mindless** (Psychic does nothing to them). **Combo encounters:** Storm front (a Wet maker with Static Imps), Toxic garden (slugs and a healer), Gravity trap (a Grav Rock with fast enemies); template slots can name an enemy id.

## B12. The Endless Arena

- **Bosses every 5th wave** (elites every 4th), each with a **gimmick** announced before the wave: Thorned Hide (hits hurt the attacker for 3), Rising Fury (+15% damage per round), Regrowing Shell (shield of 10% HP each turn), Calls the Pack (2 minions every 2 rounds), Last Stand (a 35% HP shield at half HP), Too Fast (hasted). `data/arena/gimmicks.json`.
- **The loop:** after wave 50 the arena starts over (weeks, themes, bosses, gimmicks) with everything 1.25x stronger per loop. `data/arena/waves.json` loopAt, loopMul.
- **The merchant** at checkpoints sells relics, backpack potions and deck items for arena coins (the banked money): 5 goods per checkpoint, weighted by rarity. A cutscene introduces her the first time.
- **Card picks** only offer cards at least one party member can put in their deck.

- **Two ways in:** from the title screen (a preset party: your class plus one of each other class, named Ash, Brick, Quill, Sage and Lyric), or in the story through **the Rift** (week 2+). In the story, losing knocks you out instead of killing you.
- **Waves:**
  - Seeded, endless and growing.
  - Every wave has a new layout and a **hazard set**.
  - Every 5th wave is elite.
  - Every 10th wave is a remixed boss.
- **Checkpoints, every 5 waves:** 3 Arena AP (unspent AP carries over).

  | Action | AP |
  | --- | --- |
  | Swap a card | 1 |
  | Craft | 2 |
  | Swap a teammate | 2 |
  | Equipment | 1 |
  | Rest (50% HP and MP) | 2 |
  | Reroll mutators | 1 |

  Then pick 1 of 3 **mutators** (risk and reward until the next checkpoint).
- **Score:** waves cleared plus bonuses, with a best-score table.

Change these in `data/arena/*.json`.

---

# Part C: Everything outside combat

**Themes in blocks of 5 waves (user request, Oct 28):** waves 1 to 5, 6 to 10 and so on each share one theme: its hazard set and an enemy lean toward its Vectors (Fire Drill, Cold Snap, Pitfall, Trench War, Rune Maze, Cave-In, Assembly Line, Lights Out, Toxic Spill). Themes are seeded per run and never repeat back to back. The checkpoint shows the next block's theme, so you can rebuild decks for it. Change them in `data/arena/waves.json` themes.

**Progression (PT Part 6):**
- After **every wave**: pick 1 of 3 cards (or skip for 2 Scraps). Offers lean toward the party's Vectors (x3), get rarer as waves go up (common 6 / uncommon 3 / rare 1 early, 2 / 4 / 4 by wave 20), and 20% of the time include a Vector nobody in the party knows.
- **Every checkpoint (5 waves)**: one party member picks 1 of 2 class perks (Techniques once PT Part 8 lands), plus Arena AP for rest, deck edits (removing a card costs 1), crafting, the Card Forge, teammates and equipment, and the mutator choice.
- **The first round of every wave**: the whole party acts before any enemy.
- **Pause** (P): Save and Quit restarts the current wave on Continue.
- **Score screen**: waves, score, best runs, cards picked, perks taken and the highest single hit.

Change these in `data/arena/waves.json` cardReward and checkpointPick.

## C1. Days, time and AP

| Day part | AP |
| --- | --- |
| Before School | 2 |
| Period 1 | Class (whole part) |
| Period 2 | Class (whole part) |
| Lunch | 2 |
| Period 3 | Class (whole part) |
| After School | 3 |
| Evening | **The Upside-Down** (Mon to Fri) |
| Night | 1 |
| Weekend parts (Morning, Midday, Afternoon, Evening) | 3 each; no dungeon |

- Walking, reading signs and short greetings are free. Leftover AP is lost when the part ends. Space ends a part early.

  | Action | AP |
  | --- | --- |
  | A dialogue topic | 1 |
  | A gift | 1 |
  | Hanging out | 2 |
  | Asking someone to join | 1 |
  | A shop visit | 1 |
  | Training at a location | 1 to 2 |
  | Crafting at the workbench | 1 at Night, 2 elsewhere |

- **Sleep** fully restores HP and MP. HP lost in class accidents carries into that evening.
- **Injured** party members miss the next evening's dungeon.

Change these in `data/calendar.json`, `data/social.json` and the locations data.

## C2. School

- You set a **weekly schedule:** one class per period, from 9 classes (PE, Physics, Chemistry, Earth Science, Shop, Drama, Debate, Biology, History).
- **Attending** plays a class event (lesson, pop quiz, partner work, disruption, accident or professor spotlight; 64 events) and gives **training bars** to that class's stats. A stat point costs 3 bars below 7, 4 from 7, and 5 from 13. Repeating a class the same day gives half. Attending also nudges your Vector affinity toward the subject.
- **Grade** with each professor: +3 per attendance, −5 per skip (0 to 100). Spotlight events need Grade 25 to 40.
- **Skipping** frees the period. Three skips in a week means **detention** (a Mr. B scene, and you lose the next After School).

Change these in `data/school_classes.json`, `data/events/class_events.json`, `data/stats.json` training and `data/events/detention.json`.

## C3. Stats and leveling


**Point buy at run start (PT Part 9):** every stat starts at **3**; spend **20 points** (1 per point up to 8, 2 per point for 9 and 10; nothing above 10). The class adds a small bonus on top (Mage +1 INT +1 WIL, Fighter +1 STR +1 CON, Rogue +1 DEX +1 PER, Healer +1 WIL +1 CON, Bard +1 CHA +1 DEX). The screen shows each stat's job and the derived values live, with **Recommended** and **Random** buttons. Story runs get it after picking a class; arena runs offer "Use recommended for all" or point buy for each member. NPCs keep their class starting stats. Change it in `data/point_buy.json`.
- **Stats:** STR, DEX, CON, INT, PER, WIL, CHA (1 to 20).
- **Derived values:**

  | Value | Formula |
  | --- | --- |
  | HP | 20 + CON x4 + class bonus + per-level growth |
  | MP | See B2 |
  | Movement | 3 + DEX/5 |
  | Initiative | DEX + PER/2 |
  | Physical Defense | CON/2 |
  | Magic Resistance | WIL/2 |
  | Stability | WIL + INT/2 |
  | Crit | 5% + DEX/2 % |

- **XP:** 45 x level to reach the next level (max level 20).
- **Each level:**
  - 3 stat points rolled from the class's growth weights;
  - a Vector learning roll;
  - a Form roll on even levels;
  - **pity** after 3 dry rolls.
- **Perks** at levels 3, 6 and 9 (pick 1 of 2). **Class Change** at levels 5 and 12.
- **Knowledge Tier:** Tier 2 at level 5 with INT 8; Tier 3 at level 10 with INT 12. It caps Magnitude and which new Vectors and Forms you can learn.

Change these in `data/leveling.json`, `data/stats.json` and `data/classes.json`.

**Techniques (PT Part 8, replacing the level 3, 6 and 9 perk picks):** picks at levels **2, 3, 6, 10, 14 and 18** from a shared pool of 24 in four categories (Forging, Alchemy, Kinetics, Meditation); each has a tier (minimum level 2, 3, 6, 10, 14, 18). Every class can take any category, but each starts with one (Mage Still Mind, Fighter Runic Toolkit, Rogue Vector Redirection, Healer Meditative Reserve, Bard Still Mind) and its leaning categories are listed first. **Reconfigure** one Technique at the night workbench (1 AP) or an arena checkpoint (1 Arena AP); arena checkpoints also offer one Technique pick per visit.

| Technique | Active now | Effect |
| --- | --- | --- |
| Runic Toolkit | Yes | Learn Construct; Constructs +50% HP |
| Efficient Forging, Lasting Rune | Lasting Rune yes | Constructs and Glyphs last +2 rounds (the cost cut is data, not wired yet) |
| Vector Redirection, Perfect Counter | Yes | Reaction, 2 MP (0 with Perfect Counter): a single-target attack on you goes to another enemy within 3 |
| Reactive Casting | Data | Cantrip at enemies stepping next to you |
| Conversion Reflex | Yes | Reaction, 1 MP: a known Vector's damage is reduced by INT/2 + level/2 |
| Mid-Flight Correction | Yes | Your ranged attacks ignore half cover |
| Living Equation | Yes | Your Quick can be your Cantrip |
| Still Mind, Resilient Mind | Yes | Instability rolls twice (first roll each fight / every roll), keep the best |
| Meditative Reserve | Yes | +3 MP at rest rooms and arena checkpoints |
| Internal Casting | Yes | Hazards don't hurt you on your own turn while you have 1+ MP |
| One With the Formula | Yes | Instability thresholds +3 |
| Modular Imbuement, Overcharged Construct, Living Foundry, all Alchemy, Deep Calculation | Planned | Listed greyed out until potions, acting constructs and once-per-night actions exist |

Reactions use Options "reactions" (auto by default; "ask" acts like auto until the prompt is built; never). **Advanced classes** added: **Alchemist** (from Mage or Healer; needs Stored Formula) and **Runesmith** (from Mage or Fighter; needs Runic Toolkit); Smith-Mage is now the hidden upgraded Runesmith. Change them in `data/techniques.json` and `data/classes.json`.

## C4. Crafting cards

- At the workbench, choose Vectors, Form and Magnitude, then play the crafting **minigame** for that Vector type:
  - Thermal: hold to heat and stay in the band.
  - Precision: a timing bar.
  - Alignment: lock spinning rings.
  - Chemical: an arrow sequence.
- Property gates (the Vector strength a Property needs) are on the same scale as spell power (lowered x0.7 with the CT power change).
- **Performance** sets how many **Properties** (bonuses from a bank of 15) the card rolls: below 0.35 gives none, below 0.8 gives one, otherwise two. A score of 0.95+ adds a Magnitude step.
- The card collection is shared. Each deck can use up to the copies you own (max 3).

- Minigame timing windows and time limits are **x1.5** (PT Part 5); the **Easy** minigame setting (pause > Options) multiplies them by 1.5 again.
- Crafted cards go straight into the crafter's deck.

**The Card Forge** (PT Part 5, at the workbench and arena checkpoints; each action costs 1 AP or 1 Arena AP):
- **Fuse** two cards: an **element** (Weapon Infusion or a one-Vector spell) with a **technique** (Lunge, Strike-type cards, Throw, Shove, Dash) makes the technique carry that Vector (Frost Bolt + Lunge = Cold Lunge, which applies Cold's effect on the hit). Two spells make a **hybrid** with a combo name where one exists (Heat + Cold = Thermal Shock). Cost = the higher cost + 1. Both sources are used up.
- **Salvage** a card for **Scraps**: 2 of each of its Vectors, plus 1/2/4 generic by rarity.
- **Upgrade** with Scraps (3/5/8 generic by rarity + 1 per Vector): named cards become their "+" version, spell designs go up one Magnitude.
- **Riders** cost Scraps (1st at its listed cost, 2nd +1, 3rd +2) and raise the card's MP cost. Slots: 1 common, 2 uncommon, 3 rare. Widen and Twin can't share a card; Twin is single-target only.

| Rider | Effect | MP |
| --- | --- | --- |
| Slow | Target -2 Movement next turn | +1 |
| Push/Pull | Move the target 1 tile | +1 |
| Daze | Target loses its Quick and has -20% hit chance next turn | +1 |
| Lingering | Target takes 30% of the hit again at the start of its next turn | +1 |
| Weaken | Target deals -25% damage next turn | +1 |
| Widen | Plus becomes 3x3, a Line gets +2 | +2 |
| Twin | Also hits a second target within 2 tiles | +2 |
| Extended | Burn, auras and glyphs last 1 round longer | +1 |

Change these in `data/minigames.json`, `data/properties.json`, `data/forge.json`, `data/riders.json`, `src/core/progression/crafting.gd` and `src/core/progression/forge.gd`.

## C5. Talking, Bonds and recruiting

- **Topics** cost 1 AP; each can be used once a week (some once ever). Some are locked behind **CHA** or a Bond level.
- **Reception:** how well your line's tone matches the person's personality, plus their mood today (good +0.15, bad −0.15), plus Bond/400. A score of 0.2+ is good, −0.05 or below is bad. Bond changes by score x10 (risky lines can earn up to x1.45 when they land).
- **Misheard:** every line has a risk (5% safe, 20% jokes, 30% bold), reduced by CHA. The screen shows "you meant / they heard", and the misheard version's tone is used.
- **Gifts:** liked tags +5 each (max 15), disliked −5, otherwise +2.
- **Hanging out:** 2 AP at Acquaintance or better, +6 to +12 Bond.
- **Bond tiers:**

  | Tier | Bond |
  | --- | --- |
  | Enemy | −100 to −51 |
  | Rival | −50 to −11 |
  | Stranger | −10 to 10 |
  | Acquaintance | 11 to 40 |
  | Friend | 41 to 70 (can recruit) |
  | Close | 71 to 85 (combos) |
  | Unbreakable | 86+ |

  Bonds drift toward 0 each week (5%).
- **Recruiting waves:**
  - the Core Four from week 1;
  - Sam, Baxter and Jon from week 2;
  - Kris, Diane and Penny from week 3 (Jake after his forge questline, Phase after 3 deli shifts);
  - Mel from week 4.

  **Kelly** needs Bond 60 and a kind first night. Up to **3 companions** each night.

Change these in `data/social.json`, `data/bonds.json` and `data/npcs/*.json`.

## C6. The town

- **Four zones:** school, downtown, residential (Hillside, Elm Street, Maple Street) and outskirts. There are 72 locations, each marked **open**, **exterior** (door only), **closed** or **story**.
- Every named character has a home and a schedule. Doorstep talks happen at exterior homes.
- **Shops** (deli, forge, hospital, corner store): price = base x (1 + keeper Greed/200) x (1 − (CHA − 5) x 0.02). New gear auto-equips.
- **Bus stops** for fast travel from week 2.

Change these in `data/town/*.json` and `docs/TOWN.md`.

## C7. The Upside-Down (story dungeon)

- **Leaving early:** the exit is open whenever the boss room (if the floor has one) is beaten; other fights are optional (user request, Oct 28; `data/dungeon.json` sealExitUntilCleared).

- **Each week** has a **Vector signature**, shaped by town events, that decides which enemies and loot appear.
- **Floors:**
  - Monday to Thursday floors are generated rooms: combat, elite, treasure, rest, event, merchant and exit.
  - Friday is the **boss floor:** returning encounters (ones you fled from come first), a rest room, then the boss.
- You walk in through the woods edge and choose your party.
- **The exit is sealed** until every combat, elite and boss room on the floor is won (CT Part 6). The HUD shows "fights left N" and the exit says "Sealed (N fights left)". Fleeing leaves the room uncleared: go back and win it. Treasure, rest, event and merchant rooms are optional.
- **Monday evening of week 1 is the combat tutorial floor** (CT Part 7, `data/story/tutorial_floor.json`): 10 small rooms with Kelly as a guest, one lesson each, taught with the 2-Action rules:
  1. First Contact: turn order, 2 Actions, Strike as a Quick.
  2. The Red Tiles: telegraphs and dodging.
  3. Brace Yourself: Guard and tracking attacks.
  4. Cards on the Table: the hand of 3, MP, hover previews, range, area and Hold.
  5. Weak Spots: matchups.
  6. Walls and Cover: line of sight, cover and flanking.
  7. A rest room (campfire, chest), then Hot Floor: hazards, pushes and friendly fire. Taking the shortcut skips Hot Floor.
  8. Quick Thinking: quick cards, Dash and interrupts.
  9. Off the Script: the Vector Wheel, with the first improvise guaranteed.
  10. The Whole Mess: priorities and the threat view.

  How the floor plays:
  - The hand is greyed out until room 4, the Wheel until room 9 and the threat view until room 10.
  - There are no crits until room 9.
  - A training HP floor means the party can't drop below 1 HP.
  - Lessons wait for what they teach (moving, dodging, striking, guarding, hovering, playing, holding, improvising) and give a hint after 20 seconds stuck.
  - The Kelly Risk choices are unchanged: the lantern, the shortcut, the help call (room 8) and the panic moment.
  - Once the floor is cleared in any run, later runs offer "Skip the lessons": the fights stay and the prompts go.

Change these in `data/dungeon.json`, `data/weeks.json` and `data/encounters.json`.

## C8. Story, death and the Journal

- **Place-based events:** a story with `"at": { "zone" }` or `{ "loc" }` waits until you're in that zone or within 4 tiles of that location's door or spot, any time from its day part to the end of that day (the banner at the front steps, the deli freezer, the forge, the closed wing, Mr. B at school). Others still play when their day part starts.

- **Week 1 Monday:** Kelly is your guest on the first floor. Your choices that day add to **Kelly Risk**. At 4 or more, she panics and the run ends.
- **Story arc:** Mr. B's arc runs through weeks 1 to 5, with choices in weeks 3 and 4. The run ends at the `NARRATOR_REVEAL_TBD` finale.
- **Death:** a run summary, then the **Narrator's Journal** keeps lore, creatures, endings, best week and trait unlocks across runs.

Change these in `data/story/*.json`, `data/journal.json` and `data/endings.json`.

- **Cutscenes:** `data/cutscenes/*.json` (see docs/CUTSCENE_GUIDE.md). A new run opens on moving day, then creation (with a name), then the first night. Week 1 Monday plays a short beat each day part; the Kelly floor opens and closes with cutscenes; the Hollow Mascot has intro and phase 2 scenes. Later runs can skip the tutorial day. Skip with Esc (choices take their first option; effects still apply), hold E to fast-forward. Each cutscene sets the flag `cutscene_seen_<id>`.
- **Arena cutscenes:** the first visit, the first boss wave, a new best score; each 5-wave theme gets a Narrator banner.

---

## B13. Vector combos and your spark

- **Combos:** every pair of Heat, Cold, Force, Motion, Binding and Light is a named combo (15), plus three-Vector combos (Shatterstorm, Starfall Lance, Crystal Prison). A party spell whose top Vectors match (each at least 20% of the strongest) runs the combo's effects after its damage. This covers crafted hybrids and improvised casts. Cards with their own authored effects keep those. Three-Vector spells already cost more through the fusion surcharge.
- **Discovery:** the first cast or craft of a combo shows its name, effect and a narrator line. The run and the Narrator's Journal remember it, and the **Vector Compendium** (Party panel or workbench) shows found combos, with "???" and a hint for the rest.
- **Your spark:** at the start of a story run, the narrator asks 6 questions. Answers add Vector weights, and the strongest is your spark. It adds +3 to that Vector's affinity, makes it known, adds a Standard Bolt of it to your deck and gives a trait: Runs Warm (+1 damage on Heat cards), Cool Head (+1 WIL), Heavy Hands (+1 damage on Force cards), Restless (+1 Initiative), Keeps Promises (+1 CON) or Bright Idea (+1 PER). After the first quiz, later runs can pick a spark directly.
- **Crafting:** the workbench builder shows a live card preview, its footprint and its combo ("???" until discovered). After the minigame you get a grade (S 95%+, A 80%+, B 60%+, C 40%+, else D) and the card flips in. The deck editor sorts by Vector, then cost, and badges combos.

Change these in `data/combos.json`, `data/sparks.json`, `data/intro/spark_quiz.json` and `data/traits.json`.

---

# Part D: Changing next

PT (`docs/PATCH_1.md`), P2 Parts 1 to 3 (`docs/PATCH_2.md`, with cutscenes M14 and the intro M15) and VD (combos, the spark, the card builder, the demo and feedback) are in. Demo mode (`data/demo.json`) ends a story run after the week 1 boss. Next:
