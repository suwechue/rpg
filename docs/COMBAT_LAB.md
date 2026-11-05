# Combat Lab (separate milestone: CL)

This is a **separate milestone, CL (Combat Lab)**, outside `docs/ROADMAP.md`. Don't renumber or edit the roadmap for it.

**Order (user request, Nov 5):** CL comes **before everything else**. Finish and commit whatever is in progress, then start CL. Track it as its own row ("CL Combat Lab") in `docs/PROGRESS.md` and commit it as "CL: Part N ...". Where this doc conflicts with an earlier combat doc (CU, AR, CT, PT, P2, P3, TL), **this doc wins**. Update `docs/MECHANICS.md` with every rule change.

---

## Why

Combat works but isn't fun yet, and the user has said so after playing. Six rounds of combat changes were tuned mostly by AI simulations, which optimize win rate rather than fun. The progress notes show the result:

- **Multiplied damage:** enemy damage is multiplied (x2.5 Normal, x5 Hard) to keep the AI party from out-trading everything.
- **Free telegraphs:** reading telegraphs costs nothing, because you can dodge and attack in one turn.
- **Long fights:** a week 3 boss takes 34 to 51 actions.
- **Bookkeeping:** a turn is mostly bookkeeping: 2 Actions, a Quick, a Cantrip, Hold, MP, undo locks, riders.

**The new direction (user decisions, Nov 5):**
1. **The board is the weapon:**
   - pushes, pulls, pits, hazards and terrain reactions are a main way to win;
   - spells stay, and Vectors are how you shape the board.
2. **One Action per turn** unless a card is Quick or says otherwise.
3. **Strike stays**, as an Action.
4. **Guard is removed** from the game.
5. **Cantrips are removed** from the game.
6. **The Vector Wheel** (improvised casting in combat) **is removed** from the game. Crafting cards at the workbench and in the card builder stays.
7. **More interesting cards:** cards that work with your discard pile, your deck and **your teammates' decks**, so combos and interactions between characters carry the fun.

**The goal of CL:** find a version of combat that is fun **for a human**, by building a lab where rules are switches ("levers"), fights are hand-made, and the user plays and compares versions. **AI win rates are not the target in CL.** The sims stay as crash and stall checks only.

---

## Part 1: The Lab mode

- **How to open it:**
  - **Title screen:** a "Combat Lab" button. It shows in dev builds, and in any build when `data/lab/lab.json` has `"showOnTitle": true`.
  - **F1:** Fights > Lab.
  - **Dev flag:** `--lab --fight=<id> --preset=<id>`.
- **The Lab screen** has three parts:
  - **Fight list:** the hand-made fights from Part 4.
  - **Party picker:** preset characters, levels and decks; quick-edit a deck.
  - **Preset picker:** named sets of lever values, in `data/lab/presets.json`.

  A "Levers" panel shows every lever for the chosen preset, and the user can change any of them before starting. Changes can be saved as a new preset.
- **During a Lab fight:**
  - A small "Lab" tag shows the preset name.
  - F1 keeps the lever panel available mid-fight. Changes apply from the next turn, and the log notes them.
  - Restart (R) and "Restart with other preset" buttons.
- **After every Lab fight, a short rating card.** All answers are optional and the card is skippable:
  - Fun (1 to 5).
  - "Did you usually have more than one good option?" (1 to 5).
  - "Did you feel clever at least once?" (yes or no).
  - "What was boring or annoying?" (free text).

  Ratings are saved with the fight log.
- **The Lab log** goes to `user://lab/` as one JSON line per fight. Each line records:
  - the preset and its lever values, the fight and the party;
  - rounds and time taken, and the win or loss;
  - per turn:
    - the options the player had;
    - what was played;
    - pushes and kills by board effect;
    - combos triggered;
    - damage taken from telegraphed vs untelegraphed attacks;
  - the rating.

  A tool, `tools/lab_report.gd`, summarizes `user://lab/` into a table per preset: average fun, rounds, board kills, combos per fight, decision count. F8 feedback zips include the lab folder.
- **A/B mode:** "Play this fight twice" runs the same fight and seed with two presets back to back, then asks "Which was more fun, A or B?"
- **Data:**
  - `data/lab/lab.json` holds settings;
  - `data/lab/presets.json` holds presets;
  - `data/lab/fights.json` holds fights.
- **Code:** every lever is read through one place: a `Rules` view built from `combat_rules.json` plus the active preset. That way the same switches can later become the game's defaults without rewriting combat.

