# Town Life, Skipping Class and Gear (separate milestone: TL)

This is a **separate milestone, TL**, outside `docs/ROADMAP.md`. Don't renumber or edit the roadmap for it. Track it as its own row ("TL Town life, skipping and gear") in `docs/PROGRESS.md` and commit it as "TL: Part N ...".

**Order (user request, Oct 29):**
1. Finish M23 if anything is left.
2. Then **TL**, Parts 1 to 7 in order.
3. Then **AC** (`docs/ARENA_CAMPFIRE.md`). TL's gear system (Part 4) is what the campfire's blacksmith stall will open into later.

Where this doc changes an earlier rule, this doc wins. Update `docs/MECHANICS.md`, `docs/TOWN.md` and `docs/DEMO_CHECKLIST.md` as you go. All content goes in data, all art and audio go by asset id, and all text goes in strings.

---

## Why (audit, Oct 29, code at M23)

All 4,144 core checks and the 48-screen UI audit pass, so this is about content and design gaps, not crashes.

1. **Skipping class gives nothing.**
   - What exists: `School.skip()` costs grade (-5) and counts toward detention, and `Flow` grants 2 AP (`skipAp`).
   - What's missing: no location in `data/town/locations.json` lists `period_1`, `period_2` or `period_3` in its hours. No NPC in `data/npcs/*.json` has a schedule for those parts. `data/town/crowd.json` spawns nobody during them.
   - Result: you get 2 AP in an empty town where only the park, the square, the bus stops and the like are open.
2. **Gear exists but is invisible:**
   - **Slots and items:** 3 slots (weapon, armor, trinket) and 10 items.
   - **Armor:** gives only +1 to +3 flat physical defense.
   - **Weapons:** only add Strike damage.
   - **Equipping:** gear auto-equips from the shop, and there's no equipment screen for party members.
   - **The blacksmith:** sells this and nothing else.
3. **The town is thin:**
   - 5 weekly town stories in `data/story/town_events.json`;
   - 3 crowd favors;
   - 11 CLOSED places with nothing behind them;
   - 31 EXTERIOR houses that can't be visited.
4. **Smaller gaps** (from PROGRESS.md and DEMO_CHECKLIST.md):
   - the week 1 friendship scene is missing;
   - there are no scene fade transitions;
   - Binding tethers, hidden enemies and party combos at Close Bond aren't built.

---

## Part 1: The town during school hours

**The goal:** skipping a class is a real choice. You trade the class's stat gain and grade for something you can only get while everyone else is in school.

- **New "school hours" day parts in data:**
  - Locations get `period_1`, `period_2` and `period_3` in their `hours` where it makes sense: Gary's Deli, the library (adults only, with Ms. Marlowe raising an eyebrow), the hospital, the forge, the corner store, the post office, town hall, the arcade (period 3 only), the park, the town square and the bus stops.
  - School rooms are closed during class, except the hallways, which become a sneaking area (Part 2).
  - **Data cleanup:** add a `"schoolHours"` group to `data/calendar.json` (`["period_1", "period_2", "period_3"]`) so data can say `"hours": ["@schoolHours"]` instead of listing each part.
- **Daytime NPC schedules:**
  - **Existing adults:** these get `period_X` entries: Gary, the blacksmith, Patti, Dr. Reyes, the mayor, Mr. B (who checks attendance from the admin office), Ms. Marlowe, the innocent bystander and the parent (home on some days).
  - **The narrator:** sits in the park.
- **New daytime characters:** 4 to 6 small NPCs, data-only like the existing ones, with schedules, topics, a Bond track and 2 to 3 personal scenes each:
  - **Officer Dana Pruitt, the truant officer:** patrols during school hours (Part 2).
  - **A dropout who works the corner store:** knows the Upside-Down rumors nobody at school will say out loud.
  - **A retiree in the park:** feeds pigeons and knew the town before the fountain. Mystery lore.
  - **A delivery driver:** routes through all four zones. Gives cross-town errands (Part 3).
  - **A substitute teacher on a "break":** sympathetic, and might cover for you.
  - **Optional:** a homeschooled kid who only exists in daytime, as a recruitable party member later.

  **Names and dossiers:** names are placeholders; follow the style of `docs/characters.md`. Write a short dossier for each in `docs/characters.md` under "Daytime townsfolk".
