# Arena Campfire: the wave 5 rest point (separate milestone: AC, scheduled later)

This is a **separate milestone, AC**, outside `docs/ROADMAP.md`. Don't renumber or edit the roadmap for it.

**Scheduled later (user request, Oct 28):** don't start AC until the demo ships (P2, PT, then VD Parts 5 and 6 done). Then build it before ROADMAP M12, unless the user says otherwise. Add it to `docs/PROGRESS.md` now as "AC Arena Campfire" with status **Scheduled (later)**, and commit it as "AC: ..." when built.

**Before you start, read these:**
- `docs/ARENA.md` (checkpoints, Arena AP, mutators)
- `docs/PATCH_1.md` Part 6 (card and perk picks, forge at checkpoints)
- `docs/PATCH_2.md` (owner choice and the effects strip)
- `docs/TOWN.md` and `docs/characters.md` (Gary, the blacksmith and the cast)

Where this doc changes an earlier rule, this doc wins.

**Goal:** replace the checkpoint menu with a small **walkable campfire camp** that the party reaches after every 5th wave (5, 10, 15 and so on). Every checkpoint action becomes a place or a person in the camp. The camp makes the arena feel like a journey, gives the cast a place to talk, and reuses the town's systems (dialogue, shops, minigames).

---

## Part 1: The camp scene

- **The map:**
  - A small top-down map (about 20x12 tiles at 32x32): a campfire in the middle, stations around it, and the gate at the far side.
  - Built from a layout in `data/arena/campfire.json`. Use M12 markers if M12 exists; otherwise a hand layout with named markers.
  - The camp tileset, props, fire animation and music (`music_arena_campfire`) and ambience (`amb_campfire`) are all asset ids with placeholders.
- **Arriving:**
  - A short arrival cutscene (P2 Part 3 cutscene system): the party walks out of the arena, the narrator gives a line, and a "Wave N cleared" title card shows.
  - The player is free to walk the camp. Nothing costs time except what costs Arena AP, and the Arena AP counter is on the HUD.
- **The effects strip** (P2 Part 2) is visible, so the player can see what's active.
- **Saving:** entering the camp saves the arena run, the same as the PT pause-menu save.
- **The camp grows:**
  - At waves 10, 20 and 30 (the numbers are in data), the camp gains small upgrades: more lights, a new NPC visitor, a stock upgrade at the deli.
  - So reaching deeper waves is visible.

## Part 2: The stations

Each existing checkpoint action moves to a station. The costs stay in `data/arena/checkpoint.json`.

| Station | What you do there | Replaces |
| --- | --- | --- |
| **Campfire** | Rest (heal 50% HP and MP, 2 AP), hear the narrator's line for this checkpoint, and see the run summary (waves, best hit, picks). | Rest, narrator line |
| **Companions** (members sitting around the fire) | Talk (Part 3), and swap party members (Part 4). | Swap teammate |
| **Gary's Deli, Arena Branch** | Buy items (Part 5). | New |
| **Workbench** | The Card Forge and deck editing: swap a card, craft, fuse, salvage, plus moving cards between members' decks. | Swap card, craft, forge |
| **Equipment rack** | Change equipment (1 AP). | Change equipment |
| **Blacksmith's stall** | **Open (user request, Oct 29).** Upgrade, infuse and repair gear (TL Part 4's smith screen with those three tabs), paid from banked coins. Forging new gear and commissions stay in town. *(Was: closed with a note.)* | Banked coins, ore |
| **Training room** (a tent or ring) | Train stats (Part 6), and pick the checkpoint perk or Technique from the trainer. | Perk or Technique pick |
| **The gate** | Choose the next mutator (and reroll it for 1 AP), see the next 5 waves' hazard sets, then walk through to start the next waves (Part 7). | Mutator pick, continue |
| **The path home** (story mode only) | Bank and leave (keep rewards so far). | Bank and leave |

- **Station labels:** every station has a floating label and an interact prompt, using the same interaction system as the town.
- **Done marks:** a station you've used this visit gets a small check mark.

## Part 3: Talking to companions

- **Who's there:** every roster member who isn't dead sits at the fire. That's the active party and the bench. In preset arena runs, the preset party (Ash, Brick, Quill, Sage, Lyric) is the cast.
- **Talking:** each one has **campfire lines** in `data/arena/campfire_talk.json`. The lines react to the run:
  - the last wave (who got downed, who landed the best hit);
  - the current mutator;
  - their deck ("I've got three Cold cards and no idea why");
  - their depth record.
- **Variety:** use 3 to 5 generic lines per character, plus reaction lines with conditions, and no repeats in a run until the lines run out.
- **Story mode:**
  - Talking gives a small Bond gain once per camp, using the town's Bond rules.
  - Characters can use their dossier voice and topics, and the Charisma-gated and misheard-line rules apply as in town.