---

## Part 2: The new core rules

These are the **"cl_base"** preset. The current game's rules are kept as a **"current"** preset for comparison until Part 6.

### Turn

- **The turn:** each turn a character gets **1 Move** (up to their Movement) and **1 Action**.
- **What uses the Action:** a card or Strike.
- **The order:** move and act in either order. The Move can be split around the Action (move 2, act, move 2) if the "split move" lever is on.
- **Quick cards don't use the Action.** The quicks-per-turn lever caps how many (default 1).
- **Some cards say otherwise.** These keywords are in card text and data:

  | Keyword | Effect |
  | --- | --- |
  | **Free** | Doesn't use the Action or the Quick |
  | **Follow-up** | After this resolves, you may play one card with a named tag |
  | **Swift** | Gives back your Move after use |
  | **Heavy** | Uses the Action and the Move |

- **Removed from the game:**
  - **Guard:** the built-in Action or Quick, its button, its status and the `guard_active` and `guarded` hooks.
  - **The Cantrip:** the built-in 0 MP attack.
  - **The Vector Wheel:** improvised casting during combat.
- **Strike** stays as a built-in Action. Weapons still shape it (reach, push, infusion).
- **Hold:** off in `cl_base` (lever).
- **Undo:** a lever. Default: you can undo a Move until you play a card or something random happens.

### Hand, deck and MP

- **The hand:** 4 cards at the start of each turn (lever).
- **Leftover cards:** stay in hand (lever). The default is keep up to the hand size, so you plan across turns.
- **The deck:** when it runs out, the discard is shuffled back.
- **The discard pile:** visible and clickable. It matters for the Part 3 cards.
- **MP:**
  - **The pool:** a small pool that refills a little each turn (lever).
  - **What costs MP:** cards cost MP as now, and Actions limit how many you play.
  - **Lever alternative:** cards are free and MP is spent only on Major and Grand spells.

### Numbers you can read

- **Small numbers (lever, default on):**
  - **Rescaling:** enemy HP and all damage are divided down to a small scale. Normal enemies have about 3 to 8 HP, minions 1 to 2. Attacks deal about 1 to 4 and spells about 2 to 6.
  - **Bosses:** about 20 to 30 HP, plus phases.
  - **Party HP:** about 10 to 16.
  - **How:** do the rescale as a preset multiplier first, so the user can compare. If the small scale wins, make it the data's real values in Part 6.
- **No dice (lever, default on):**
  - no crits and no misses;
  - Blind turns into "attacks the tile next to its target, chosen in the telegraph", so it stays readable;
  - Stability and Instability rolls still apply to risky multi-Vector cards, unless the lever says otherwise.
- **Previews show the exact result:** hover anything to see the exact damage, push path, collisions, falls, terrain reactions and who dies. The preview is the truth.
- **Remove the difficulty damage multipliers** in `cl_base`. Difficulty comes from enemy count, enemy abilities and board layout instead.

### Telegraphs as a dilemma

- **Exact telegraphs:** enemies telegraph exact tiles and the exact damage at the start of the player's turn. All of them, before you act.
- **Ways to stop a telegraphed attack:**
  - push or pull the attacker so its tiles no longer hit;
  - kill it;
  - put a Construct or a pushed enemy in the path;
  - move the target out;
  - **redirect:** move an enemy into another enemy's telegraphed tiles. It takes that hit.
- **Telegraphs that track** (follow their target) are rare and marked with their own icon.
- **Lever, "Enemies hit hard but rarely":** each enemy acts every other turn with a bigger hit, so turns where it's quiet are your window.

### Rewards for playing well (levers)

- **Surge meter:**
  - **Filling it:** a party-wide meter fills when you dodge or cancel a telegraphed attack, make a board kill (pit, collision, hazard), redirect an enemy hit, or trigger a combo.
  - **Spending it:** at full, any one character can make their next card Free and one Magnitude higher.
- **Kill refund:** killing an enemy with your Action gives back your Move (or your Action, as a lever).
- **Combo chain:** each different teammate who plays a card on the same enemy this round adds +1 damage to the next card.

### Short fights with goals

- **Targets:** normal fights end in **3 to 5 rounds**, elites in 5 to 6, bosses in 6 to 8, with 2 or 3 phases.
- **The round cap:** if a fight passes the cap (lever, default 8), "the Upside-Down shifts": enemies get +1 damage per round. This ends stalls without a timer screen.
- **Fight goals besides kill-everything** (data per fight):
  - survive N rounds;
  - protect a character or object;
  - reach the exit;
  - break the anchor or totem;
  - stop the ritual (an enemy charging a 3-round spell);
  - capture a tile.