- **The daytime crowd:** add `period_X` entries to `crowd.json` `spawn`: few students, mostly adults, and a few "also skipping" students who have their own barks.
- **Daytime-only things to do:**
  - **Deli lunch rush (period 2):** help Gary for money and Gary Bond (a quick minigame, reusing an existing one).
  - **Forge apprentice shifts (periods 1 to 3):** blacksmith Bond and ore. This is the path to better gear tiers (Part 4).
  - **Library archives:** only Ms. Marlowe is there, so the town history shelf is open. These are mystery board leads (M18 `mystery.gd`) found only here.
  - **Town hall:** public records. More leads, and the mayor's secrets.
  - **Hospital:** visit injured friends. A Bond bonus, and they heal faster.
  - **Empty school spots:** the roof, the boiler room and the teachers' lounge can be reached only by sneaking during class (Part 2). They hold secrets, items and story flags.
- **Balance:**
  - Skipping keeps its 2 AP, and visiting school-hours places costs AP as usual.
  - A skip should be worth about one class's stat gain, in a different currency (Bond, money, leads, ore).
  - Tune it with `tools/sim_days.gd`. Add a "skip-heavy" player profile to the sim and record the results in PROGRESS.md.

## Part 2: The cost of getting caught

- **Truancy risk:**
  - Each school-hours action outside the school has a **Spotted** chance, shown before you act ("Risk: low / medium / high").
  - The chance depends on the place (town square high, hidden alley low), whether Officer Pruitt or Mr. B is nearby, and your skips this week.
- **Getting spotted** starts a short scene:
  - **Talk your way out:** a Charisma check, with misheard-line flavor on a fail.
  - **Run:** a short chase minigame.
  - **Take it:** detention later this week, or a call home that costs parent trust.
- **Parent trust:** a new hidden meter.
  - **Low trust:** a curfew, i.e. fewer Night AP.
  - **High trust:** a weekend allowance bonus.
  - It shows on the phone as texts from your parent.
- **Sneaking inside school:**
  - The hallways during class are a sneaking area.
  - Hall monitors and teachers walk patrol routes made from M12 markers.
  - Their vision cones are visible, and being seen sends you to the admin office (Mr. B).
  - This is the route to the roof, the boiler room and the teachers' lounge.
- **Rewards for good attendance:** perfect-attendance streaks give a weekly bonus (+1 stat point or a teacher favor), so attending is also a real choice. Report cards (M16) show attendance.

## Part 3: More town events, favors and places

- **Town events:**
  - Grow `data/story/town_events.json` from 5 stories to **at least 15**, about 3 per week.
  - Mix them:
    - stories that react to the Upside-Down signature (the existing kind);
    - slice-of-life (a broken-down truck, a lost dog, an arcade high-score battle);
    - daytime-only events (Part 1).
  - Each has a choice with consequences: Bond, money, leads, or Shifting the week's signature.
- **The favor board:**
  - A corkboard at the post office and the deli lists **15 to 20 small jobs** in `data/town/favors.json`: deliveries, finding items, fixing things, tutoring.
  - Jobs have hours (some daytime only), an AP cost, a reward, and an NPC they help.
  - The board refreshes weekly.
  - Some jobs give gear materials (Part 4).
  - The delivery driver hands out cross-town errands.
- **Opening CLOSED places:** open at least 4 as story or weekend locations, with hooks that already exist in data:
  - **Train station:** opens week 3. A traveling vendor with rare trinkets; a mystery lead.
  - **Town museum:** weekends and daytime. A history exhibit with fountain lore, plus a puzzle.
  - **Movie theater:** weekend evenings. A friendship scene spot (2 friends at a time; Bond for both).
  - **The abandoned mansion:** stays locked until the story opens it. Add a "something moved inside" event so players notice it.
