# Project Vector: Mechanics Reference

Every mechanic in the game as it works **right now** (written from the code at commit `d51771d`, after the Arena milestone, Oct 25, 2026), with the numbers and the file where each one is set. Use it to explain the game to playtesters, to nitpick, and to decide what to change.

- **Part A** is a one-page "how to play" for playtesters.
- **Part B** is the full combat reference.
- **Part C** covers everything outside combat.
- **Part D** lists what the Combat Tuning milestone (CT, `docs/COMBAT_TUNING.md`) is about to change.

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
- On a turn you **either move or act** (play a card, Strike or Guard), not both. You can also play **one quick card**.
- Enemies **telegraph**: red tiles show where they'll hit next. Step out of the red, or kill or disable them first.
- Cards cost **MP**. MP barely refills during a night, so spend it carefully.
- Every spell has a **Vector** (element). Enemies are **weak** (x1.5 damage) or **strong** (x0.6) against certain Vectors.
- **Hover a card** to see its range, area and damage before you play it.

---

# Part B: Combat

## B1. Turns and actions

| Mechanic | How it works now | Change it in |
| --- | --- | --- |
| Turn order | Every unit acts once per **round** in **initiative** order (DEX + PER/2). Party and enemies interleave. A "Round N" banner starts each round; the timeline shows this round and the next with portraits | `data/stats.json` derived.initiative |
| Turn mode | **Move OR act** (default): a unit either moves up to its Movement or takes one action. Other modes: move-then-act, move-and-act. F1 > Fights switches it mid-fight | `data/combat_rules.json` turnMode |
| Actions | Play a card, Strike (adjacent, uses STR), Guard (until your next turn: +3 Defense, +15% Magic Resistance), or improvise with the Vector Wheel | `data/stats.json` combat.guardDefense, guardMagicResistPct |
| Quick cards | Cards marked quick don't use your action or move. Limit: **1 quick card per turn** | card `"quick": true` |
| Undo move | Before acting, you can undo this turn's move (Esc or Back) | — |
| Movement | 3 + DEX/5 tiles. 4-way, blocked by walls, water, units and props | `data/stats.json` derived.movement |
| Selection | Idle → card selected (targets shown) → hover a target (preview) → confirm. Click the card again, right-click or Esc to cancel. A click on floor while a card is selected only cancels the card | — |
| Previews | Hovering a card or target shows range, area (in the Vector's color), damage, statuses, push landings, collisions, hazards, slides and whether it interrupts a telegraph | — |
| Enemy turns | Played one beat at a time: banner, highlight, move, wind-up, hit, log line. Combat speed setting; hold a key to fast-forward | — |
| Fleeing | Allowed in non-boss fights (not boss floors) | fight setup fleeAllowed |
| Combat difficulty | Chosen at new run. **Normal:** enemies either move or attack. **Hard:** enemies move, then attack | `data/combat_rules.json` difficulties |

## B2. Cards, hand and MP

| Mechanic | How it works now | Change it in |
| --- | --- | --- |
| Deck | Each character has their own deck (10 to 20 cards, max 3 copies of a design) | `data/leveling.json` deckMin, deckMaxBase |
| Hand | **Opening hand 5**, then **draw 2** at the start of each of your turns (including the first). **Hand limit 7**: extra draws stay in the deck | `data/stats.json` combat.openingHand, drawPerTurn, handLimit |
| Running out | When the deck is empty, the discard pile reshuffles and that character takes **Fatigue** damage (1, then +1 each reshuffle) | combat.fatigueStart, fatigueStep |
| Max MP | 4 + INT/2 + WIL/3 + class bonus, +0.5 per level. Roughly 8 to 12 at level 1 | `data/stats.json` derived.maxMp; classes mpBonus |
| MP regen | **1 per turn**. MP is **not** refilled between fights in a night, only by rest rooms, food and sleeping | derived.mpRegen |
| Spell cost | Magnitude cost (Minor 1, Standard 2, Major 4, Grand 7) + Form cost (0 to 3) + 1 if hybrid | `data/vectors.json` magnitudes; `data/forms.json` |
| Magnitude | Minor 5 power, Standard 10, Major 20, Grand 35. Capped by Knowledge Tier (Tier 1: Standard, Tier 2: Major, Tier 3: Grand) | `data/vectors.json` |
| Card kinds | **Spell** (Vector + Form + Magnitude), **basic** (Strike, Guard, Lunge, Dash...), **item**. 75 card records plus generated spell designs | `data/cards/*.json` |
| Rarity and upgrades | Common, uncommon, rare. Upgraded versions ("Ember Bolt+") via crafting and arena rewards | card rarity, upgrade |
| Can't play | Unaffordable cards, or ones needing a used action, are greyed out with the reason on hover | — |

## B3. Damage and defense

| Mechanic | How it works now | Change it in |
| --- | --- | --- |
| Spell damage | Power x Form multiplier x (1 + Vector affinity bonus) x **matchup** x (1 − target Magic Resistance %) x other bonuses | `src/core/combat/resolver.gd` spell_damage |
| Strike damage | Stat x card multiplier (+ infusion), minus target **Physical Defense** (CON/2 + armor). Always at least 1 | resolver strike_damage |
| Magic Resistance | WIL/2 points x 2% each, max 60% | combat.magicResistPctPerPoint, maxMagicResistPct |
| Crit | 5% + DEX/2 %, x1.5 damage | derived.critChancePct; combat.critMultiplier |
| **Typing (matchups)** | Each enemy is **weak to** some Vectors (x1.5) and **strong against** others (x0.6); everything else is x1.0. Shown with icons on the enemy | enemy weakTo, strongAgainst; `data/matchups.json` |
| Back attack | Hitting a unit from behind (relative to its facing): x1.15, for everyone | combat.backMul |
| Flank (Backstab) | Rogue perk: x1.5 from behind or from a different row within 1 column | combat.flankMul |
| Cover | Standing on a cover tile: **ranged attacks deal x0.75**. That's all cover does right now | combat.halfCoverRangedMul |
| Friend nearby | +5% damage when standing next to a Friend-tier ally | combat.adjacentFriendDamagePct |
| Area falloff | Area attacks hit the first 2 targets in full, then x0.75 to each extra target | `data/combat_rules.json` areaFalloff |
| Enemy damage knobs | Enemy HP x0.65 (bosses x1.5). Telegraphed attacks x2.0. Difficulty damage x2.3 (Normal) or x2.0 (Hard) | combat_rules enemyHpMul, bossHpMul, difficulties; stats telegraphDamageMul |
| Downed | A party member at 0 HP is **downed**: they stay on the grid and any heal revives them. Still down when the fight ends = **injured** (misses the next dungeon) | `data/leveling.json` injuryDays |
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
| When | At the start of a party member's turn, every enemy without an intent picks one and commits to it. It resolves on that enemy's turn |
| Intent icons | Attack, special, buff, defend, move, over the enemy's head |
| Locked tiles | Red tiles; the attack hits **whoever stands there** when it resolves, including other enemies. Move out to dodge |
| Tracking | A different icon: the attack follows its target and can't be dodged by moving (used sparingly) |
| Charge-ups | Big attacks charge for a turn first, with a bigger telegraph. Bosses use patterns (cross, ring, rows, checkerboard, line) |
| Interrupts | Light cancels a charge, Cold delays it, pushes move it with the enemy, killing the enemy cancels it. The preview tells you when your card will interrupt |
| Re-aiming | If the target is gone, the enemy moves instead and re-telegraphs |
| Overlaps | Tiles hit by several telegraphs show combined damage. Hold the threat key for the **threat view** (every tile shaded by incoming damage) |
| Damage | Telegraphed attacks deal x2.0 (they can be dodged) |

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

Statuses last through the unit's next turn. Change them in `data/stats.json` combat and `data/ui.json` (names and icons).

## B9. Terrain and hazards

| Letter | Terrain | Effect |
| --- | --- | --- |
| `.` | Floor | — |
| `#` | Wall | Blocks movement and line of sight |
| `c` | Cover | x0.75 ranged damage to a unit standing on it |
| `h` | Hazard | 4 damage on entry |
| `w` | Water | Impassable until frozen |
| `i` | Ice | Slide until you hit something |
| `x` | Crate | Pushable, breakable prop |

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

| Class (arena name) | Role now | Starting deck | Perk |
| --- | --- | --- | --- |
| Mage (Ash) | Ranged and area damage | 2+2 Standard Bolts (two Vectors), Minor Burst, Minor Line, Minor Shield, Strike, Guard, Blink | Overchannel |
| Fighter (Brick) | Melee front line | 2 Strike, 2 Heavy Swing, 2 Lunge, Parry, Brace, Shove, Standard Weapon Infusion | Second Wind |
| Rogue (**Quill**) | Mobile skirmisher | 2 Strike, 2 Quick Stab, **2 Dash**, Blink, Afterimage, Throw, 1 Standard Bolt | Backstab |
| Healer (**Sage**) | Support | 2 Mend, Halo, Beacon, Standard Shield, 2 Standard Bolts (Light), Strike, 2 Guard | Triage |
| Bard (Lyric) | Buffs and tempo | Haste, Tailwind, 2 Dazzle, Rally, 2 Standard Bolts, 2 Strike, Guard | Hype |

Change these in `data/classes.json` starterDeck and `src/core/arena/arena_party.gd` (arena names).

Advanced classes (Class Change at levels 5 and 12): Elementalist, Kinetic Logician, Spellblade, Guardian, Trickster, Medic, Idol, Deli Knight, Smith-Mage, Upside-Touched. Each has its own perk.

## B11. Enemies

| Mechanic | How it works now | Change it in |
| --- | --- | --- |
| Stats | HP (x0.65 Normal), Movement, initiative, Defense, Magic Resistance, weak/strong Vectors, actions with power or stat multipliers, a disposition | `data/enemies/week1..5.json` |
| AI | Scores actions by expected value x how well they suit its personality, picks with some randomness. Surrounds, staggers telegraphs, protects healers, focuses wounded or isolated targets, avoids its own allies' telegraphs | `data/ai.json`, `src/core/combat/enemy_ai.gd` |
| Behaviors (12) | Charger, Bomber, Healer, Summoner, Shield bearer, Burrower, Sniper, Splitter, Hazard maker, Mirror, Leech, Anchor | enemy behavior |
| Elite affixes | Hasted, Armored, Burning, Vampiric, Shielded, Explosive (icons over the enemy) | `data/enemy_affixes.json` |
| Minions | Weak, often one-hit; count as half an enemy | `data/encounters.json` minionWeight |
| Encounters | Built from templates: Pack, Front and back, Swarm, Healer core, Ambush, Reinforcements, Summoner nest, Hazard lords, Elite escort. Count per week: 3–4, 4–5, 4–6, 5–6, 5–7 (elite rooms 4 to 7). Smaller parties face fewer, weaker enemies | `data/encounters.json` |
| Bosses | 5 (Hollow Mascot, Cold Cut, Forge Revenant, Night Ward, Mirror Town), with phases, adds and reinforcements from week 3 | `data/enemies/bosses.json` |

## B12. The Endless Arena

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

## C4. Crafting cards

- At the workbench, choose Vectors, Form and Magnitude, then play the crafting **minigame** for that Vector type:
  - Thermal: hold to heat and stay in the band.
  - Precision: a timing bar.
  - Alignment: lock spinning rings.
  - Chemical: an arrow sequence.
- **Performance** sets how many **Properties** (bonuses from a bank of 15) the card rolls: below 0.35 gives none, below 0.8 gives one, otherwise two. A score of 0.95+ adds a Magnitude step.
- The card collection is shared. Each deck can use up to the copies you own (max 3).

Change these in `data/minigames.json`, `data/properties.json` and `src/core/progression/crafting.gd`.

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

- **Each week** has a **Vector signature**, shaped by town events, that decides which enemies and loot appear.
- **Floors:**
  - Monday to Thursday floors are generated rooms: combat, elite, treasure, rest, event, merchant and exit.
  - Friday is the **boss floor:** returning encounters (ones you fled from come first), a rest room, then the boss.
- You walk in through the woods edge and choose your party.
- **The exit** currently lets you leave as soon as you reach it, even with rooms uncleared. CT changes this (Part D).

Change these in `data/dungeon.json`, `data/weeks.json` and `data/encounters.json`.

## C8. Story, death and the Journal

- **Week 1 Monday:** Kelly is your guest on the first floor. Your choices that day add to **Kelly Risk**. At 4 or more, she panics and the run ends.
- **Story arc:** Mr. B's arc runs through weeks 1 to 5, with choices in weeks 3 and 4. The run ends at the `NARRATOR_REVEAL_TBD` finale.
- **Death:** a run summary, then the **Narrator's Journal** keeps lore, creatures, endings, best week and trait unlocks across runs.

Change these in `data/story/*.json`, `data/journal.json` and `data/endings.json`.

---

# Part D: Changing next (Combat Tuning, CT)

From the Oct 25 playtest. See `docs/COMBAT_TUNING.md` for details.

- Player damage down and enemy HP and damage up, to new kill-time targets.
- Enemies telegraph right before their own turn, then **move and attack** immediately.
- Cover becomes directional and meaningful.
- Hand size becomes **3**.
- Dash and other movement cards work before moving or carry over to the next turn.
- Clear roles for every class (Rogue and Healer first).
- The exit only opens when every fight on the floor is won.
- A full **combat tutorial floor** with Kelly, one new mechanic per room.