---

## Part 3: Cards that make combos

Add **at least 40 new cards** in `data/cards/lab_cards.json`, using the existing data-driven effect engine (`card_effects.gd`). Add new effect ops where needed:
- `discard_*`, `deck_*`, `ally_deck_*`, `exhaust`, `board_*` and keyword handling;
- clear card text written from the ops;
- previews that show what each card will do.

The tables below are a starting set. Names and numbers are tunable; keep the ideas.

### Your discard pile

| Card | Effect |
| --- | --- |
| Recall | Quick. Return a card from your discard to your hand |
| Echo | Replay the last card in your discard at half Magnitude (it stays in the discard) |
| Kindling | Deal +1 damage for each Heat card in your discard |
| Burnout | Exhaust up to 3 cards from your discard: +2 damage each |
| Afterimage Step | Free. Swap places with the target of the last Motion card in your discard |
| Scrapheap | Shuffle your discard into your deck; draw 1 |

### Your deck

| Card | Effect |
| --- | --- |
| Foresight | Quick. Look at your top 3, put them back in any order |
| Gamble | Draw 2; discard 1 |
| Rehearsed | If this is the first card you play this turn, draw 1 |
| Deep Pocket | Search your deck for a card with a tag and put it in hand. Exhaust |
| Stacked Deck | Put a card from your hand on top of your deck; next turn it costs 0 MP |

### Your teammates' decks and hands

| Card | Effect |
| --- | --- |
| Pass | Quick. Give a card from your hand to an adjacent (or in-range) ally's hand |
| Borrow | Play the top card of an ally's deck as if it were yours (their Vector, your position) |
| Setup | Put a card from your hand on top of an ally's deck. It costs 1 less MP for them |
| Harmony | If the last card an ally played shares a Vector with this one, it is Free |
| Relay | After an ally pushes an enemy this round, this card pushes it again |
| Encore for Two | Your ally replays the last card they played, at half Magnitude |
| Shared Burden | Move one of your statuses to a willing ally, or theirs to you |

### Board cards (spells that shape the board)

| Card | Effect |
| --- | --- |
| Shove Line | Force. Push everything in a line 2 tiles |
| Undertow | Motion. Pull all enemies within 2 one tile toward a chosen tile |
| Flash Freeze | Cold. Turn water and wet tiles to ice; units on ice slide when pushed |
| Steam Vent | Heat on water makes a steam cloud that blocks sight and telegraphs aimed through it |
| Collapse | Force. Crack a tile: it becomes a pit at the end of the next round (telegraphed to both sides) |
| Anchor Point | Binding. A tile that nothing can be pushed past |
| Barrel Toss | Throw a prop 3 tiles; it explodes or spills by type |
| Bridge | Cold or Construct. A walkable tile over a pit or water for 2 rounds |
| Swap | Motion. Swap any two units in range (enemy into a telegraph works) |

### Payoffs and keywords

| Card | Effect |
| --- | --- |
| Shatter | Triple damage to a Frozen target |
| Detonate | Every burning tile explodes for 2 |
| Domino | Push; each collision pushes the next unit too |
| Finisher | Free if the target was pushed or collided this round |

**Exhaust:** played and removed for the rest of the fight. Strong cards use it.

**Class decks** are rebuilt so each class has a board role and a combo role:

| Class | Board role | Combo role |
| --- | --- | --- |
| Fighter | Pushes, Domino | Finishers |
| Mage | Terrain spells | Discard payoffs |
| Rogue | Swaps and repositioning | Deck tricks |
| Healer | Anchors, Bridges | Statuses moved to allies |
| Bard | Pass, Borrow, Encore | Teammate decks |

Starting decks are 8 to 10 cards.

**Synergy existing systems:** combos, Techniques, gear and riders keep working where they still make sense. Anything that only existed for Guard, the Cantrip or the Wheel is reworked or removed (Part 5).

---

## Part 3b: The board