- **Visitable houses:** make at least 4 friends' houses visitable (interiors through M12 blocks) at Bond Friend or above. Each has one scene and one item.
- **Weekend activities:**
  - **Farmers market:** Saturday morning at the town square. Ingredients for the deli and a rare trinket stall.
  - **Arcade tournament:** one weekend, against Jon and Dex.
  - **Park pickup game:** with Coach Byrne's team. Gives Strength or Agility.
- **A "morning paper":** a short recap card at Before School, built from the gameplay log, with flavor from the narrator. It shows:
  - what changed in town overnight;
  - new favors;
  - today's open places and events;
  - who's skipping today.

## Part 4: Gear: armor, weapons and the blacksmith

**The goal:** gear is a visible, chosen system for every party member, and the blacksmith is the reason to visit the forge.

- **The Equipment screen:**
  - **Access:** a new tab on the character sheet and the Party panel, available in town, at the arena checkpoint and in the pause menu.
  - **The slots:** each member shows weapon, armor, trinket, and a second trinket at level 6.
  - **Comparing:** hovering an item compares it with what's equipped (green and red stat changes).
  - **Auto-equip:** stop auto-equipping. Buying asks "Equip on whom?" with the owner row from P2 1.3.
- **Armor types:**

  | Type | Effect |
  | --- | --- |
  | Light | +1 Movement or +Dodge |
  | Medium | Balanced Defense |
  | Heavy | High Defense and +Guard shield, -1 Movement, and an Agility requirement or penalty |

  - Armor gives **Physical Defense and Magic Resist**.
  - Some pieces resist a Vector ("Insulated Coat: Cold resistance 25%").
  - Classes have a preferred type that gives a small bonus: Fighter heavy, Rogue light, and so on.
- **Weapons:**
  - **Damage type:** a weapon sets your Strike's damage type and reach: knuckles (adjacent), baton (adjacent, push 1), spear (reach 2), sling (range 3, half damage).
  - **Infusing:** a weapon can carry one Vector infusion, making Strike deal Heat, Cold and so on. Infusions come from the forge.
  - **Card bonuses:** a weapon adds +X to cards with its tag ("blunt", "blade", "thrown").
- **Trinkets:** keep the existing ones. Add trinkets that change rules ("first Quick each fight is free", "+1 card in hand on turn 1", "reflect the first hit each fight").
- **Rarity and tiers:**
  - The rarities are common, uncommon, rare and unique.
  - A unique has its own perk and a story source: Gary's cleaver, the mayor's ceremonial chain, the retiree's old compass.
  - Tiers unlock by week and by **blacksmith Bond**.
- **Ore and materials:**
  - Upside-Down floors and arena waves drop **ore**: iron, frost iron, ember iron, and void glass at Tier 4. Favors and forge shifts give some too.
  - Ore is stored in the backpack (P3).
- **Blacksmith services** (shop tabs at the forge):
  - **Forge:** craft a piece from a recipe (`data/gear_recipes.json`) with ore and money, and a quick hammer-timing minigame. A better score gives better stats.
  - **Upgrade:** take a piece from +0 to +3, with rising cost.
  - **Infuse:** add a Vector to a weapon, or a resistance to armor. Needs that Vector's ore or shards.
  - **Repair:** see durability below.
  - **Commissions:** order a unique piece that's ready in 2 days, a reason to come back.
- **Durability (optional switch in `data/combat_rules.json`, default on for Normal):**
  - Gear loses durability when you go down.
  - At 0, it's broken and gives half its stats until repaired.
  - The blacksmith repairs it cheaply, or free at blacksmith Bond Friend.
