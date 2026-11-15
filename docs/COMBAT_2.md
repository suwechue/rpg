# Combat 2.0: kits, spell charges and loadouts (separate milestone: C2)

This is a **separate milestone, C2 (Combat 2.0)**, outside `docs/ROADMAP.md`. Don't renumber or edit the roadmap for it.

**Order (user decision, Nov 15):**
- **Pause FF** at its next clean commit. It is testing the card system C2 replaces; FF resumes on C2 later.
- **Leave CL Part 6 unbuilt;** C2 replaces it.
- Then build **C2 Parts 1 to 5**: a vertical slice inside the Lab, next to the current combat.
- **Stop** for the user to play.
- **Part 6** (rolling C2 out to the story and arena) waits for the user's OK.

Track it as "C2 Combat 2.0" in `docs/PROGRESS.md` and commit it as "C2: Part N ...". Where this doc conflicts with an earlier combat doc, **this doc wins**. Update `docs/MECHANICS.md` as rules land.

---

## Why

Combat has been reworked six times and still isn't fun. The Lab Tuner (`docs/LAB_TUNING.md`) shows why:
- **Hit-then-step-off:** every agent persona found it, and enemies almost never land a hit.
- **Strike beats cards:** basic Strike out-hits most cards.
- **Cards nobody uses:** Surge is never spent, and teammate-deck cards sit unused.
- **No passing preset:** no preset passed the limits, and the best was 3.3 out of 5 fun.

The card hand adds randomness and bookkeeping without adding fun, and dodging every telegraph makes enemies harmless.

**The user's target:**
- a turn-based game that feels like **Persona**;
- the movement and turn order of ***South Park: The Fractured but Whole***;
- the build-your-setup feel of a **deck builder**.

**The core loop in one line:** characters with **fixed, readable kits** act in a **shared turn order** on a **small grid**. They **exploit Vector weaknesses** to knock enemies down and chain extra turns. Between fights you **build your loadout** from what you've collected, like a deck builder.

## The user's decisions (Nov 15)

1. **Turn order like *The Fractured but Whole*:** one shared timeline of allies and enemies by Initiative, each unit acting in turn. Not a party phase followed by an enemy phase.
2. **Crafted spells are abilities with a limited number of uses per dungeon**, not cards. They refill when you rest at home (or at arena checkpoints, see Part 2).
3. **The deck-builder feel comes from loadouts:**
   - equip perks and gear (armor, weapons, trinkets) that have real effects;
   - swap a character's moves for others as you collect more;
   - **level-ups add slots** for more stored moves, spells and perks.
4. **No deck, hand, draw or discard in combat.**

**My additions (the user can veto any of them; each is a lever):**
- Persona's **weakness → Knockdown → One More / Baton Pass → All-Out Attack** loop.
- **Enemy attacks land on their turn**, with no dodge window, except some boss attacks.
- **Bonds unlock combat team-ups.**
- **MP removed.** Spell charges replace it.

---

## Part 1: Turns and movement

- **The timeline:** every unit has Initiative (from Agility plus gear and perks). The timeline at the top shows the next 2 rounds of turns with portraits, and enemies are interleaved with allies. Some moves and statuses change the order: Haste, Slow, Delay ("act after the next unit"), Stun.
- **A unit's turn:** **Move** (up to Movement tiles, which can be skipped), then **one Ability** (a class move, a spell or the ultimate). Using the Ability ends the turn.
  - **Lever `moveAfterAct`:** off by default. If it's on, you may move after acting with leftover tiles. Off avoids hit-and-run.
- **One free item use per turn** (a consumable from the backpack), before or after moving. It doesn't end the turn.
- **Ending a turn with no Ability** gives **Brace**: take 25% less damage until your next turn.
- **Facing and back attacks:** a unit faces the way it last moved or acted. Hits to the back deal +50%, and to the side +25%. An arrow under each unit shows facing.
- **Enemy threat on hover:** hovering an enemy shows the tiles it can reach and hit on its next turn, as *The Fractured but Whole* does. A toggle shows all enemy threat at once.
- **Grid size:** fights use smaller grids, about 8x6 to 11x7, so positioning matters every turn. Reuse the 2.5D view, the board props and terrain from CL.
- **Keep from CL:**
  - pushes, pulls and collisions;
  - pits and ledges;
  - ice slides, barrels, crates and spikes;
  - the Vector reactions table;
  - exact previews and the plain-words log.