- **Every Lab fight has interactables.** Each one is a data prop with a type and rules:

  | Prop | Rules |
  | --- | --- |
  | Pits | Fall in: enemies die (bosses take heavy damage), party members take damage and come back next to the edge |
  | Ledges and low walls | Push off for fall damage |
  | Water | Heat makes steam, Cold makes ice, Lightning arcs |
  | Ice | Pushed units slide until they hit something |
  | Explosive barrels | Heat or a hard push makes them blow up in a plus shape |
  | Oil and gas | Spreads fire |
  | Crates | Block, push-able, can be destroyed |
  | Spikes | Damage on entry |
  | Conveyors and currents | Move units 1 tile at round end |

- **Collisions:**
  - A unit pushed into a unit or wall takes collision damage (lever, default 2), and the unit it hit also takes it.
  - With the Domino lever on, a push can chain into the next unit.
- **Terrain reactions:** one table, `data/lab/reactions.json`, decides what each Vector does to each tile type. Reuse the existing Vector tile rules and add the new ones. The preview reads from it.
- **Enemy AI respects the board:** enemies avoid edges and pits when they can. Some enemies are immovable (marked with an icon), so it's not trivial.

---

## Part 3c: Extra mechanics as levers (user request, Nov 5)

Every mechanic below is a lever. All of them are **off in `cl_base`**, unless marked "default on". The user switches them on in the Lab to try them.

**Reuse what exists before building new.** The game already has flanking, relics, reinforcements, hidden units and darkness, card picks, combat speed settings and a combat log. Build each lever on those where it fits.

**Every mechanic needs:**
- the exact preview (Part 2);
- a line in the plain-words log;
- an icon or label wherever it's active;
- text in the Lab's lever panel saying what it does.

### Turn order and tempo

| Mechanic | Lever | What it does |
| --- | --- | --- |
| Team turn vs alternating turns | `turnStructure`: "team" (default), "alternate" | **Team:** the whole party acts, then all enemies. **Alternate:** one ally, one enemy, and so on. Telegraphs update after each enemy acts |
| Choose your order | `chooseOrder`: false | At the start of the party turn, the player picks who goes next each time; the timeline shows who has acted |
| Initiative from cards | `cardInitiative`: false | Playing a Quick or Swift card moves that unit earlier next round; Heavy moves it later. The timeline previews the change |
| Delay | `delay`: false | A unit can pass and act after the next enemy (once per round per unit) |

### Positioning

| Mechanic | Lever | What it does |
| --- | --- | --- |
| Facing | `facing`: false; `facingBackMul` 1.5, `facingSideMul` 1.25 | Units face the way they last moved or attacked. Back and side hits deal more. An arrow under each unit shows facing. Replaces flanking while on |
| Zones of control | `zoneOfControl`: "off", "extra_move", "free_hit" | Leaving a tile next to an enemy costs +1 Movement, or gives that enemy a free hit. Shown as faint tiles around enemies |
| High ground | `highGround`: false; `highRange` +1, `highDamage` +1, `fallDamage` reuse | Raised tiles give +range and +damage downhill. Uses the 2.5D heights; pushing off a raised tile is a fall |
| Body blocking | `bodyBlock`: false | A unit standing between a telegraphed attack and its target takes the hit instead. With gear, armored allies take less. The preview shows who'd be hit |
| Line of sight and fog | `lineOfSight`: false; `fog`: false | **Line of sight:** spells need a clear line; walls, crates and Constructs block. **Fog:** enemies' plans in fog are hidden until something lights them (Light, Reveal, adjacency); hidden plans show as "?" |

### Spells and Vectors

| Mechanic | Lever | What it does |
| --- | --- | --- |
| Charge-up spells | `chargeSpells`: false | Cards with the **Charge** keyword fire at the start of your next turn at +1 Magnitude. The target tiles are telegraphed, and enemies try to dodge them. Add 6 Charge cards |
| Lingering fields | `lingeringFields`: false; `fieldRounds` 3 | **Leftover terrain:** spells leave terrain for N rounds. Heat leaves fire, Cold ice, Binding sticky ground (costs +1 Movement), Light leaves glare (no hidden units), Force cracks floor that turns to a pit after 2 hits. **Fields react:** they follow the reactions table |
| Vector weather | `weather`: false; `weatherBonus` +1 Magnitude, `weatherMalus` -1 | Each fight has a strong and a weak Vector, by default from the Upside-Down's weekly signature. Shown at fight start and on the effects strip |
| Overload | `overload`: "off", "hp", "exhaust", "both"; `overloadHp` 3 | Cast one Magnitude above what you can afford by paying HP or Exhausting a card from hand. Risky multi-Vector cards still roll Instability |
| Cross-ally element combos | `allyReactions`: false | When two different allies hit the same tile or unit with different Vectors in one round, a reaction fires automatically (steam, explosion, shatter, conductive arc, and so on, from `data/lab/reactions.json`). A burst effect and a log line name the combo. It counts for Surge and combo discovery |

