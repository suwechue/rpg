# Combat Tuning and the Combat Tutorial (separate milestone: CT)

This is a **separate milestone, CT**, outside `docs/ROADMAP.md`. Don't renumber or edit the roadmap.

**Order:** do it **right after the milestone currently in progress**, before VD, because the demo needs balanced combat and a real tutorial. Then do VD (`docs/VECTORS_DEMO.md`), then return to the roadmap where you left off. Track it as its own row ("CT Combat tuning and tutorial") in `docs/PROGRESS.md` and commit it as "CT: ...".

**Every change here must also update `docs/MECHANICS.md`** (the mechanics reference) in the same commit. Add a rule to CLAUDE.md: "When any mechanic or number changes, update docs/MECHANICS.md."

**User playtest notes (Oct 25), arena with the preset party:**
- **Damage:** players one-shot enemies, while enemies need 7 or 8 hits to kill a player character. With everything telegraphed, that's far too easy. The fix is the damage numbers, not telegraphing.
- **Telegraph timing:** the telegraph appears too early. Enemies should telegraph at the start of the player turn right before theirs, attack immediately on their own turn, and be able to move and attack.
- **Cover** barely matters.
- **Too many cards:** players have too many cards at once; limit the hand to 3.
- **Quill (Rogue):** his kit was mostly movement with no real attacks, so the user spent fights running around and never attacking. Dash was confusing: playing it after moving wasted the MP.
- **Sage (Healer):** her role was unclear. She sat in the back, took no damage, and her healing was useless because nobody took much damage.
- **The first dungeon** needs to teach combat gradually: striking, guarding, enemy types, hazards, walls, telegraphing, cards, improvising and matchups, one mechanic per room.
- **The exit room** should only open once every enemy is defeated.

---

## Part 1: Damage and health rebalance

**Kill-time targets** (week 1, level 1 to 2, Normal difficulty). Record them in `data/combat_rules.json` "balanceTargets" so the sim checks them:

| Target | Hits to kill |
| --- | --- |
| Minion | 1 player action |
| Normal enemy | 2 to 3 player actions (a Standard spell or a Strike), or 1 if hit on its weakness and flanked |
| Elite | 5 to 7 player actions |
| Party member (from full HP) | **3 or 4 normal enemy hits**, or **2 telegraphed heavy hits**. A party member who ignores two telegraphs in a row should be in real danger |
| A single normal enemy hit | about 20 to 30% of a party member's max HP |
| A telegraphed heavy or charged hit | about 35 to 50% |
| A boss's big charged attack | about 60 to 80% (must be dodged, blocked by cover, guarded or interrupted) |

**Levers** (all data, no hardcoded numbers):
- Enemy HP: remove the 0.65 enemy HP multiplier (back to 1.0) and raise base HP where needed. Bosses go from x1.5 to whatever hits the targets.
- Enemy damage: replace the stacked telegraph x2.0 and difficulty x2.3 multipliers with clear per-action damage values in enemy data, plus one difficulty multiplier. The current stacking is hard to reason about. The hover preview and threat view must show the real numbers.
- Player damage: lower spell power per Magnitude (for example Minor 4, Standard 7, Major 14, Grand 25) or the Form multipliers, and check the affinity bonus. Strike stays the reliable 0 MP option at about a third of a normal enemy's HP.
- Player HP: keep 20 + CON x4 for now; tune enemies first.

**Healing matters again:** with real incoming damage, Mend, Halo and Shield become valuable. Keep heals at about 25 to 35% of a party member's HP.

**Sim:** `tools/sim_fights.gd` and `tools/sim_arena.gd` report the measured hits-to-kill for each row above, plus win rates for a "reads telegraphs" AI and an "ignores telegraphs" AI. Targets:

| Situation | Win rate |
| --- | --- |
| Reads telegraphs, week 1 normal fights | 85 to 90% |
| Reads telegraphs, week 1 boss | 60 to 70% |
| Ignores telegraphs | under 40% |
| Arena: a full preset party reaches wave 10 | about half the time |
| Arena: a full preset party reaches wave 20 | rarely |

## Part 2: Telegraph timing, and enemies that move and attack