- **The arena:**
  - Arena runs use the same gear.
  - The arena merchant sells a small gear stock.
  - The AC campfire's blacksmith stall stays closed until AC is built. It then opens with upgrade and repair, using the services above.
- **Enemies:** some enemies get armor tags that interact: "Armored" from affixes is reduced by blunt weapons, and some enemies hit through light armor. Show this in enemy info.
- **Data and art:**
  - `data/items.json` keeps the gear records (slot, type, defense, magicResist, resist, tags, rarity, tier, mods, perk).
  - Recipes go in `data/gear_recipes.json`.
  - Icons go by asset id: `icon_item_<id>`, with fallback `icon_gear_<slot>_<type>`.
  - Optional: character sprites get a gear tint layer (a palette swap per armor type) so gear is visible on the map and in combat.

## Part 5: Friendship and social content gaps

- **The week 1 friendship scene** (demo blocker): one scripted scene at lunch with Dex or Theo, using the cutscene system. Mark it in DEMO_CHECKLIST.
- **One daytime scene per new character** from Part 1, plus one hangout per Core Four member that only triggers if you skip with them. A "skip with me?" invite comes in by phone.
- **Party combos at Close Bond** (from VD Part 2, not built yet): build them now. The pair's Vectors are cast together and both spend an Action.

## Part 6: Combat stubs to finish

- **Binding tethers:** link two units; damage to one hits both. Includes the Tether and Pact cards from AR.
- **Hidden enemies:** some enemies start hidden; Light's Reveal and the darkness hazard show them. Add 2 enemies that use it.
- **Turret and decoy Constructs:** Constructs that act, as AR planned.

## Part 7: Polish

- **Scene transitions:** fades between scenes and day parts (the last open juice item in DEMO_CHECKLIST).
- **A goal tracker:** a small "What can I do?" panel (pause menu and a HUD hotkey). It lists:
  - open places and who's there now;
  - active favors;
  - mystery leads;
  - Bond scenes ready;
  - gear ready at the forge.
- **The run-end summary:** shows attendance vs skips and what each skip bought (Bond, leads, gear), plus the gear you finished with.

---

## Tests and done when

**Tests:**
- **School hours:**
  - each school-hours location and NPC schedule resolves during `period_X`;
  - skipping lands you in a town with open places and people;
  - the `@schoolHours` alias expands.
- **Getting caught:**
  - Spotted chance by place, nearby NPC and skips;
  - each outcome (talk, run, take it);
  - parent trust effects.
- **Sneaking:** a patrol vision cone catches you; being caught sends you to the office.
- **Favors and events:**
  - favor board refresh and hours;
  - each new town event's choices;
  - the attendance streak bonus.
- **Gear:**
  - the equip and unequip screen logic;
  - "Equip on whom?";
  - armor type effects (Movement, Defense, Magic Resist, resistances);
  - weapon Strike type and reach;
  - infusion;
  - forging with a minigame score;
  - upgrades;
  - durability and repair;
  - blunt vs Armored.
- **Combat stubs:** tethers, hidden units and acting Constructs.
- **Sims:** `tools/sim_days.gd` with the skip-heavy profile and `tools/sim_balance.gd` with gear tiers. Record results in PROGRESS.md.

**Done when:**
- **School hours:**
  - a skipped period has at least 6 open places and at least 8 people;
  - at least 4 daytime-only activities;
  - a real risk of getting caught.
- **Town content:**
  - at least 15 town events and at least 15 favors;
  - 4 CLOSED places opened and 4 houses visitable.
- **Gear:**
  - every party member has an Equipment screen;
  - armor types and weapon types change how you play;
  - the blacksmith forges, upgrades, infuses, repairs and takes commissions.
- **Smaller items:**
  - the week 1 friendship scene, party combos, tethers, hidden enemies and fades are in;
  - the goal tracker works.
- **Screenshots in `tools/screenshots/`:**
  - the town during a skipped period;
  - getting spotted;
  - the Equipment screen;
  - the forge;
  - the favor board;
  - the morning paper.