### Cards and decks

| Mechanic | Lever | What it does |
| --- | --- | --- |
| Upgrade in combat | `fightUpgrade`: false; `fightUpgradeAt` 3 | A card played N times in one fight becomes its "+" version until the fight ends |
| Status cards | `statusCards`: false | **Junk cards:** some enemy attacks shuffle junk cards into your deck: Fear (unplayable, discards 1 when drawn), Burned (lose 1 HP when drawn), Tangled (costs your Move to play away). **Clearing them:** deck tricks, Exhaust, and a few cleanse cards remove them. **Data:** status cards live in `data/cards/status_cards.json`; add them to 6 enemies' actions |
| Signature card | `signatureCard`: false | Each character has one unique card, always in their opening hand. The 5 preset characters and the Core Four get one each, in `data/cards/signature_cards.json` |
| Retain | `retainKeyword`: false | Cards with **Retain** stay in hand when the hand is discarded (only matters when `keepHand` is false) |
| Duet cards | `duetCards`: false; `duetBond` "Close" | Cards that need two specific characters adjacent. They're unlocked by Bond (story) or a pick (arena). Start with 5 duets in `data/cards/duet_cards.json` |
| Reshuffle effects | `reshuffleEffect`: "none", "surge", "hp_cost" | When your deck reshuffles: gain 1 Surge, or lose 1 HP. Shown on the deck counter |

### Enemies

| Mechanic | Lever | What it does |
| --- | --- | --- |
| Enemy roles | `enemyRoles`: false | **Adds 5 role tags to enemies:** Shield bearer (front blocked; hit from the side or push), Bomber (explodes in a plus shape when pushed or killed; works for you too), Anchor (immovable; stops pushes next to it), Summoner (spawns a minion every 2 rounds; a priority target), Copycat (repeats the last card the party played). **Uses:** at least one Lab fight uses each. Reuse the AR behaviors where they match |
| Weak points | `weakPoints`: false | Some enemies and boss parts show a marked tile or side. Hitting it Staggers them and cancels their current telegraph |
| Morale | `morale`: false; `moraleRadius` 2 | When an enemy dies, enemies within the radius may panic: they flee or switch to a weaker plan. The preview shows "may panic". Bosses and mindless enemies are immune |
| Longer boss intents | `bossLookahead`: 1 (default), 2 | Bosses show their next 2 turns' plans, the second faded |

### Party and characters

| Mechanic | Lever | What it does |
| --- | --- | --- |
| Downed allies | `downedRules`: "current" (default), "carry" | **Carry:** a downed ally lies on the board. An adjacent ally can drag them 1 tile with their Move, or revive them with a heal card. They're out of the fight only if an enemy hits them while down, or the fight ends with them down (story rules decide after) |
| Swap in reserves | `reserves`: false; `reserveUses` 1 | Once per fight, bring a benched member in at a marked edge tile in place of a downed or chosen ally (their turn is spent) |
| Bond in combat | `bondInCombat`: false; `bondTier` "Close" | Adjacent allies with that Bond share one free Quick per round (either can use it). Shown as a link between them |
| Class gauges | `classGauges`: false | Each class gets a simple meter with one spender card or effect: Fighter **Momentum** (pushes and collisions), Mage **Heat** (casting, which overheats: at full, the next cast is +2 Magnitude, then the meter locks for a round), Rogue **Shadow** (rounds not targeted; spend for a free reposition and a back hit), Healer **Faith** (preventing or healing damage on allies; spend for a free revive or shield), Bard **Tempo** (playing cards in a chain with allies; spend to give an ally an extra Action). Numbers in `data/lab/gauges.json` |

### Fight structure