## Part 2: Kits (what a character can do)

**Each character's kit:**

| Slot | Start | Grows | What |
| --- | --- | --- | --- |
| **Class moves** | 4 | +1 at levels 4, 8, 12 (up to 7) | Unlimited uses. Some have a **cooldown** (1 to 3 turns). Each has a fixed **shape**: adjacent, line, cone, plus, burst around self, leap, projectile, self or ally |
| **Spell slots** | 2 | +1 at levels 3, 6, 10, 14 (up to 6) | Crafted Vector spells, each with **charges** |
| **Ultimate** | 1 | Upgrades at levels 7 and 13 | Fills a meter from dealing and taking damage, knockdowns and Baton Passes. Big, flashy, with a cut-in |
| **Perk slots** | 1 | +1 at levels 2, 5, 9, 13 (up to 5) | Passive rule changers (Part 4) |
| **Gear** | Weapon, armor, 2 trinkets | (existing) | Effects as in TL, plus Part 4 |

**Class moves:**
- **The pool:** each class has a **pool of 10 to 12 moves**. You start with 4 equipped and unlock more through levels, teachers, class events, the forge (weapon moves), Bonds and dungeon finds.
- **Strike disappears as a separate button:** every class has a basic attack in its kit instead.
- **Quick reference:** shape, damage, push, status and cooldown are all visible on the move. The preview shows exactly who is hit and what happens.

**Spell charges** (the finite resource):
- **What a spell is:** each crafted spell (from the workbench and card builder) is an Ability with **charges per dungeon night**:
  - Minor: 4;
  - Standard: 3;
  - Major: 2;
  - Grand: 1.

  The craft grade adds +1 charge for a great score. Multi-Vector spells have one fewer charge. All numbers are in data.
- **How charges come back:**
  - **all charges refill** when you sleep at home;
  - **rest rooms** in a floor refill 1 charge on each spell;
  - **items** like "Focus Snack" can restore a charge;
  - **in the arena,** charges refill at checkpoints (every 5 waves), so spending is a real choice.
- **Crafting:** charges make crafting matter. A strong Grand spell is your one big moment for the night.
- **Instability** stays for risky multi-Vector spells.
- **MP is removed.** The MP stat (INT and WIL) feeds spell power and charges instead.

**Ultimates:**
- **What they are:** one per class, and it can be swapped for alternates unlocked by class advancement.
- **Big moments:** examples are a party-wide shield, a huge push wave, or "every ally acts again".
- **The meter:** shown on the portrait.

## Part 3: Weaknesses, Knockdown, One More, Baton Pass and All-Out Attacks

- **Weaknesses:** every enemy has **weak**, **resist** and **immune** markings per Vector (Heat, Cold and so on), plus physical types from weapons (blunt, blade, pierce). They live in the enemy data.
  - **Discovering them:** markings are unknown (shown as "?") until you hit the enemy with that type, scan it (Light, the Reveal move, a Rogue perk) or have met it before. Discovered weaknesses are kept in the Journal.
- **Knockdown:** hitting a weakness (or landing a crit back attack, as a lever) knocks the enemy down.
  - **Effect:** it takes +50% damage, can't react, and **uses its next turn to stand up** (lever: it stands up and acts at half effect).
  - **The look:** knocked-down units are drawn on their side.
- **One More:** knocking down an enemy that wasn't already down gives the attacker an **immediate extra Ability**, without a Move (lever: a 2-tile step).
  - **Limit:** One More can't chain more than once per turn (lever).
  - **Feedback:** a big "ONE MORE!" cut-in and sound.
- **Baton Pass:** instead of taking the One More, pass it to an ally. That ally acts right now, out of turn order, with **+25% damage** and **+1 Movement**. A Baton Pass can be passed on again, and the bonus stacks to +50%.
  - **Unlocking it:** Baton Pass between two characters needs **Bond Acquaintance or higher** (story). In the arena, it's always on.
