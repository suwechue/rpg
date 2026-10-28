# Playtest Patch 1 (separate milestone: PT)

Written Oct 28, 2026 from the first outside playtest, the user's own notes, and the user's homebrew "Arcanist" D&D class: the tabletop design the Vector system came from. It's quoted in Part 8 as a source of ideas.

## How this fits with CT and VD

**Where things stand:**
- CT (`docs/COMBAT_TUNING.md`) is **in progress**. Part 1 (damage and kill-time targets) and the 3-card hand are done.
- VD (`docs/VECTORS_DEMO.md`) is **paused**.
- This is a **separate milestone, PT**, outside `docs/ROADMAP.md`. Don't renumber or edit the roadmap.

**Order:**
1. **Now, inside CT:**
   - Adopt **PT Part 1** (the new turn economy) and **PT Part 2's hand rules**, which replace CT's move-or-act and CT Part 4's cycling.
   - Finish CT's remaining parts on top of the new rules: telegraph timing, turn clarity, cover, class roles, exit lock and the tutorial floor. The tutorial must teach the **new** rules: 2 actions, quicks, Strike and Guard as quicks, holding a card.
   - Commit CT.
2. **Then PT Parts 3 to 9**, one commit per part ("PT: part N ...").
3. **Then resume VD.**
   - VD's 15 pair combos must include the **synergy and antagonism** rules from PT Part 8.
   - VD's Compendium covers the expanded Vector list.
   - VD's card forge work builds on PT Part 5. If they overlap, PT wins and VD extends it.

**Rules that apply to every part:**
- Content and numbers go in `data/`. Art and sound go through asset ids. Text goes in `data/strings.json`.
- Keep `docs/MECHANICS.md` updated with every change.
- Run the sims after each balance-affecting part and record the results in PROGRESS.md.
- Where this patch conflicts with CT, AR or the design doc, **this patch wins**. Log each conflict in PROGRESS.md "Decisions".

---

## Part 1: Turn economy (replaces move-or-act)

Playtesters found move-or-act too restrictive and the action rules confusing. New rules:

- **2 Actions per turn.** An Action is either:
  - **Move:** up to **4 tiles**. The default Movement becomes 4, still modified by DEX, Slow, Haste and terrain. Set it in `data/combat_rules.json` "moveActionTiles".
  - **A non-quick card or ability.**

  So a turn can be move + card, card + move, card + card, or move + move.
- **Quicks don't use Actions:** **1 Quick per turn** (`quicksPerTurn`, data). A Quick can be:
  - **Strike** (built in, not a card): an adjacent weapon hit with STR.
  - **Guard** (built in, not a card): +Defense and +Magic Resistance until your next turn.
  - **A quick card.**

  Quicks can be used **before or after moving**, and **after** your Actions. Remove Strike and Guard from every deck and replace them with class cards.