| Mechanic | Lever | What it does |
| --- | --- | --- |
| Waves in a fight | `fightWaves`: false | **Reinforcements:** they arrive on a set round from marked doors, and the doors are telegraphed a round early. **Blocking:** a unit, crate or Construct on a door stops that group |
| Bonus objectives | `bonusObjectives`: false; `bonusCount` 2 | **Optional goals:** each fight shows 1 to 3 optional goals from a pool in `data/lab/bonus_goals.json`, e.g. "No one goes down", "Win in 4 rounds", "Kill 2 with the board", "Trigger a combo", "Never get hit by a telegraph". **Rewards:** shown on the result screen; they give extra rewards in story and arena |
| Retreat | `retreat`: false | An exit tile in each fight. If the whole party reaches it, the fight ends: you keep what you found but lose the fight's reward. Story rules decide what fleeing means after |
| Environmental timers | `envTimers`: false | Fights can have a board clock: rising water (one row floods per round), a collapsing floor (telegraphed tiles fall), spreading fire. Shown as a counter and tile warnings |

### Rewards and progression

| Mechanic | Lever | What it does |
| --- | --- | --- |
| Choose after a fight | `postFightChoice`: false | After a win, pick one: a new card (1 of 3), a gear upgrade, or **remove a card** from a deck. Story and arena |
| Card mastery | `cardMastery`: false; `masteryUses` 10 | Using a card N times across a run unlocks its "+" version permanently for that run |
| Run-wide relics in the story | `storyRelics`: false | Relics (from the arena) can drop in the story too. They're small rule changers, e.g. "Your first push each fight goes 1 extra tile". Add 10 board-themed relics |

### How the game feels

| Mechanic | Lever | What it does |
| --- | --- | --- |
| Hitstop and slow motion | `hitstop`: true (default on); `hitstopMs` 60; `killSlowmo` true | A short freeze on hits, and slow motion on kills. Screen shake on collisions follows the existing shake setting. A slow pan on big combos |
| Board kill cams | `killCam`: true (default on) | A quick zoom when a unit falls into a pit or off a ledge, or dies to a collision or explosion. Skippable, and off when combat speed is fast |
| Speed controls | `speedControls`: true (default on) | The existing combat speed setting, plus a "skip enemy animations" toggle and hold-to-fast-forward in the Lab HUD |
| Plain-words combat log | `plainLog`: true (default on) | A scrollable log: "Brick pushed the Ghoul into the pit." Every lever that changes something writes a line. Reuse the existing log and its "why" lines |

---

## Part 4: Hand-made Lab fights

Build **at least 8** fights in `data/lab/fights.json`. Each is a fixed map, enemy set, party, goal and seed:

1. **Ledge Day:** 3 minions near a pit. Learn push kills.
2. **Hold the Line:** survive 4 rounds while 2 chargers telegraph lines at an object you protect.
3. **Thin Ice:** a frozen pond, Cold and Force. Slides and collisions.
4. **Fire Sale:** barrels and oil in a shop, against enemies that throw. Blowing up the room.
5. **Hand-Off:** a 2-person party built around Pass, Borrow and Setup. Teammate deck combos.
6. **The Ritual:** an enemy channels a 3-round spell behind cover; break through or redirect.
7. **Crowded Hall:** 6 enemies in a narrow hallway. Domino and Line.
8. **The Hollow Mascot, remixed:** the week 1 boss in 3 phases, with board gimmicks (the floor collapses in phase 2).

Optional: **9. Arena sampler:** 3 waves back to back, so the user can feel a sequence.

**Presets to ship with:**

| Preset | Rules |
| --- | --- |
| `current` | Today's rules, for comparison |
| `cl_base` | Part 2 defaults |
| `cl_puzzle` | Small numbers, no dice, Surge on, kill refund on, hand of 4 keep |
| `cl_cards` | `cl_base` plus Follow-up and Free cards weighted up, hand of 5 |
| `cl_brutal` | `cl_puzzle` with "hit hard but rarely" enemies and the round cap at 6 |
| `cl_plus` | `cl_puzzle` plus the five top picks from Part 3c: `chooseOrder`, `allyReactions`, `statusCards`, `bonusObjectives`, `lingeringFields` |
| `cl_everything` | Every Part 3c lever on, for stress-testing how they combine. Not meant to be fun |

