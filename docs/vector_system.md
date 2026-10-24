The Vector System
Oct 18, 2026 · @Sam
The Vector system describes anything in the game as a set of weighted axes, so one small toolkit of operations can roll a level-up, resolve a matchup, pick a crafted item and decide how an NPC feels.
The core idea
A vector is a short list of named numbers. Each name is an axis (Heat, Force, Perception, Trust) and each number is a weight on that axis. That is all a vector is. The game gets its depth from using the same shape everywhere, so a small toolkit of operations (see The operations) works on a character's talents, a spell, a crafted item, an enemy and an NPC's opinion of you.
{ "heat": 12, "force": 4 }
That one object can mean three different things depending on the field that holds it:
Reading
The numbers mean
Example
Amount
How much has been invested or earned
Research input of Heat 12 and Force 4
Affinity
How likely each axis is to come up
A mage's level-up table: Heat 20%, Cold 20%, Force 15%
Signature
The ideal profile of a thing, where only the proportions matter
The property Searing Edge is 70% Heat and 30% Force
Every vector has two properties worth keeping apart. Its direction is what kind of thing it is, the proportions between axes. Its magnitude is how much of it there is. A Minor Heat spell and a Grand Heat spell point in the same direction and differ only in magnitude. Keeping the two apart is what lets one system answer "what kind?" and "how strong?" separately, and it is why matching uses direction and scaling uses magnitude.
Rules every vector follows
• A vector belongs to a space. A space is a named, fixed set of axes (the elemental Vectors, the six stats, the opinion axes). Operations combine vectors only inside one space, or through an explicit mapping between two spaces.
• A missing axis is zero. Vectors are stored sparsely as axis: number, and an axis that is not listed does not exist for that entity.
• A vector is plain data. It carries no behavior. All behavior lives in the operations that read it, which is what makes the whole system moddable: adding an axis or a new entity is a data change.
• Each field says whether it is raw or normalized. Raw vectors hold amounts. Normalized vectors are scaled so the weights sum to 1 (for probabilities) or have length 1 (for matching). Converting is an operation, never an assumption.
• Weights are not negative, except in signed spaces. Opinion and mood spaces run from -100 to +100 on purpose. Every other space starts at zero.
• Ceilings come from outside the vector. A Knowledge Tier caps how high an axis or Magnitude can go. The cap is a rule applied to the vector, not a number stored in it.
Why one shape for everything
• One engine. Level-ups, crafting, matchups and AI choices reuse the same few functions, so a fix or a balance change lands everywhere.
• Variety without hand-authoring. Two characters or two crafted items differ because their vectors differ, not because someone wrote both.
• Legible. Any vector can be shown as a row of bars, so a player can read what a character, spell or enemy is made of at a glance.
• Open to extension. A new axis, such as Dimensional magic at Knowledge Tier 4, is a line of data and a new entry in the matchup table.
The spaces
A space is a named set of axes. The game uses a handful, and the most important is the Vector space of magic, because its axes (Heat, Cold, Force and so on) are reused outside magic: in crafting, in enemy weaknesses and in what a character grows into. When a new thing needs describing, the first question is which existing space it belongs to.
Space
Axes
Range
Reading
Status
Magic Vectors
Tier 1: Heat, Cold, Force, Motion. Tier 2: Binding, Light. Tier 3: Transmutation, Vitality, Corrosion
0 and up
Amount (invested), affinity (growth odds), signature (what a property or spell is)
Designed. The beta gives a mage one fixed Vector
Forms
Bolt, Burst, Shield, Weapon Infusion, then Line, Sphere, Projectile, Touch, Aura, Construct, Glyph
0 and up
Affinity (which Forms a caster tends to learn)
Designed
Stats
STR, CON, DEX, INT, PER, WIL
3 to 15 in the beta
Amount
Built
Talents and skills
One axis per talent or skill
Talents are table weights; skills 0 and up
Affinity for talents, amount for skills
Built (talents), designed (skills)
Material attributes
Hardness, Weight, Conductivity, Magic Affinity, Corrosion Resistance
1 to 10
Amount
Designed
Property signatures
The Magic Vector axes
Proportions only
Signature
Designed, with a standalone minigame prototype
Threat and weakness
The Magic Vector axes, plus a single Threat Rating for size
Weakness lists in the beta
Signature (what it is weak or strong to), amount (how big)
Built as lists, designed as a matchup table
Bond
One signed axis per pair of characters
-100 to +100
Amount
Built
Standing
One axis per faction
0 to 1000
Amount
Designed (diplomacy)
Realm and biome flavor
The Magic Vector axes
Proportions only
Signature (which magic is strong here)
Proposed
NPC disposition
Axes such as Courage, Greed, Curiosity, Loyalty
-100 to +100
Amount
Proposed
The shared axes are the glue. Heat is the same axis whether it appears in a mage's growth table, a crafted item's property, an enemy's weakness or the minigame the Research Bench picks. That is why a character who specializes in Heat produces Heat-signature items and is strong against Binding and organic-armored enemies, without any rule connecting those three facts. They connect because they all read the same axis.
Mappings between spaces are explicit and few, and each is a data table:
• Class to affinity. A class and specialization name a Vector Affinity Table and a Form Affinity Table.
• Dominant Vector to minigame. The axis with the largest input picks the archetype: Heat or Cold plays as Thermal, Force or Motion as Precision, Binding or Light as Alignment, and the Tier 3 axes as Chemical.
• Material to magic. A material's Magic Affinity scales how much of a Vector input becomes Instability risk or effect strength. It is a multiplier from one space applied to another, never a new axis.
• Trait to every space. A trait is a small edit to one or more vectors (a trait that adds +10% to the chance of a new unlock, a trait that adds to CON). The trait list is the edit list.
The operations
Eight operations cover every use in the game. Each is a pure function: it takes vectors and returns a number or a new vector, changes nothing, and draws randomness only from the seeded RNG that is passed in. That makes every result reproducible in a test.
Operation
Takes
Returns
Used for
Normalize
A raw vector
The same direction, scaled to sum 1 (odds) or length 1 (matching)
Turning amounts into probabilities, preparing a match
Sample
A probability vector and the RNG
One axis, chosen by weight
Level-up rolls, trait draws, picking a crafted property
Match
Two vectors
A similarity from 0 to 1
Choosing which item properties fit an input, scoring a squad against a target
Blend
Vectors and weights
One combined vector
Adding a specialization to a base table, applying a trait, combining research inputs
Shift
A vector and a change
The vector moved, then capped
Growth, training, a mentor's influence
Contest
An attacker vector, a defender vector and a matchup table
A multiplier
Spell against enemy, Combat Power repertoire bonus
Gate
A vector and a threshold list
Yes or no, or a tier
Property eligibility, Magnitude caps, bond tiers
Decay
A vector, a rate and a resting value
The vector drifted toward rest
Bonds that fade, grief wearing off, standing that cools
The formulas:
\hat{v}_i = \frac{v_i}{\sum_j v_j} \qquad
\text{Match}(a, b) = \frac{a \cdot b}{\lVert a \rVert \, \lVert b \rVert} \qquad
c = \alpha a + \beta b