- **All-Out Attack:**
  - **When:** when **every enemy on the board is knocked down**, the party may launch an All-Out Attack.
  - **What happens:** every ally hits every knocked-down enemy within their Movement + 1, for big damage with a cut-in. All enemies then stand up.
  - **The alternative:** decline it, to keep your positions and the knockdowns.
- **Bond team-ups** (story; from the existing Bond tiers):

  | Bond tier | Team-up |
  | --- | --- |
  | Friend | A **follow-up attack** (a chance that the ally adds a hit when you knock down an enemy next to them) |
  | Close | **Protect** (the ally takes a killing blow for you once per fight) |
  | Unbreakable | A **duo ultimate** |

- **Enemies use it too:** some enemies hit party weaknesses and get their own One More, so your gear's resistances and armor types matter.

## Part 4: Loadouts (the deck-builder feel)

**What you collect:**
- class moves;
- crafted spells;
- perks;
- gear (armor, weapons, trinkets with effects);
- ultimates.

**What you choose:** what to equip in your limited slots.

- **Perks** (`data/combat2/perks.json`; rework the existing perks and Techniques into this format) change rules instead of only adding stats. Aim for **40 at launch**, 6 to 10 per class plus general ones. Examples:
  - "Your pushes deal +2 when they slam into a wall."
  - "One More also heals you 3."
  - "When you Baton Pass, the receiver gets +1 Initiative for the rest of the fight."
  - "Your first spell each fight costs no charge."
  - "Back attacks knock down regardless of weakness."
  - "Burning enemies are weak to Force."
  - "Knocked-down enemies next to you can't stand up while you're adjacent."
  - "+1 charge on Cold spells; Heat spells have one fewer."
- **Gear effects:**
  - **Every armor and trinket gets one effect line** on top of its stats.
  - **Armor types** set your Vector resistances and change Movement (light, medium, heavy, as in TL).
  - **Weapons** set your basic attack's type (blunt, blade, pierce) and shape, and can add one weapon move.
- **Build archetypes:** design 2 or 3 per class, so swapping matters. Examples:
  - Fighter: "wall-slammer", "protector";
  - Mage: "weakness hunter", "terrain controller";
  - Rogue: "back-stabber", "scout";
  - Healer: "anchor", "cleanser";
  - Bard: "baton conductor", "tempo".

  Each needs 3 or more pieces (moves, perks, gear) that work together.
- **Where you change loadouts:**
  - at home at night (free);
  - at the workbench;
  - at arena checkpoints and the campfire;
  - at dungeon **rest rooms**, limited to 1 swap per character.

  You can't swap mid-fight.
- **The loadout screen:**
  - one screen per character: slots on the left, your collection on the right with filters (Vector, shape, archetype tag);
  - hover-compare;
  - a **synergy hint** when two equipped pieces share a tag;
  - saved loadouts (3 per character).
- **Rewards feed it:**
  - after fights, pick one of 3 (a move, a spell recipe, a perk or a gear piece);
  - in the arena, after every wave;
  - in the story, from floor treasure and boss drops.

  This replaces card picks.

## Part 5: The vertical slice (in the Lab)

Build C2 as a **new combat ruleset in the Lab**, next to the current combat, without touching the story or arena yet.
- **Where the code goes:** new code in `src/core/combat2/`, with content in `data/combat2/`.
- **Reuse:** the grid, board, props, reactions, previews, log, AI search code and Lab tools.
- **Levers:** every open question is a lever in `data/combat2/rules.json`:
  - `moveAfterAct`;
  - knockdown behavior;
  - One More step and chain limit;
  - Baton bonus;
  - All-Out range and damage;
  - charges per Magnitude;
  - slot counts by level;
  - ultimate meter rates;
  - boss telegraphs;
  - weakness reveal rules.

**The slice content:**
- **4 characters** (the Lab presets): Brick (Fighter), Ash (Mage), Quill (Rogue) and Lyric (Bard), at level 1 and level 6 loadouts. Each has a 10-move pool, 2 to 3 example spells, 8 perks and an ultimate.
- **8 enemies** with weaknesses and resists, using existing sprites, including:
  - 2 that are immovable;
  - 1 that hits party weaknesses;
  - 1 that reveals nothing until scanned.