**More fights for Part 3c** (each shows off a group of the new levers; turn their levers on in the fight's suggested preset):

10. **Night Market:** fog, line of sight and a Summoner behind stalls (positioning).
11. **The Bell Tower:** high ground, a Shield bearer and a Bomber (positioning and enemy roles).
12. **Flood Drill:** rising water timer, waves through doors you can block, and retreat (fight structure).
13. **Duet:** two characters with Duet cards, Bond in combat and class gauges (party).

---

## Part 5: Removing Guard, the Cantrip and the Vector Wheel (whole game)

These are decided. Do them for the whole game, not just the Lab.

**Guard:**
- Remove the built-in Guard button and rules, `card_guard`, the guard status and icon, and AI Guard use.
- Perks, Techniques, gear, tutorial lessons and tests that refer to it are reworked as follows:
  - The **Guardian** perks become "the first hit each round on an adjacent ally is reduced by 2".
  - The **Bulwark aura** becomes an Anchor-style effect.
  - **Gear** that boosted Guard boosts collision resistance or push immunity instead.

**The Cantrip:**
- Remove the built-in 0 MP attack, its data in `combat_rules.json`, its UI, its AI use and its Techniques hooks.
- Make sure every class's starting deck can still deal damage with 0 MP, through Strike and 0-cost cards.

**The Vector Wheel and in-combat improvising:**
- Remove the Wheel UI and `improvise()`.
- Rework the things that used them:
  - "improvise" perks, traits and class abilities, e.g. "Once per fight, improvise at normal card cost";
  - the Unstable class's "very strong improvised casts";
  - Phase's dialogue;
  - the tutorial floor's wheel lesson;
  - class events;
  - the boss data that mentions the wheel.
- Each one becomes a card-based version. For example, "Once per fight, play a two-Vector card at normal cost", or a class card "Wild Cast" that makes a random two-Vector spell from your known Vectors.
- **Combo discovery** still happens through crafted cards (workbench and card builder) and Borrow/Harmony plays.

**After the removals:**
- Rewrite the combat parts of the tutorial floor to teach Move, Action, Quick, Strike, push into a pit, telegraph cancelling and the discard pile.
- Update `docs/MECHANICS.md`, `docs/CUSTOMIZE.md` and strings.
- Search the code and data for the words guard, cantrip, wheel and improvise, and for their string keys. Leave nothing behind except history notes in PROGRESS.md.

---

## Part 6: Rolling out what wins (only after the user says so)

- **Stop for the user's verdict.** When Parts 1 to 5 are done, stop and write a short summary in PROGRESS.md with:
  - the presets;
  - what the Lab log shows;
  - a request for the user to play.

  **Don't roll out until the user picks a preset** (or a mix of lever values).
- **Then make it the game:**
  - make the chosen lever values the real defaults in `data/combat_rules.json`;
  - rescale enemy and card numbers in data if small numbers won;
  - move story floors, the tutorial floor, the arena and encounter templates to the new rules;
  - add props and terrain to dungeon room layouts and arena layouts;
  - give week 1 to 5 enemies board-aware AI and some immovable ones.
- **Clean up:**
  - remove the unused levers' old code paths, except where the Lab still needs them;
  - keep the Lab as a dev tool for future tuning.
- **Re-check the sims for crashes and stalls only:** no fight past the round cap without the shift ending it, and zero errors.

---

## Levers (all in `data/lab/presets.json`; defaults are `cl_base`)

**Turn:**
- `actionsPerTurn` (1)
- `moveSeparate` (true; false = moving uses the Action)
- `splitMove` (true)
- `quicksPerTurn` (1; 0 = no cap)
- `strikeCost` ("action")
- `undo` ("until_card")
- `hold` (false)

**Cards:**
- `handSize` (4)
- `keepHand` (true)
- `drawPerTurn` ("refill"; or a number)
- `reshuffle` ("when_empty")
- `mpMax`, `mpRegen`, `cardsCostMp` (true)
- `exhaustOn` (true)
- `keywordsOn` (Free, Follow-up, Swift, Heavy)
- `teammateCards` (true)
- `discardCards` (true)

**Numbers:**
- `smallNumbers` (true), `hpScale`, `damageScale`
- `crits` (false), `misses` (false)
- `difficultyDamageMul` (off)
- `instability` (true)

**Board:**
- `collisionDamage` (2)
- `domino` (false)
- `pitKillsEnemies` (true), `pitDamageParty` (3)
- `fallDamage` (2)
- `iceSlide` (true)
- `propsDensity` (per fight)
- `reactionsTable` (default)
- `enemiesAvoidEdges` (true)

**Telegraphs:**
- `telegraphTiming` ("start_of_player_turn")
- `trackingShare` (0.1)
- `redirect` (true)
- `hitHardRarely` (false)
- `blindMode` ("adjacent_tile")

**Rewards:**
- `surge` (true), `surgeSize` (5)
- `killRefund` ("move")
- `comboChain` (true)

**Pacing:**
- `roundCap` (8)
- `shiftDamage` (+1 per round)
- `enemyCount` (per fight)
- `goal` (per fight)

**Difficulty:**
- `enemyHpMul`, `enemyDamageMul`
- `extraEnemies`
- `enemyAbilitiesTier`

**Part 3c levers** (off unless noted):

- **Turn order:**
  - `turnStructure` ("team")
  - `chooseOrder`
  - `cardInitiative`
  - `delay`
- **Positioning:**
  - `facing`, `facingBackMul` (1.5), `facingSideMul` (1.25)
  - `zoneOfControl` ("off")
  - `highGround`, `highRange` (+1), `highDamage` (+1)
  - `bodyBlock`
  - `lineOfSight`
  - `fog`
- **Spells:**
  - `chargeSpells`
  - `lingeringFields`, `fieldRounds` (3)
  - `weather`, `weatherBonus`, `weatherMalus`
  - `overload` ("off"), `overloadHp` (3)
  - `allyReactions`
- **Cards:**
  - `fightUpgrade`, `fightUpgradeAt` (3)
  - `statusCards`
  - `signatureCard`
  - `retainKeyword`
  - `duetCards`, `duetBond` ("Close")
  - `reshuffleEffect` ("none")
- **Enemies:**
  - `enemyRoles`
  - `weakPoints`
  - `morale`, `moraleRadius` (2)
  - `bossLookahead` (1)
- **Party:**
  - `downedRules` ("current")
  - `reserves`, `reserveUses` (1)
  - `bondInCombat`, `bondTier` ("Close")
  - `classGauges`
- **Structure:**
  - `fightWaves`
  - `bonusObjectives`, `bonusCount` (2)
  - `retreat`
  - `envTimers`
- **Rewards:**
  - `postFightChoice`
  - `cardMastery`, `masteryUses` (10)
  - `storyRelics`
- **Feel (default on):**
  - `hitstop`, `hitstopMs` (60), `killSlowmo`
  - `killCam`
  - `speedControls`
  - `plainLog`

---

## Tests and done when

**Tests:**
- Lever reading and presets load (every lever has a default and a type).
- Every keyword (Free, Follow-up, Swift, Heavy, Exhaust).
- Each new card op (discard, deck, ally deck, board ops).
- Pass, Borrow and Setup across two decks.
- Collisions, Domino, pits, ledges, ice slides, barrels and reaction table entries.
- Redirecting a telegraph into another enemy.
- Surge filling and spending, kill refund, combo chain, the round cap shift.
- Each fight goal.
- Small-number rescaling keeps every unit at 1+ HP and every hit at 1+.
- **Every Part 3c lever:** at least one test with it on, and one checking that it changes nothing when off. That covers turn structures, facing, zones of control, high ground, body blocking, line of sight and fog, charge spells, lingering fields, weather, overload, ally reactions, fight upgrades, status cards, signature, retain and duet cards, reshuffle effects, each enemy role, weak points, morale, boss lookahead, carry-downed, reserves, Bond in combat, each class gauge, waves and door blocking, bonus objectives, retreat, each environmental timer, post-fight choice, card mastery and story relics.
- `cl_everything` runs every Lab fight under autoplay with zero errors (levers combine safely).
- The Lab log writes one valid line per fight.
- `lab_report.gd` summarizes it.
- **Removal tests:** no guard, cantrip, wheel or improvise references remain in `src/` or data, except the history notes in PROGRESS.md and the reworked perk texts.
- **Smoke:** autoplay clears every Lab fight under each preset with zero errors and no stall.

**Done when (Parts 1 to 5):**
- **The Lab:** opens from the title, F1 and the dev flag; runs the 8 fights with any preset; changes levers before and during a fight; does A/B runs; saves logs and ratings.
- **Rules and cards:** the Part 2 rules work as `cl_base`; the 40+ new cards and board props are in.
- **Part 3c:**
  - every extra mechanic works behind its lever, with previews, log lines and lever-panel text;
  - the Charge, status, signature, duet and relic content is in;
  - fights 10 to 13 and the `cl_plus` and `cl_everything` presets are in.
- **Removals:** Guard, the Cantrip and the Wheel are gone from the whole game, with their dependents reworked.
- **Docs:** MECHANICS.md is updated.
- **Screenshots in `tools/screenshots/`:**
  - the Lab screen with the lever panel;
  - a push-into-pit preview;
  - a redirected telegraph;
  - a Borrow play;
  - the rating card.

**Stop then and ask the user to play (Part 6 waits for their pick).**