- **Cantrip** (from the homebrew's "Cantrip Magnitude"): every character who knows a Vector also has a built-in, **0 MP, Action-cost** ranged or touch attack in their primary Vector. It's single target, Bolt or Touch only, has no riders, and deals small damage. Casters always have something to do, just as Strike guarantees it for melee characters. Its damage is set in data per Vector.
- **Undo:** until you press **End Turn**, you can undo any step that **didn't reveal new information or roll dice:**
  - **Undoable:** moves, card targeting, and card plays whose outcome is fixed (no crit or miss roll, no draw, no hidden reveal).
  - **Locked in:** anything that rolled or revealed something. The undo button greys out from that point back, with the reason shown ("A crit roll happened").

  An undo stack lives in `CombatState`.
- **Action display on the HUD:** two Action pips and one Quick pip for the active unit, filled or empty. Hovering a card shows which pip it will spend.
- **The first round of an Arena wave:** all party members act before any enemy, in the first round only. After that, initiative works as normal.
- **Telegraph timing** (from CT Part 2, kept): enemies reveal their plan on the last party turn before their own, then carry it out. Enemies also get **2 Actions** (move + attack, attack + attack for some, move + move for chargers), shown in their telegraph. Update the AI and `enemyMoveAndActChance` accordingly (this replaces it).
- **Opportunity strike:** if a party member stands on the tile an enemy's telegraph says it will move to (blocking its plan), that party member gets a **free Strike** on the enemy when it arrives next to them or is stopped. Shown in the preview as "Blocks Frost Wolf's path: opportunity strike". It doesn't use their Quick.
- **Re-balance with the sims:** two Actions per turn roughly doubles player output, so re-tune enemy HP, damage and counts to keep CT Part 1's kill-time targets (in actions-to-kill terms) and win-rate targets.

## Part 2: Hand and deck rules

- **Hand of 3, refreshed every turn:** at the start of your turn, draw up to 3. At **End Turn**, every unplayed card in your hand goes to the discard pile, so next turn's hand is fresh.
- **Hold:** spend **1 Action** to keep 1 card in hand for your next turn (a small "held" pin on the card). You can hold at most 1 card. This replaces CT Part 4's "discard 1, draw 1 for 1 MP" cycling, which is removed.
- **No maximum deck size.** Keep a minimum of 8 cards. `maxCopies` stays at 3 but is configurable in data, and the user can set it to 0 for no limit. Fatigue on reshuffle still applies, so a huge deck has a real cost (more reshuffles at the wrong time).
- **Crafted cards go straight into the deck.** Removing a card from a deck costs **1 AP** in story mode, or **1 Arena AP** in the arena at checkpoints (data: `removeCardCost`). Adding cards from your collection is free.
- **The deck edit screen shows everything:**
  - the full card text;
  - the shape diagram (Part 3);
  - cost, Vector, Form, Magnitude and riders;
  - upgrade preview, rarity and synergy tags (Part 7);
  - filters by Vector, cost, kind and tag;
  - deck stats (cost curve, Vector mix, quick count).

## Part 3: Clarity fixes (from playtesters)

| Problem | Fix |
| --- | --- |
| Can't see party decks or skills in the Endless Arena until wave 5 | A **Party panel** reachable any time (pause menu, and a HUD button in combat and the arena) shows every character's deck, cards in hand, discard pile, stats, perks and techniques, and Vectors known. Read-only during fights; editable at the workbench and arena checkpoints |
| Character stats only visible in the debug menu | A **character sheet** in the Party panel: core stats, derived values (HP, MP, Movement, initiative, Defense, Magic Resistance, Stability, crit and high crit chances), Vector affinities, known Forms, traits, perks and techniques. Each line has a tooltip explaining what it does |
| Shield amount unknown (just an icon) | The shield chip shows its number ("Shield 12") and the HP bar gets an overlay segment showing the shield. Hover text gives the amount and the turns left |
| Can't see behind units | When the cursor is over a tile, any unit **in front of it** (lower row, overlapping sprite) fades to 30% opacity. Hold the threat-view key to **ghost all units**. The tile info panel always shows terrain, hazards, cover, telegraphs and the unit, for any hovered tile |
| Enemy effects not listed | The enemy hover panel lists **everything:** each action with its name, damage, **shape diagram**, range and riders; passives (burning trail, splits on death...); affixes; weak and strong matchups; statuses; current intent in words ("Next: Frost Breath, cone, 9 damage, hits Quill") |
| Area enemy attacks badly telegraphed | Area telegraphs draw the **full footprint**: filled red tiles, an outline around the whole shape, a line from the attacker to the shape, damage numbers on each tile, and a short pulse animation when the telegraph appears. Charge-ups pulse more strongly |
| Can't tell **who** is attacking, especially with several of the same enemy | Duplicate enemies get **number tags** (Wisp 1, Wisp 2) on their HP bars, and their telegraph tiles carry the same small number. **Hovering a red tile highlights the attacker(s)** and draws the line to them; hovering an enemy highlights its tiles. Each enemy's telegraph gets a slightly different tint |
| Quicks not obvious | Quick cards get a distinct frame edge and a lightning-bolt **QUICK** badge. The Quick pip lights up when one is playable. Strike and Guard show as quick buttons next to the hand |
| Cards don't show what cells they hit | Every card shows a small **shape diagram** (footprint on a mini grid, with the caster position marked), plus range, and an animated version on hover in the deck and crafting screens. Card text names the shape ("Plus shape, range 4") |
| Area effects not indicated | Player area previews (CU) also persist briefly after casting, showing the hit tiles. Lingering effects (burning, glyphs, auras, constructs) have tile overlays with turn counters |
| Unclear when a downed ally won't come back | **Downed** allies show a heart icon, "Down: revive with any heal" and a **bleed-out counter: 2 rounds**. If not revived in time, or if no one in the party can heal, they become **Out:** greyed portrait, a red X, a banner "Brick is out for this fight", and they're removed from the timeline. Injury rules after the fight are unchanged |
| No pause or save in the Endless Arena | A pause menu (Esc) in the arena: Resume, Party panel, Options, **Save and Quit** (saves the full arena state mid-wave, including the RNG; Continue on the title screen resumes it), and Abandon run |

## Part 4: Rules fixes

| Issue | New rule |
| --- | --- |
| Afterimage should dodge targeted attacks | **Afterimage's decoy absorbs the next targeted (tracking) attack** aimed at its caster this round. The attack hits the decoy instead (the Frost Wolf bites the afterimage). Area attacks still hit normally. Shown on the telegraph as "→ decoy" |
| Taunt | **Taunt (Beacon and others) forces every enemy in range** (that can reach the taunter this turn) to re-plan its intent at the taunter. Their telegraphs update immediately |
| Blind removed telegraphs | **Blind never removes a telegraph.** It adds a miss chance (35%) shown as a badge on the telegraph ("35% miss"). Only Light on a **charge-up** cancels, as in CU |
| Pushed enemies before they attack | If an enemy is moved before acting: **self-centered** areas move with it; **attacks aimed at a tile or unit** still happen if that's still in range and line of sight from the new position, otherwise the attack is **skipped** ("Off balance!"). The preview shows which |
| Blink | **Blink becomes a Quick** |
| Fire and burn can't kill | **Hazards and damage over time can kill** (remove the HP floor everywhere except tutorial rooms, which keep their training floor) |
| Tracking attacks too strong | **Tracking (auto-target) attacks deal about 60%** of a locked attack's damage (data: `trackingDamageMul`). They're the price of not being able to dodge |
| Lunge and hazards | **Lunge and other lunge or dash cards pass over hazards and gaps** without triggering them (not through walls or units) |
| Walls | Wall types in data: **low wall** (climbable and breakable), **wall** (breakable), **boundary** (unbreakable, the arena edge). **Climb:** 1 Action to move over a low wall into the free tile beyond. **Break:** walls have HP (low wall 12, wall 25); any attack hits them; **Force, Heavy Swing and Corrosion deal x2** to walls; a broken wall becomes rubble (floor, half cover). Layout letters added to `grid.gd` |
| Crits | Every hit rolls: **High crit** (x2.0) at `highCritChance`, otherwise **crit** (x1.5) at `critChance`, otherwise normal. Defaults: crit 5% + DEX/2 %, high crit 1% + DEX/10 %. Both shown on the character sheet and in hover previews. Distinct popup and sound for high crits |

## Part 5: Card forge (fusing, salvaging and riders)

The crafting screen is bare. Add a **Card Forge** tab at the workbench (and at arena checkpoints):

- **Fuse:** combine two cards into one.
  - **Element + technique:** an "element" card (Weapon Infusion, or any single-Vector spell) fused with a "technique" card (Lunge, Strike-type cards, Throw, Shove, Dash...) makes the technique carry that Vector. Examples: Weapon Infusion (Heat) + Lunge = **Heat Lunge** (Lunge that applies Burn); Frost Bolt + Throw = **Frost Throw**.
  - **Two spells:** fused into a **hybrid** (the two-Vector rules in Part 8, including synergy and antagonism costs).
  - The fused card's cost is the higher of the two costs plus the fusion surcharge, and its name is generated, with combo names from VD where they apply.
  - Both source cards are used up.
  - Fusion rules (which kinds fuse with which, the result) live in `data/forge.json`.
- **Salvage:** destroy a card for **Scraps** of its Vector (Heat Scraps and so on) plus generic scraps by rarity.
- **Upgrade:** spend Scraps to upgrade a card (the existing "+" versions).
- **Riders** (from the homebrew's Modifiers): spend Scraps to add a rider to a card. **Each extra rider on the same card costs more** (1st rider at its listed cost, 2nd +1, 3rd +2), and riders also raise the card's MP cost.

  | Rider | Effect | MP |
  | --- | --- | --- |
  | Slow | Target −2 Movement next turn | +1 |
  | Push/Pull | Move target 1 tile | +1 |
  | Daze | Target loses its Quick and has −20% hit chance next turn | +1 |
  | Lingering | Target takes 30% of the hit again at the start of its next turn | +1 |
  | Weaken | Target deals −25% damage next turn | +1 |
  | Widen | Area footprint grows one step (plus → 3x3, Line +2) | +2 |
  | Twin | Single-target only: also hits a second target within 2 tiles of the first | +2 |
  | Extended | Lasting effects (burn, auras, constructs, glyphs) last 1 round longer | +1 |

  A card can't have Widen and Twin together.
- **Mod slots:** each card has 1 rider slot at common, 2 at uncommon and 3 at rare.
- **The forge screen** shows a live preview card (shape diagram, new cost, name, effect) before confirming, and a satisfying reveal. Data: `data/forge.json` and `data/riders.json`.
- **Crafting minigames get more time:** increase every timing window and time limit by **50%** (`data/minigames.json`), and add an Easy/Normal minigame setting in Options.

## Part 6: Endless Arena progression

- **Card reward after every wave:** pick 1 of 3 cards (or skip for Scraps). Rarity improves with wave number. Offers are weighted toward the party's Vectors and classes, plus a chance of a new Vector card.
- **Every 5th wave (checkpoint):**
  - **a perk or Technique pick** (Part 8) for one party member;
  - Arena AP edits (as now, plus forge actions);
  - the mutator choice.
- **Point-buy stats at the start of any run** (story or arena): see Part 9.
- **Pause and save:** Part 3.
- **First-round initiative:** Part 1.
- **Score screen:** add the cards picked, the techniques taken, and the highest hit.

## Part 7: Synergy, card variety and enemy variety

### Statuses as setups and payoffs

Add these as statuses with icons, in `data/stats.json` and `data/ui.json`:

| Status | Comes from | Payoff |
| --- | --- | --- |
| **Wet** | Water tiles, melted ice, Cold + Heat steam, some cards | Lightning arcs through wet units; Cold instantly **Freezes** a wet unit (root + frozen) |
| **Frozen** | Cold on Wet, Freeze cards | Rooted; Force or Sound **Shatters** it for x1.5 damage |
| **Burning** | Heat | DoT; Force or Motion **spreads** it to adjacent tiles; Wind or Motion cards fan it |
| **Rooted** | Binding | Gravity **Crush** deals +50%; can't dodge telegraphs |
| **Poisoned** | Poison | Stacking DoT that doesn't refresh duration; Corrosion **doubles** the stacks; healing on them is halved |
| **Marked** | Cognition, Light (Reveal) | All damage to them +25% for 1 round |
| **Dazed** | Sound | Loses its Quick; −20% hit chance |
| **Exposed** | Warding (offensive), Corrosion | Loses resistances; takes x1.25 from its weaknesses |
| **Shadowed** | Shadow tiles | Can't be targeted from more than 2 tiles away; attacks from Shadowed units count as flanking |
| **Conductive** | Metal props, Wet | Lightning jumps to and from it |

- **Card tags:** every card lists what it **sets up** and what it **pays off** (for example "Sets up: Wet · Pays off: Frozen"), shown as small icons, filterable in the deck screen and used to weight card rewards toward your current deck.

### Card variety

Target at least **80 more cards** on top of AR's 63. Every card must include its shape, tags and timing.

- **Melee classes (Fighter, Rogue):** they must close distance, so give them many more **quicks, throws and gap closers.**
  - **Fighter:** Shoulder Charge (move 3 in a line, knock back), Grapple (pull adjacent enemy, root), Cleave (hits the 3 tiles in front), Iron Wall (quick: Guard + adjacent allies +2 Defense), Hurl (throw a crate or prop for damage), Riposte (quick: next melee attack on you is countered at x1.5), Earthshaker (Force line that breaks walls).
  - **Rogue:** Knife Fan (Cone of throwing knives), Hamstring (quick Strike that applies Slow), Vanish (quick: become Shadowed for 1 round), Ricochet (Projectile that bounces to a second target), Smoke Pellet (Shadow tiles plus dodge), Garrote (root and DoT from behind), Pickpocket (steal a card or buff from an enemy).
- **Every class:** 10 to 15 class cards in a class card pool (`data/cards/class_<id>.json`) that only that class (and its advanced classes) can draw as rewards. Advanced classes add 5 more each.
- **New Vectors (Part 8):** at least 6 cards per new Tier 2 Vector, 4 per new Tier 3.
- **A new Form: Cone** (from the homebrew). A widening triangle 1-3-5 tiles deep, range 0 (from the caster), x0.7, cost 2. Also for enemies.

### Enemy variety

- **Every enemy gets 2 to 4 distinct actions** with different shapes: single, line, cone, ring, cross, leap, pull, summon or buff, so fights against the same type still vary.
- **At least 24 new enemies** across weeks 1 to 5 and the arena, including families for the new Vectors:

  | Enemy | Vector | Gimmick |
  | --- | --- | --- |
  | Static Imp | Lightning | Chains through Wet units and Conductive props |
  | Hush Moth | Sound | Dazes; telegraphs a scream ring |
  | Gloom | Shadow | Hides in Shadow tiles; only Light reveals it |
  | Sludge Slug | Poison | Leaves a toxic trail; poison stacks |
  | Grav Rock | Gravity | Pulls everyone 1 tile toward itself each turn |
  | Ward Totem | Warding | Shields allies; break it first |
  | Mask of Whispers | Psychic | Confuses: an affected party member's next move goes 1 tile in a random direction |
  | Echo | Cognition | Copies the last card played, and creates illusions that look like enemies |
  | Rust Hound | Corrosion | Shreds Defense, eats cover |
  | Entropic Wisp | Entropy | Unstable: explodes when it drops below half HP |

  Use palette swaps and asset ids until the user draws art.
- **Elites** get one **signature mechanic** each (not just affixes), and bosses get 1 or 2 new attacks using the new statuses.
- **Encounter templates** (AR Part 4b) add combo-themed groups: "Storm front" (Static Imps with something that makes units Wet), "Toxic garden" (slugs + a healer), and "Gravity trap" (Grav Rock + chargers).

## Part 8: The Vector expansion (from the user's Arcanist homebrew)

The user's tabletop "Arcanist" class has a larger Vector list, a Fusion system with synergy and antagonism, Cantrip Magnitude, Modifiers (riders), a Magnitude-based Instability rule, and 24 "Axiomatic Techniques" in four categories. Adapt it as follows. Keep everything in data so the user can tune or rename any of it.

### Vector tiers and learning by affinity

- **Base Vectors** (learnable from the start): Force, Heat, Cold, Motion, Light, Binding. Unchanged.
- **Advanced Vectors** are **learned once your affinity in their parent Vectors is high enough** (and your Knowledge Tier allows). When they unlock, a level-up learning roll or a professor spotlight can teach them, and the Compendium (VD) shows the next unlock and its requirements.
- **The tree** (`data/vectors.json` "advanced", every threshold editable):

  | Tier | Vector | Parent affinity needed | Game effect |
  | --- | --- | --- | --- |
  | 2 | **Gravity** | Force 30% | Pull to a point, Crush (bonus vs Rooted), lift units over hazards; battlefield control |
  | 2 | **Lightning** | Heat 20% + Motion 20% | Arcs to a second target within 2 tiles; chains through Wet and Conductive |
  | 2 | **Sound** | Motion 30% | Daze; interrupts charges; shatters Frozen; breaks Constructs and walls faster |
  | 2 | **Shadow** | Light 30% (its mirror) | No damage: Shadow tiles, concealment, Shadowed status; pairs with Rogues |
  | 2 | **Warding** | Binding 30% | Temp HP or resistance to one Vector (protective), or Exposed (offensive). Doesn't stack: refreshes to the better value |
  | 3 | Transmutation (existing) | Binding + Motion | Change terrain and props |
  | 3 | Vitality (existing) | Light + Warding | Healing, or drain |
  | 3 | Corrosion (existing) | Heat + Binding | Shred Defense and resistances; x2 vs walls and cover |
  | 3 | **Poison** | Corrosion 15% + Binding 15% | Stacking Poisoned DoT; halves healing |
  | 3 | **Psychic** | Sound 20% + Light 15% | Ignores Defense and Physical resistance; no effect on mindless enemies (constructs, slimes) |
  | 3 | **Cognition** | Light 20% + Shadow 15% | No damage: Mark, reveal the next 2 enemy intents, illusions (decoy enemies or allies) |
  | 4 | **Entropy** | Corrosion + Heat, Tier 4 | Big decay damage; unstable (+Instability) |
  | 4 | **Void** | Shadow + Warding, Tier 4 | No damage: removes shields, buffs, hazards, constructs, glyphs and affixes |
  | 4 | **Time** | Motion + Gravity, Tier 4 | Movement and timeline control only (delay an enemy's turn, speed or slow movement). Like the homebrew, it **never** grants extra Actions or turns |

- Tier 4 Vectors and Knowledge Tier 4 are for Act 2 and deep arena waves (40+). Build the data and effects now, but gate them.
- **Probability** (the homebrew's strongest candidate, for Bards): add as a Tier 3 Vector with Light + Sound parents if it fits the sims. It nudges odds: forces a reroll on a crit or miss, or shifts crit and high-crit chances. If balance is a problem, leave it as data only and log it.

### Force is free but weak

From the homebrew: Force cards cost **1 less MP** (minimum 0) but deal **x0.7 damage**, so Force is the reliable cheap option, never the best damage per MP.

### Fusion (hybrids) with synergy and antagonism

- A two-Vector card or improvise costs a **fusion surcharge** by Magnitude: Minor +1, Standard +1, Major +2, Grand +3 MP.
- **Synergistic pairs** reduce the surcharge (down to a minimum of half, rounded up) and gain a small **resonance bonus** (+15% effect):
  - Heat+Motion, Cold+Binding, Light+Sound, Force+Gravity, Corrosion+Vitality, Lightning+Motion
  - Psychic+Sound, Warding+Vitality, Shadow+Binding, Void+Transmutation, Poison+Corrosion, Cognition+Light
- **Antagonistic pairs** add +1 MP and +2 to the Instability target:
  - Heat+Cold, Binding+Motion, Vitality(heal)+Entropy, Light+Corrosion, Lightning+Corrosion, Psychic+Binding
  - Warding+Entropy, Shadow+Light, Time+Entropy, Void+Warding, Cognition+Binding
- Antagonistic pairs still have their named VD combos (Thermal Shock and so on), so they're a high-risk, high-reward choice, not a trap.
- **Damage split** (homebrew rule): a fused card's damage is split between its two Vectors (each checks its own matchup), not doubled.
- **Three-Vector fusion** (Tier 3+): pays the surcharge twice.
- All pairs and numbers live in `data/vectors.json` "fusion". The VD combos table extends to new pairs over time.

### Instability by Magnitude (replaces the "% of current MP" rule)

- The homebrew found that scaling Instability with the MP pool made it irrelevant. New rule: a cast needs a Stability roll when its **final MP cost reaches the Magnitude's threshold:**

  | Magnitude | Threshold |
  | --- | --- |
  | Minor | never |
  | Standard | 4 MP |
  | Major | 6 MP |
  | Grand | 9 MP |

  Thresholds are scaled to the game's MP and set in data. Improvised casts always roll.
- **Target:** 10 + (cost − threshold) / 2 (rounded down), +1 for Entropy, +2 per antagonistic pair, −1 per synergistic pair (minimum 10). Roll d20 + Stability/2. The success chance is shown before casting.
- **Failure table** (homebrew "Arcane Strain", weighted, in data):

  | Result | Effect |
  | --- | --- |
  | Reduced | Half effect |
  | Misfire | Random valid target |
  | Backlash | Caster takes damage equal to the MP cost; the card still resolves |
  | Strain | Can't cast the same Magnitude next turn |
  | Wild Surge | Resolves, plus a random side effect |
  | Collapse | Fails completely; MP lost |

  This replaces the current Fizzle/Backlash/Misfire/Wild Surge table.

### Techniques (perks rework)

- Replace the perk picks at levels 3, 6 and 9 with **Technique** picks from a **shared pool in four categories,** adapted from the homebrew's Axiomatic Techniques:
  - **Forging:** constructs, glyphs, gear
  - **Alchemy:** potions and items
  - **Kinetics:** combat casting
  - **Meditation:** MP and stability
- Picks happen at levels 2, 3, 6, 10, 14 and 18. Each Technique has a minimum level (its tier).
- **Every class can pick from every category,** but each class's starting Technique and recommended picks lean toward one category.
- **Reconfigure** your Techniques at Night (workbench, 1 AP), or at arena checkpoints (1 Arena AP).
- **Starting pool** (`data/techniques.json`; adapt names and numbers freely):

  | Category | Tier I to II | Tier III to IV | Tier V to VI |
  | --- | --- | --- | --- |
  | Forging | **Runic Toolkit** (learn Construct; Constructs +50% HP), **Modular Imbuement** (Weapon Infusion can store a Glyph: next Strike places it) | **Efficient Forging** (Constructs and Glyphs −1 MP), **Lasting Rune** (Constructs and Glyphs +2 rounds) | **Overcharged Construct** (Constructs pulse their Vector each round), **Living Foundry** (once per fight, a Construct acts as an ally for 3 rounds) |
  | Alchemy | **Stored Formula** (once per Night, brew a spell card into a one-use **Potion** item card any party member can play as a Quick), **Reactive Terrain** (once per fight, saturate a 3x3 area with your Vector for 3 rounds) | **Volatile Brewing** (potions one Magnitude higher, with a 1-in-6 Instability chance), **Damage Type Fluency** (once per turn, change a card's Vector to another you know) | **Grand Reagent** (once per week, brew a Grand potion early), **Mutation Mastery** (choose the volatile outcome instead of rolling) |
  | Kinetics | **Vector Redirection** (reaction, 2 MP: redirect a targeted attack aimed at you to another enemy in its range; areas let you step out instead), **Reactive Casting** (once per round, cast your Cantrip at an enemy that enters a tile next to you) | **Conversion Reflex** (reaction, 1 MP: reduce damage of a Vector you know by INT/2 + level/2), **Mid-Flight Correction** (Projectiles and Lines ignore half cover) | **Perfect Counter** (Redirection costs 0 MP), **Living Equation** (Strike can be replaced by your Cantrip as a Quick) |
  | Meditation | **Still Mind** (first Instability roll each fight rolls twice and keeps the best), **Meditative Reserve** (rest rooms and checkpoints restore +3 MP) | **Resilient Mind** (all Instability rolls twice, keep the best), **Internal Casting** (ignore difficult terrain and hazards on your own turn while MP is at least 1) | **Deep Calculation** (once per night, restore full MP as an Action), **One With the Formula** (Instability thresholds +3) |

- **Reactions** (Redirection, Conversion Reflex) get a small prompt during enemy turns ("Redirect? 2 MP"), with an auto-decline after 3 seconds and an Options toggle to always ask, never ask, or auto-use.

### Adapting the Arcanist into classes

- The **Mage** is the closest to the Arcanist: a Kinetics and Meditation lean, Overchannel kept.
- Add **two advanced classes** built from the homebrew categories, with requirements and kits in `data/classes.json`:
  - **Alchemist** (from Mage or Healer; requires Stored Formula). Brews Potions, gets more Potion slots per Night, and party Potions are Quicks.
  - **Runesmith** (from Mage or Fighter; requires Runic Toolkit). Strong Constructs and Glyphs, and Infusion fusing. It overlaps the existing hidden Smith-Mage: make Smith-Mage its hidden upgraded version.
- Update `docs/MECHANICS.md` B10 and the class role table.

## Part 9: Point-buy stats at run start

- At the start of **any run** (story character creation, and the arena's party setup for **every** member), allocate stats with **point buy:**
  - all seven stats start at **3**;
  - spend **20 points:** 1 per point up to 8, 2 per point from 9 to 10;
  - nothing above 10 at creation.
- The class adds its own bonuses on top (from `startStats`, rebalanced as small bonuses).
- **"Recommended" button** per class; **"Random"** for fun.
- **Derived values update live** (HP, MP, Movement, crit and high crit, Stability...), with a one-line explanation per stat ("WIL: Magic Resistance, Stability, MP").
- The arena offers **"Use recommended for all"** to skip point buy.
- Data: `data/point_buy.json`. The story's spark quiz (VD Part 3) happens before point buy, and its trait shows here.

---

## Tests and done when

- **Core tests:**
  - the 2-Action economy;
  - Quicks, including Strike and Guard as Quicks after moving;
  - the Cantrip;
  - undo up to the last roll or reveal;
  - Hold and the end-of-turn discard;
  - no deck maximum and auto-add on craft;
  - the arena's first round with the party first;
  - opportunity strikes;
  - the Afterimage decoy absorbing tracking attacks;
  - Taunt re-planning;
  - Blind keeping telegraphs;
  - push skip and move rules;
  - Blink as a Quick;
  - hazard kills;
  - tracking damage;
  - Lunge over hazards;
  - wall climb and break;
  - crit and high crit;
  - fusion surcharge, synergy and antagonism;
  - damage split;
  - Instability thresholds and the new failure table;
  - every new status interaction;
  - forge fuse, salvage, upgrade and riders (with escalating cost);
  - advanced Vector unlock by affinity;
  - Techniques and reconfigure;
  - point buy;
  - arena save and resume.
- **Smoke tests:** arena autoplay to wave 15 with card picks and a Technique pick; one week 1 night; the tutorial floor with the new rules.
- **Sims:** re-tuned for 2 Actions. CT's kill-time and win-rate targets still hold, and every class reaches 15% or more of damage dealt or prevented.

**Done when:**
- Every row in Parts 3 and 4 is fixed and visible in a screenshot (`tools/screenshots/pt_*.png`).
- The 2-Action economy, hand rules and Card Forge work.
- The arena gives a card after every wave and a Technique every 5.
- At least 80 new cards, 24 new enemies, 5 new Tier 2 Vectors and 3 new Tier 3 Vectors are playable with the status synergies.
- Instability uses the Magnitude thresholds.
- Point buy works for story and arena.
- `docs/MECHANICS.md` describes all of it.