P(\text{axis } i) = \hat{v}_i \qquad
v_i \leftarrow \min\left(v_i + \Delta_i,\ cap_i\right) \qquad
v \leftarrow v + r\,(rest - v)

Contest(a, d) = \sum_i a_i \cdot m(i, d), \quad m \in \{1.5, 1.0, 0.6\} \qquad
Gate(v) = \bigwedge_i \left( v_i \ge t_i \right)
How each operation behaves
• Normalize. Two ways to scale, for two jobs. Divide by the sum when the numbers become odds. Divide by the length when only direction matters. A vector with all zeros cannot be normalized, so callers treat it as "no preference" and fall back to a default table.
• Sample. Draw a number from 0 to 1 from the RNG and walk the cumulative weights. Sampling without repeats removes the chosen axis and renormalizes the rest. A pity rule narrows the draw: after enough rolls with nothing new, only axes the character does not yet have stay in the table, so the roll still picks which one but not whether.
• Match. Cosine similarity compares direction and ignores size, so 12 Heat and 4 Force matches a property signature of 70% Heat and 30% Force exactly as well as 120 Heat and 40 Force. For vectors with no negative weights the result runs from 0 (nothing in common) to 1 (identical proportions). Size is handled separately, by a Gate or by Magnitude.
• Blend. Add the weighted vectors, then normalize if the result is used as odds. Specializations and traits are blends: they add a small vector onto the base one.
• Shift. Growth adds a small change to chosen axes and applies the cap. A change to an affinity table is renormalized afterward so the odds still sum to 1.
• Contest. The matchup table gives a multiplier for each pair of an attacker axis and a defender trait. A multi-axis attacker's result is the sum of its axes, each multiplied by its matchup. Because the table is data, a new Vector needs a new row and column and no code.
• Gate. A hard line. Below it the thing is not eligible, whatever its score. Tiers are a Gate with several lines: Magnitude steps (Minor 5, Standard 10, Major 20, Grand 35), bond tiers (Stranger through Unbreakable Bond), and Knowledge Tier caps.
• Decay. Moves a value a fraction of the way toward a resting value each period. Bonds rest at 0 and, once at 86 or more, stop decaying, which is a Gate that switches the operation off.
Two derived measures come up often and are worth naming. Total is the sum of a vector's weights, the amount invested. Spread is the number of axes with weight above zero. The invention design combines them as a complexity score, Complexity = total / 10 + (spread - 1) x 3, so adding more points and adding more axes both make a project harder. A dominant axis is the axis with the largest weight, and it selects an archetype, such as which crafting minigame to play.
How one vector feeds many systems
Every space on the left is a vector, every system on the right reads the result of the same small set of operations, and nothing in the middle knows which space it is working on.
Applications
Each application below says what the vector is, which operations act on it, and whether it is already designed or only proposed.
Magic
A spell is a choice of one Vector, one Form and one Magnitude. In vector terms it is a unit direction on the Vector axes (usually a single axis, or a blend of two for a hybrid) scaled by a Magnitude value of 5, 10, 20 or 35.
• Gate: the caster's Knowledge Tier decides which axes and Forms exist for them and the highest Magnitude they can pick. A Tier 2 caster cannot choose Grand.
• Contest: the matchup table turns a spell and an enemy into a multiplier of 1.5, 1.0 or 0.6. Summed over a caster's equipped spells, this is the repertoire bonus in Combat Power.
• Sample and Shift: a caster learns Vectors and Forms through weighted level-up rolls, and the Breakthrough roll raises the Magnitude of whichever Vector and Form pair they have used most.
• Instability: the share of the caster's Focus Points spent in one cast is compared with a Stability Roll. This is a Gate whose line moves with the cost of the spell.
• Wild Surge: the worst failure result is a Sample from the whole Vector space with equal weights, which is why it can help or hurt.
Characters
A character is a bundle of vectors: six stats, a skill list, a talent table, and for casters a Vector table and a Form table. A class is a template of weights. A trait is a small edit to some of those vectors. A specialization is a blend added onto the class's tables.
• Generation spends a point budget one point at a time with Sample, where each stat's weight is the class priority times the background's nudge. Rarity changes the budget and the number of traits, never the weights.
• Growth is Shift (stat points) and Sample (a talent, a Vector or a Form from the affinity table), with pity as a narrowing of the table.
• Specialization is Blend: a Kinetic Logician's table is the base mage table plus +15 Force and +15 Motion, renormalized.
• Mentorship is a small Blend of the mentor's strongest axes into the apprentice's table, earned through a bond.
• History is a usage vector. Counting how often each Vector and Form pair is cast gives the pairUses vector, and its dominant axis is where the next Breakthrough lands.
• Sheet: any of these vectors can be shown as a row of bars, which is the Growth tab.
Squads
A squad's combined Vector amounts are the sum of its members' vectors, and a squad is judged by how much of an enemy's weak axes it can reach. One caster with 100 Heat is strong against enemies weak to Heat and weak against everything else. Three casters with Heat, Cold and Force cover three matchup rows. This is the reason to mix Vectors in a squad. Bond tiers between pairs feed the same squad calculation as a synergy modifier.
NPCs and enemies
• Enemies have a single size (Threat Rating, in Combat Power units) and a signature: the Vector axes they are weak to and strong against. A Contest between the squad's vector and the enemy's signature gives the effective Squad Power for that fight. Designed. The beta stores weakness and resistance as lists.
• NPC disposition (proposed): a signed vector over a few axes such as Courage, Greed, Curiosity and Loyalty. Each possible action carries a profile vector, and the NPC chooses with Sample over base weight x Match(disposition, profile). A high-Courage caster is more willing to risk an Instability cast, and a Greedy trader raises prices, with no per-NPC scripting. Disposition changes by Shift when events happen and Decay returns it toward the NPC's resting personality.
• Factions hold a Standing from 0 to 1000 per faction. Gate lines turn the number into the pipeline stages Contact, Embassy, Trade Route, Alliance, Colony and Province. Designed.
Items and crafting
The invention system is the Vector system used end to end:
1. Input is a raw vector of Vector points plus Research Points.
2. Total, Spread and the dominant axis give a Complexity score and choose the minigame archetype.
3. Performance, a score from 0 to 1 from the minigame, scales the rolls.
4. The Property Bank lists every possible property with a signature vector, a weight and a Gate of minimum points. Properties that pass the Gate are weighted by weight x Match(input, signature) x (1 + Performance).
5. Sample picks 1 + floor(Performance x 3) + floor(ResearchPoints / 25) properties without repeats. Their tier comes from Complexity and rises by one on a high Performance, capped by Knowledge Tier.
6. Materials add attributes (Hardness, Magic Affinity) that scale the result. They are multipliers, not extra axes.
The same Property Bank serves weapons, armor, tools and buildings, so a Farm Plot can roll Bountiful from the same table that gives a sword Searing Edge.
Realms, biomes and the world
• Biome density is already a vector. A zone lists how common each resource and enemy is, and each tile Samples from it. Built into the world design.
• Realm flavor (proposed): each realm and zone carries a signature over the Vector axes. Enemies and resources that appear there are weighted by Match with that signature, and a spell whose Vector the realm opposes gets the 0.6 matchup multiplier. This makes Heat magic feel different in a cold realm without any special-case code, and gives each realm a reason to bring a different squad.
• Knowledge Fragments are a vector over the endgame's required axes. Their sum is how close the Ascension Engine is to complete.
Bonds
The simplest use. A bond is a one-axis signed vector between two characters from -100 to +100. Shift changes it after missions and events, Decay pulls it toward 0, and Gate lines turn it into tiers that modify squad synergy. A richer version (proposed) gives each pair several axes such as Trust, Respect and Fear, so a rivalry and a friendship can coexist.
Worked examples
The numbers below use the operations defined above. Where a value is a placeholder for the example, it is marked.
1. A specialization changes a mage's growth table (Blend, Normalize, Sample)
A base mage has this Vector table of raw weights: Heat 20, Cold 20, Force 15, Motion 15, Binding 15, Light 15. The total is 100. The character picks the Kinetic Logician specialization, which adds Force +15 and Motion +15.
• Blend: Force becomes 30 and Motion becomes 30. The total is now 130.
• Normalize: divide every weight by 130.
Axis
Before
After
Heat
20.0%
15.4%
Cold
20.0%
15.4%
Force
15.0%
23.1%
Motion
15.0%
23.1%
Binding
15.0%
11.5%
Light
15.0%
11.5%
The next time the character rolls to learn a Vector, Sample draws from the new table. Force is now 30/20 = 1.5 times as likely as Heat, and Binding and Light are less likely than before, even though nothing was removed. The specialization steered the character without closing any door.
2. An invention picks its properties (Match, Gate, Sample)
The player spends 12 Heat and 4 Force at the Research Bench, scores 0.5 on the minigame, and has 30 Research Points.
• Total is 16 and the number of distinct axes is 2, so Complexity = 16/10 + (2 - 1) x 3 = 4.6.
• Dominant axis is Heat, so the Thermal minigame was the one played.
• Match is the cosine similarity between the input (12, 4) and each property's signature. Three sample properties (signatures and weights are placeholders):
Property
Signature
Gate
Cosine
Weight x Cosine x (1 + 0.5)
Searing Edge
Heat 0.7, Force 0.3
Heat 5
0.997
1.0 x 0.997 x 1.5 = 1.495
Keen Balance
Force 0.6, Motion 0.4
Force 4
0.263
0.8 x 0.263 x 1.5 = 0.316
Frostbite
Cold 0.8, Force 0.2
Cold 5
0.077
Fails the Gate: 0 Cold points were spent, so it is never rolled
Searing Edge is picked first with probability 1.495 / (1.495 + 0.316) = 82.6%, Keen Balance 17.4%. The number of picks is 1 + floor(3 x 0.5) + floor(30/25) = 1 + 1 + 1 = 3. With only two properties passing the Gate, the roll returns both and then stops, because picks are without repeats. Add a third Gate-passing property to the bank and the third pick has something to draw.
Notice that nothing here is forced: a very Heat-heavy input makes Searing Edge almost certain but not guaranteed, and a poor minigame score widens the pool of weaker properties.
3. A squad meets an enemy it is weak against (Contest)
A Frost Wolf is weak to Heat and strong against Cold. A squad has two casters, one with a Heat spell and one with a Cold spell. For the example, assume each spell's Arcane contribution to Combat Power is 20 before the matchup.
Caster
Spell
Matchup
Arcane contribution
A
Heat
Weak: x1.5
20 x 1.5 = 30
B
Cold
Strong: x0.6
20 x 0.6 = 12
The squad gains 42 Arcane Combat Power from the two casters instead of 40, but the more important change is who carries the fight: A is worth 2.5 times B here. Swap B for a Force caster (neutral, x1.0) and the total becomes 50. This is the whole reason to scout an enemy before choosing a squad, and it is produced by one lookup in the matchup table, with no special case for Frost Wolves.
The resulting Squad Power then enters the same win formula as everything else: P(win) = SP / (SP + ETR).
Design rules, pitfalls and extending the system
Rules
1. Keep each space small. Four to eight axes. If a space needs twenty, it is really two spaces.
2. Name every space. A vector is only meaningful with its axis list, so each space has an id, such as arcane, stats or disposition, and an ordered list of axes.
3. Store raw, derive normalized. Save the raw weights. Compute shares when needed, so that Total (the amount of investment) is never lost.
4. No negative weights outside signed spaces. Bonds and disposition are signed. Everything else is zero or more, which keeps Normalize and Sample valid.
5. Put caps outside the vector. Tier limits, level limits and Gate lines are separate rules that read the vector. Do not encode a cap by clamping an axis.
6. Seed all randomness. Every Sample goes through the seeded generator (Game.rand in the beta), so a save, a replay and a test all agree.
7. Data, not code. Tables of affinities, signatures, matchups and gate lines live in JSON, so a modder can add a class or an enemy without touching a system.
Pitfalls
Pitfall
What goes wrong
Fix
All-zero vector
Normalize divides by zero, cosine is undefined
Treat a zero vector as having no direction. Match returns 0, Sample falls back to equal weights or refuses
Ties for the dominant axis
The minigame or archetype flips unpredictably
Break ties by a fixed axis order in the catalog, never by array position or chance
Double counting
A trait adds Force to a stat and again through the class table, so a bonus is applied twice
Each source edits a vector once. Combine sources into one effective vector, then read it
Runaway sums
Summing every equipped spell's matchup bonus grows without limit
Cap the repertoire bonus, or average above a fixed number of spells
Rarity as power
A rare character gets a sharper vector, so rarity beats choice
Rarity changes budget and variety, never the weights themselves
Rounding drift
Repeated Normalize and Shift lets shares drift off 100%
Keep raw integers, round only for display
Hidden vectors
The player cannot see why a result happened
Show the vector as bars and show the top contributors to a Sample or a Match
Adding a new vector space
1. Pick the question. What is the thing being described, and which decisions will read it? If no decision reads it, it does not need a vector.
2. List the axes. Choose four to eight, and write down what a high value means.
3. Choose the operations. Usually Sample (to pick), Match (to compare), Shift (to change) and Gate (to unlock). Add Decay only if the value should relax over time.
4. Add the space to the catalog (below) and any matchup or signature tables to their own files.
5. Write the tests. A zero vector, a single-axis vector, a tie, and a seeded Sample that always gives the same answer.
6. Expose it in the UI as bars on the relevant sheet.
Data format
A catalog of spaces and the matchup table, as the rebuild would keep them in data/:
{
  "spaces": {
    "arcane": {
      "axes": ["heat", "cold", "force", "motion", "binding", "light"],
      "signed": false,
      "tieBreak": "axisOrder"
    },
    "bond": {
      "axes": ["bond"],
      "signed": true,
      "min": -100,
      "max": 100,
      "decayPerDay": 1
    },
    "disposition": {
      "axes": ["courage", "greed", "curiosity", "loyalty"],
      "signed": true,
      "min": -100,
      "max": 100
    }
  },
  "matchups": {
    "strong": 0.6,
    "neutral": 1.0,
    "weak": 1.5
  },
  "enemies": {
    "frost_wolf": {
      "threat": 120,
      "weakTo": ["heat"],
      "strongAgainst": ["cold"]
    }
  },
  "properties": {
    "searing_edge": {
      "signature": { "heat": 0.7, "force": 0.3 },
      "gate": { "heat": 5 },
      "weight": 1.0
    }
  }
}
The file names and keys above are the proposed layout. The beta keeps the same ideas in config.js, and the rebuild moves them into JSON. The numeric values in the example are placeholders, except the matchup multipliers, which come from t