- **Kelly:** if Kelly is in the roster, she gets special lines. Her Risk tier colors what she says.

## Part 4: Swapping party members

- **How it works:** talk to a benched member, then choose "Join the party". Pick who sits out from the active party's portraits. The swap costs 2 AP (the existing cost).
- **Moving cards:** cards stay in each member's own deck. The workbench can move a card between decks for 1 AP, if the receiver is eligible (same rule as P2 1.3).
- **A full party:** if the party is full and nobody is benched, the option is hidden. At wave 10 and later, a wandering recruit (a preset class not in the party) can appear at the fire and join the bench for free once. This is tunable in data.

## Part 5: Gary's Deli, Arena Branch

- **Who runs it:** a small deli cart. Gary runs it (or a Gary-family stand-in if the user prefers; that's an open question for the user). He uses his dossier voice and greets you by your depth.
- **Currency:** **Deli Tickets**, earned per wave cleared (more for elite and boss waves, bonuses for no-damage clears). Tickets are arena-only and reset when the run ends. In story-mode Rift runs, the deli takes real money instead, and tickets are not used.
- **Stock** (`data/arena/deli_stock.json`):
  - **Snacks:** consumables usable in combat as a Quick (heal, MP, cleanse, shield).
  - **Combos:** "meals" that buff the whole party for the next 5 waves (+1 Movement, +10% HP, +1 MP regen). Only one meal can be active at a time; it shows on the effects strip.
  - **A daily special:** a random card pack (choose 1 of 3, then pick the owner, P2 1.3) or a rare upgrade.
- **Stock changes:** stock rerolls every camp. Deeper camps unlock better stock.
- **Prices:** in data.
- **Art and text:** item icons, the cart sprite and Gary's portrait are asset ids. Item names and descriptions are in data. This is the same shop UI as the town deli (reuse it).

## Part 6: The training room

- **The trainer:** a coach character from the cast or a new arena NPC (the user decides). Placeholder "Coach".
- **Stat training:**
  - Pick a member and a stat, then play a short training minigame using the existing minigames re-skinned (strength: the timing bar; intelligence: the pattern; and so on).
  - A good score gives +1 to that stat for the rest of the run. A great score also gives +1 to a related derived value.
  - **Cost:** 1 AP per session. Each member can train once per camp, and stat gains from training are capped per run. Costs and caps are in data.
- **Perk or Technique pick:** the trainer offers the checkpoint perk pick (PT Part 6; Techniques after PT Part 8). This one is free, the same as today.
- **Point buy:** shows each member's current stats with the same derived values view as point buy.

## Part 7: The gate

- **The gate structure:** a stone gate (or arena door) at the far side of camp. Its look changes with depth.
- **Interacting with it** shows:
  - the mutator choice (1 of 3, reroll for 1 AP);
  - the hazard sets for the next 5 waves;
  - whether wave 10, 20 and so on is a boss wave;
  - the current run score.
- **Confirm:** "Leave camp and start wave N+1?" Any unspent AP carries over (existing rule).
- **The walk:** the party walks through the gate into the next wave with a short transition. Use a cutscene, so it can be skipped.

## Part 8: Data, modularity and tests

- **Data:** `data/arena/campfire.json` (layout, stations, depth upgrades), `campfire_talk.json`, `deli_stock.json` and training settings in `checkpoint.json`. Every station, item, line and cost is data.
- **Assets:** every sprite, icon, portrait, tile, sound and track is an asset id with a placeholder. Add them all to the manifest and `docs/ASSETS.md`.
- **Autoplay** (`--arena --autoplay`) handles the camp:
  1. rest if under 50% HP;
  2. buy the cheapest meal;
  3. train the lowest stat;
  4. take the first perk;
  5. pick a mutator, then go through the gate.

  `tools/sim_arena.gd` keeps working.
- **Tests:**
  - Each station action spends the right AP or tickets.
  - Swapping keeps decks.
  - Moving a card between decks checks eligibility.
  - Ticket income per wave.
  - Meal duration.
  - The training cap.
  - Talk lines pick by condition and don't repeat.
  - The blacksmith upgrades, infuses and repairs (opened Oct 29; it was closed).
  - The gate starts the right next wave with the chosen mutator.
- **Smoke test:** autoplay reaches wave 15 through two camps with no errors.

**Done when:**
- Every 5th wave leads to the walkable camp.
- Every old checkpoint action is reachable from a station.
- Companions talk and can be swapped in and out.
- The deli sells items for tickets.
- The blacksmith is open for upgrades, infusion and repair (it was visibly closed until Oct 29).
- The training room raises stats through minigames.
- The gate starts the next 5 waves.
- **Screenshots in `tools/screenshots/`:** the camp, the deli and the gate screen.