- **Just-in-time telegraphs:** an enemy reveals its intent at the start of the **last party turn before its own turn** in the timeline. Enemies that act back-to-back all reveal during the same preceding party turn. On its own turn, the enemy **carries it out immediately**. No telegraph sits on the board across several party turns, except boss charge-ups, which keep their one-turn charge with a distinct "charging" look.
- **The timeline** marks which party turn is "the last chance" before each enemy acts (a small red link between the portraits), and the turn banner says "Kelly's turn: 2 enemies act next".
- **Enemies move and attack** on their turn. This is now the default for every difficulty; the Hard setting raises damage and HP instead. The telegraph shows the **whole plan:** a dotted move arrow to the tile it will move to, and the red tiles it will hit from there.
  - **Dodge:** leave the red tiles.
  - **Block:** stand or place a Construct, crate or body in its path. If it can't reach its planned tile, it attacks from where it ends up if it can (re-aimed at the same target, shown when the path is blocked), or it loses the attack.
  - **Disable:** kill, root (stops the move), push (moves the plan), blind (miss chance), or cancel it (Light on a charge).
- **Tracking attacks** stay rare (single target, can't be dodged by moving). Guard and cover are the answers to them.
- Re-check the AI's stagger rule so several enemies acting in a row don't all pick the same tile.

## Part 2b: Whose turn is it?

User note (Oct 25): it should always be obvious whose turn it is.

- **Spotlight the active unit:** during any unit's turn, every other unit is **dimmed and desaturated** (about 55% brightness, half saturation). The active unit stays full color with:
  - a pulsing ring under its feet;
  - a small bob or idle animation;
  - its name and portrait in a banner at the top ("Quill's turn").
- **Readable information stays bright:** enemy intent icons, telegraph tiles, move arrows, HP bars, status icons and cover icons are **never dimmed**, so telegraphs are still easy to read while units are greyed out.
- **The hand belongs to someone:** the hand area shows the active character's portrait and name. Each character's cards keep a thin border in that character's color, so it's clear whose cards they are.
- **Round progress:**
  - Units that have **already acted this round** get a small check mark and stay slightly darker than units still waiting.
  - In the timeline, past turns are faded, the current portrait is enlarged and outlined, and upcoming ones are normal.
  - The red "last chance" link from Part 2 marks the party turn right before each enemy acts.
- **Enemy turns:** the acting enemy is spotlit the same way (everyone else dimmed) while its move and attack play out. Then the spotlight moves to the next unit with a short slide in the timeline.
- **Transitions:** a quick (about 0.2 s) dim/undim fade, with a soft sound cue when a party member's turn starts (sound event id `turn_start_party`) and a different one for enemies (`turn_start_enemy`).
- **Settings:** dimming strength and an option to turn it off live in `data/ui.json` (and the Options menu later). Colors and the ring go through asset ids and UI colors.

## Part 3: Cover that matters

Cover becomes **directional:**
- **Half cover:** cover tiles, crates and low walls. A unit standing next to it is protected from attacks that come from the far side, measured by the attacker's position across the cover. They take **x0.5** from ranged and area attacks and **x0.75** from melee over the cover.
- **Full cover:** walls block line of sight entirely.
- **Telegraphs respect cover:** a telegraphed ranged or area attack against a unit in cover (relative to the attacker's planned position) deals half. **Hiding** is a third answer to a telegraph, besides dodging and killing.
- **Flanking ignores cover:** attacking from the side or behind ignores it, which gives Rogues and movement cards a real job.
- **Breaking cover:** cover has HP (crates 8, low walls 15). Force pushes and Heavy Swing break it; Heat burns crates. Pushing a unit into cover deals collision damage.
- **Enemy AI uses cover:** snipers and casters move to cover, and chargers and flankers try to get around it.
- **UI:**
  - A shield icon on a unit that is in cover against the hovered attacker (full or half).
  - The hover preview shows "in cover: x0.5".
  - A cover outline on tiles when choosing where to move.
- More cover in layouts: every combat layout gets 3 to 6 cover pieces, and some arena hazard sets add destructible cover.

## Part 4: Hand size 3, and cards that make sense

- **Hand:** opening hand 3, and at the start of each of your turns **draw back up to 3** (hand limit 3). Strike and Guard are always available as buttons, never dead cards, so you're never stuck. Remove them from starting decks and replace them with class cards.
- **Cycling:** once per turn, as a free action, you may **discard 1 card to draw 1** (this costs 1 MP, so it isn't free fishing). The Mage's improvise still discards as fuel.
- **Fatigue** stays as-is (reshuffle damage). Retune deck sizes (minimum 8) so a deck lasts about a fight and a half.
- **Movement cards** (Dash, Afterimage, Tailwind, Haste or any "+Movement"):
  - Played **before moving** this turn: applies **now**. The hover preview shows the bigger reachable area.
  - Played **after moving or acting**: **carries over to your next turn** (a "+2 next turn" chip on the unit). The card text says so: "+2 Movement this turn, or next turn if you've already moved."
  - Never silently wasted. If a card would have no effect at all, it's greyed out with the reason.
- **Card text audit:** every card's one-line text states exactly when it applies and what it does. Add a test that every card's text mentions its timing words when it has a timing rule.

## Part 5: Class roles

Every class needs a clear job under move-or-act, real damage options, and a reason to be on the board. Rebuild the starting decks in `data/classes.json` (8 to 10 cards each, Strike and Guard as buttons) and add any new cards to `data/cards/`.

| Class | Role | How it plays | Starting deck direction |
| --- | --- | --- | --- |
| **Rogue (Quill)** | Skirmisher and assassin: moves **and** hits | His attacks carry movement: hit and run, teleport-strike, dash-stab. Flanking ignores cover and triggers Backstab | **Hit and Run** (Strike, then move 2), **Shadow Step** (teleport behind an enemy within 3 and Strike), **Quick Stab** (quick, small hit to an adjacent enemy), **Lunge**, **Throw** (ranged, cheap), **Smoke Bomb** (blind adjacent enemies, then move 1), 1 Dash (with the new timing rule), 1 Bolt. At most 2 pure movement cards |
| **Healer (Sage)** | Protector: stops damage before it lands, then heals | Reads telegraphs and acts first: shields the target of a big hit, pulls an ally out of red tiles, makes a safe zone, taunts an attack onto herself. She needs Movement and a way to defend herself | **Ward** (Shield an ally; double strength against a telegraphed attack), **Mend** (heal about 30%), **Guiding Light** (pull an ally up to 3 tiles toward her), **Sanctuary** (Minor Aura: allies inside take x0.5 telegraphed damage this round), **Beacon** (taunt), **Sunbeam** (a Light Line that pierces and blinds; her damage option), **Cleanse** (remove statuses, quick) |
| **Fighter (Brick)** | Front line: holds space and soaks | Stands in enemy paths to block moves, takes hits for allies, breaks cover | **Intercept** (quick: take the next attack aimed at an adjacent ally), **Heavy Swing** (breaks cover), **Shove**, **Lunge**, **Brace**, **Parry**, **Taunt**, Weapon Infusion |
| **Mage (Ash)** | Area and control: glass cannon | Shapes the field: hazards, pushes, interrupts. Fragile, so cover matters most for her | Two Vectors' Bolts, a Minor Burst, a Line, a control card per Vector (Freeze, Shove, Root...), Blink. Owns the Vector Wheel (Overchannel) |
| **Bard (Lyric)** | Tempo: makes allies' turns better | **Haste** lets an ally **move and act** next turn, which is the most valuable effect under move-or-act. Also buffs, blinds and the turn order | Haste, Tailwind, Dazzle, Rally, **Encore** (an ally who already acted this round gets a second action at half effect, once per fight), Bolt |

- Each class's role, how it plays and its deck go into `docs/MECHANICS.md` Part B10.
- The arena preset party uses the new decks.
- **Sim check:** in the arena sim, every class deals at least 15% of the party's total damage, or prevents an equivalent amount (healing, shielding, interrupts). No class should spend more than 40% of its turns only moving.

## Part 6: The exit opens only after every fight

- **The exit room is sealed** until every combat and elite room on the floor is cleared. A counter on the HUD and the exit door ("3 fights left") shows the progress.
- **Fleeing** from a fight leaves that room uncleared; you must go back and win it before leaving. Fled enemies still get stronger on Friday as before.
- **Treasure, rest, event and merchant rooms** are optional.
- **Boss floors:** the exit opens after the boss.
- **The Arena** is unaffected.
- This replaces the old "leave as soon as you find the exit" rule. Update DESIGN.md Section 10 and MECHANICS.md C7.

---

## Part 7: The combat tutorial floor (week 1, Monday night, with Kelly)

Replace the current one-fight Monday evening (`data/story/week1_monday.json` "w1_evening": two Detention Slips) with an **authored tutorial floor**. Each room teaches **one** mechanic, so the player learns combat step by step with Kelly as a guest ally and the narrator as teacher. It must still run the **Kelly Risk** story (help calls, the shortcut, the lantern) and end at the panic moment. Total length is about 25 to 35 minutes, and each fight is short.

**How it's built:**
- An authored floor in `data/story/tutorial_floor.json`: a fixed room map, and for each room its layout, enemies, starting positions, allowed actions and cards, lesson steps, and win condition.
- **Lesson steps:**
  - Narrator lines, sometimes Kelly lines.
  - Highlights on the UI element being taught (the hand, MP bar, a telegraph, the timeline).
  - "Wait until" conditions (the player moved, the player dodged, a card was hovered).
  - Gentle hints if the player is stuck for 20 seconds.
- **The UI unlocks gradually:** the hand is hidden until room 4, the Vector Wheel until room 9, the threat view until room 10. Hidden elements are greyed out, not removed, so the layout doesn't jump around.
- **Fair first lessons:** no crits, misses or Instability failures until the lesson that teaches them. Tutorial enemies use simple, predictable AI.
- **The UI-unlock and lesson system is reusable:** the same lesson steps will drive the day-one town tutorial (roadmap M15) and a later "Combat Practice" menu (title screen > Arena > Practice) that replays any room.
- **Skip on later runs:** once the floor is cleared in any run, later runs offer "Skip the lessons" (fights stay, prompts go). Tracked in the Narrator's Journal.
- **All text is data:** room names, narrator and Kelly lines live in data and strings, so the user can rewrite the story around it. The user is writing the day-one story; keep every story line easy to find and replace (prefix keys `tut_`).

**The rooms.** All layouts are small (7x5 or 9x5) with hand-placed enemies. Kelly (a Bard guest with Light and Force) acts on her own and demonstrates things.

| # | Room | Teaches | Setup and win condition | Kelly and the story |
| --- | --- | --- | --- | --- |
| 0 | **The Hallway That Isn't** (no fight) | Walking the floor, the room map, interacting, rooms you can see but haven't cleared, the sealed exit with its counter | A lantern on the floor | **Lantern choice** (existing Kelly Risk: letting her carry it or not). The narrator explains the exit is sealed until every fight is won |
| 1 | **First Contact** | The grid, initiative order, **move OR act**, **Strike** | 1 minion (Detention Slip), 2 tiles away. Win by defeating it | Kelly watches: "Hit it. With your... hands?" The narrator explains you can either move or act each turn |
| 2 | **The Red Tiles** | **Telegraphs:** reading the red tiles and dodging by moving | 1 enemy with a slow, obvious attack and enough HP that you can't kill it in one turn. You must step out of the red first, then Strike next turn. Win by defeating it | If the player stays in the red, the hit lands for real but can't kill (tutorial HP floor) and the narrator mocks gently |
| 3 | **Brace Yourself** | **Guard**, and tracking attacks you can't dodge | 1 enemy with a tracking attack (different icon). Moving doesn't help, so Guard halves it. Win by defeating it | Kelly gets hit first and complains loudly |
| 4 | **Cards on the Table** | **The hand (3 cards)**, **MP**, **hover previews**, spells at range, **area of effect** | 2 minions behind a gap Strike can't reach. Your hand is revealed: a Bolt and a Minor Burst. Hovering shows range and area. Win by defeating both | The narrator walks through hovering a card before playing it. MP is pointed out ("This doesn't come back tonight. Budget.") |
| 5 | **Weak Spots** | **Typing:** weak and strong matchups | 2 enemies: one weak to your spark or class Vector (x1.5, "Weak!" popup), one strong against it (x0.6). Their icons are highlighted. Win by defeating both | Kelly's Light hits the one you can't. The narrator nudges you to let teammates cover your weaknesses |
| 6 | **Walls and Cover** | **Line of sight**, **walls**, **cover** (directional) and **flanking** | A sniper behind cover across a wall. Bolts are blocked or halved; you must go around and flank, or hide in your own cover from its telegraph. Win by defeating it | The narrator: "Hiding counts as a strategy. Ask any teenager." |
| — | **Rest Room** (no fight) | Room types: rest (restores MP), treasure chest, Vector shards | A campfire and a chest | **Shortcut choice** right after: Kelly begs you not to take the dark shortcut (existing Kelly Risk). The shortcut skips room 7 but adds Risk |
| 7 | **Hot Floor** | **Hazards** (burning tiles), **push**, **collisions**, and making enemies hit each other | A Shove card in hand. Burning tiles between you and 2 enemies; one enemy's telegraph covers the other's tile. Win by defeating both. Bonus line if you push one into fire or into the other's attack | Kelly demonstrates a Force push first |
| 8 | **Quick Thinking** | **Quick cards** (1 per turn), **movement cards** (Dash before moving), and protecting an ally | An enemy charges Kelly from across the room (a charge-up). You must Dash and then move to reach it, or use Kelly's blind to cancel it (interrupts) | **Kelly's help call** (existing Kelly Risk: help ignored +2, helping −2). Teaches interrupts: Light cancels a charge |
| 9 | **Off the Script** | **Improvising** (the Vector Wheel), Instability, discarding as fuel | Your hand is all wrong for this enemy (it resists everything in it). The narrator gives you the Vector Wheel and the first improvise is guaranteed to succeed. Instability chance and fuel are explained. Win by defeating it | The narrator: "Prepared magic is a speech. Improvising is yelling." |
| 10 | **The Whole Mess** | **Enemy types** working together (a charger, a healer, minions), **priority**, the **threat view** | A small mixed group: kill the healer first, dodge the charger's line, clear minions with an area spell. The threat view is unlocked and explained. Win by defeating all | Kelly's **panic moment** follows the fight (the existing Kelly Risk check). At Risk 4 or more: the collapse and run-ending scene. Otherwise she steadies and you leave together |
| — | **Exit** | The exit opening once every fight is won | The door unseals with a sound and the counter hits 0 | The narrator closes the night |

- If the player took the shortcut, room 7 is skipped. Its lesson (push and hazards) moves into room 10 as a hint line.
- **Data and art:** every room's layout, enemy list, prompts and win condition are data. Tutorial enemies reuse week 1 sprites through asset ids. Lesson highlight frames and icons are asset ids too.
- **Tests:**
  - Each room's win condition.
  - The UI unlock sequence.
  - The shortcut branch.
  - Kelly Risk changes per choice.
  - Guaranteed success on the first improvise.
  - The exit staying sealed until every fight is won.
- **Smoke test:** an autoplay run through the whole floor (both shortcut branches) with no errors.

---

## Done when

- The sim measures the Part 1 kill-time targets and they hold (in PROGRESS.md).
- Enemies telegraph right before their turn, then move and attack, and the telegraph shows the path and the red tiles.
- During every turn only the active unit is in full color (everyone else dimmed, telegraphs and icons still bright), the hand shows whose cards they are, and units that already acted this round are marked.
- Directional cover halves telegraphed ranged and area hits, and flanking ignores it.
- Hands are 3 cards with Strike and Guard as buttons.
- Dash and other movement cards apply now or next turn and are never wasted.
- Quill and Sage play their new roles in the arena: the sim shows each class at 15% or more of damage dealt or prevented, and no class spends more than 40% of its turns only moving.
- The exit stays sealed until every fight on the floor is won.
- The 10-room tutorial floor plays from Monday evening with Kelly, teaching one mechanic per room, with the Kelly Risk choices and panic moment intact.
- `docs/MECHANICS.md` is updated for every change.
- Screenshots of a just-in-time telegraph with a move arrow, cover icons, the 3-card hand, and tutorial rooms 2, 6 and 9 are in `tools/screenshots/`.