- **6 fights:**
  1. a tutorial-sized fight that teaches weakness and One More;
  2. a pit-and-push fight;
  3. a Baton Pass chain fight;
  4. a fight where All-Out is the win condition, against 5 weak enemies;
  5. a fight built around resists, so you must switch Vectors;
  6. the **Hollow Mascot** rebuilt as a C2 boss, with phases and 2 telegraphed big attacks.
- **A "night" mode:** 3 slice fights in a row with spell charges and HP carried over and one rest room. This tests the finite charges.
- **The loadout screen**, working for the 4 slice characters, with a collection of all slice pieces.

**Testing the slice** (reuse LT and FF tools):
- **AI players:** adapt `src/core/lab/players/` to C2 (the expert searches move, ability and One More/Baton chains).
- **Sweeps:** run with `shortlist`-style plans and LT's metrics: real choices, obvious turns, skill gap, close wins, rounds and dominant moves. Add C2 metrics:
  - knockdowns, One Mores, Baton Passes and All-Outs per fight;
  - spell charge use per night (are charges hoarded, or spent?);
  - move variety;
  - loadout variety among winning setups.
- **Agent playtest:** `lab_play` gets C2 support (timeline, kits, charges, weaknesses shown). Run LT's 5 personas on all 6 fights and the night mode, plus the Teen Player and Game Designer Critic from FF. Keep a budget of about 100 fights.
- **The report:** add a "C2 slice" section to `docs/LAB_TUNING.md`, comparing C2 with `tuned_1` and `current` on the same metrics, with agent quotes. **Check specifically:**
  - Do enemies land hits? Hit-then-step-off must be gone.
  - Is the basic attack still dominant?
  - Do players use spells, or hoard them?
  - Do One More and Baton Pass get used?

**Then STOP** and ask the user to play the slice. Make it reachable from the Lab button as "Combat 2.0 slice".

## Part 6: Rollout (only after the user approves the slice)

Don't start this until the user says so. When they do:
- **Characters:** convert every class to a kit (move pools, ultimates, slot growth).
- **Content conversion:**
  - every existing card becomes a class move, a spell recipe, a perk or an item, or is cut. Write the mapping table in PROGRESS.md first and show it to the user;
  - Techniques, riders, the Forge, fusing and combos become spell crafting, upgrades and perks;
  - enemies get weaknesses and resists.
- **Story combat:**
  - the tutorial floor teaches the C2 loop;
  - dungeon floors get rest rooms and charge refills;
  - nights carry charges.
- **The arena:**
  - wave picks become loadout rewards;
  - checkpoints refill charges and allow loadout swaps.
- **Removals:** the deck, hand, draw, discard, MP and card UI. Keep the history in PROGRESS.md.
- **Re-tests:** re-run FF on C2.

---

## Tests and done when (Parts 1 to 5)

**Tests:**
- **Turns:** timeline order with ties, Haste, Slow and Delay; Move then Ability ends the turn; `moveAfterAct` on and off; the free item use; Brace.
- **Positioning:** facing and back attacks; threat-range hover data.
- **Kits:** slot counts by level; cooldowns; every shape; charges per Magnitude, grade and multi-Vector; refills at home, rest rooms, items and checkpoints.
- **Weaknesses:** weakness, resist and immune; reveal rules.
- **Knockdown chains:** knockdown and stand-up; One More once per turn; Baton Pass (bonus stacking, Bond gate in story); All-Out when every enemy is down, its range and the stand-up after.
- **Bonds and enemies:** Bond team-ups; enemy One More on party weaknesses.
- **The ultimate meter.**
- **Loadouts:** loadout rules (slots, swap places, saved loadouts); every slice perk's effect.
- **Smoke:** autoplay clears every slice fight and the night mode under default levers with zero errors and no stalls.

**Done when:**
- The slice is playable from the Lab with its 4 characters, 8 enemies, 6 fights, night mode and loadout screen.
- All Part 5 levers work.
- The sweeps, the agent playtest and the comparison report are done.
- `docs/MECHANICS.md` has a C2 section.
- **Screenshots in `tools/screenshots/`:**
  - the timeline;
  - a weakness hit with the ONE MORE cut-in;
  - a Baton Pass;
  - an All-Out Attack;
  - the loadout screen.

**Then stop** and ask the user to play.
