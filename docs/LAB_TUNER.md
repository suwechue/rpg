# Lab Tuner: finding the fun lever combinations (separate milestone: LT)

This is a **separate milestone, LT (Lab Tuner)**, outside `docs/ROADMAP.md`. Don't renumber or edit the roadmap for it.

**Order (user request, Nov 7):** LT comes right after CL Parts 1 to 5 (done) and **before** CL Part 6 (the rollout), because LT is how the user picks a preset. Track it as its own row ("LT Lab Tuner") in `docs/PROGRESS.md` and commit it as "LT: Part N ...".

**Read first:**
- `docs/COMBAT_LAB.md`
- `src/core/combat/rules.gd`
- `data/lab/`
- `src/core/lab/`
- `tools/lab_report.gd`

---

## The idea, and its limits

No program can measure fun directly. LT combines three things, from cheapest to most trusted:

1. **Machine sweeps:**
   - AI players play thousands of Lab fights across lever combinations, headless.
   - They measure **fun proxies**: how many real choices a turn has, whether one strategy dominates, whether skill matters, how tense fights are, how often the board and combos matter.
   - The point is to narrow the 50+ levers down to a shortlist.
2. **Agent playtesters:**
   - Claude subagents with different player personas play the shortlisted presets turn by turn, through a text interface.
   - They explain their choices, note confusion and rate each fight.
   - They're good at spotting confusing rules, obvious moves, dominant strategies and dull turns.
   - They're bad at judging feel (animation, sound, pacing), and their ratings are opinions, not truth.
3. **The user:** plays the top 2 or 3 presets in the Lab's A/B mode and decides. **LT never picks the final preset.**

**Watch for gaming the numbers:** the proxies can be gamed. Never tune a preset to one number. Always read the agent notes next to the metrics, and treat anything that looks too good with suspicion.

---

## Part 1: The headless sweep runner

- **The tool:** `tools/lab_sweep.gd` runs a set of fights × presets (or generated lever sets) × seeds × AI profiles, headless and deterministic. Run it with:

  `godot --headless --path . -s res://tools/lab_sweep.gd -- --plan=res://data/lab/sweeps/<plan>.json`

- **Plans** (`data/lab/sweeps/*.json`) list:
  - the fights;
  - a base preset;
  - lever overrides or ranges;
  - seeds per cell;
  - AI profiles;
  - a time budget.
- **Speed:**
  - Skip all scene, animation and VFX work.
  - Run cells in parallel if Godot allows (`--jobs=N` with separate processes is fine).
  - **Target:** at least 20 fights per second on the user's PC for a 4-unit party.
- **Output:**
  - one JSON line per fight in `user://lab/sweeps/<plan>/<timestamp>.jsonl`, with the same fields as the human Lab log;
  - plus the AI's per-turn decision data (Part 3);
  - plus the full lever set.
- **Resumable:** a crashed or stopped sweep continues where it left off.
- **Safety:**
  - every fight has the round cap and a stall watchdog;
  - a stall is logged as a result (it's bad, and it counts against the preset), not a crash.

## Part 2: AI players worth measuring with

The current autoplay walks into telegraphs and ignores potions, which makes it a floor, not a measure. Add **player profiles** in `src/core/lab/players/`. All of them use only the information a human sees (telegraphs, previews, the hand, the visible discard), never hidden enemy rolls or the deck order.

| Profile | How it plays | Why |
| --- | --- | --- |
| `expert` | **Turn search:** searches its whole turn using the exact preview: a beam search over orderings of each unit's Move, Action and Quicks, plus choose-order when that lever is on. **Scoring:** a state score (HP, kills, telegraphs cancelled, position safety, Surge, setups for allies). **Depth:** one enemy turn of lookahead using the visible telegraphs | Measures the skill ceiling and whether deep play exists |
| `novice` | **Choices:** picks a good-looking option with some noise. **Mechanics it ignores:** about half the time it ignores Part 3c mechanics and teammate-deck cards, and it rarely uses the board on purpose | Stands in for a new player |
| `greedy` | Always maximizes damage this turn. No defense, no setup | Tests whether "just hit things" wins (it shouldn't, most of the time) |
| `random` | A random legal action | The floor. Sanity check |

- **Same evaluator:** the expert and novice share the state-score code. Its weights live in `data/lab/players.json`.
- **Test:** an AI profile test checks that `expert` beats `greedy`, which beats `random`, on the `current` preset.

## Part 3: Fun proxies (per fight, rolled up per preset)

**Per turn**, the expert also records:
- the value of every option it considered;
- how many options were within 10% of the best ("**real choices**");
- the gap between the best and second-best option ("**obviousness**");
- how many options it had to look at ("**option load**").

**Metrics** (targets are starting guesses; all in `data/lab/tuner.json`, which the user can edit):

| Metric | What it measures | Target (tunable) |
| --- | --- | --- |
| **Real choices per turn** | Average number of near-best options | 2 to 4 (1 = obvious, 6+ = noise) |
| **Obvious turn share** | Turns where the best option is far ahead (>30% gap) | Under 35% |
| **Option load** | Legal distinct plays per turn | Under ~40 (too many means overwhelm) |
| **Skill gap** | Win rate: expert vs novice vs greedy vs random | Expert 85-95%, novice 50-70%, greedy under 50%, random under 10% |
| **Dominant play** | The largest share of any single card or play in the expert's wins; does one opening win every time? | No card over 25% of plays; no single line wins over 60% |
| **Tension** | Close wins (lowest party HP under 30%) and comebacks (behind on HP mid-fight, then won) | Close wins 25 to 45% of expert wins |
| **Length** | Rounds per fight | Normal 3 to 5, boss 6 to 8; stalls 0 |
| **Agency** | Share of incoming telegraphed damage avoided or cancelled by the expert | 50 to 80% (too high means telegraphs are free) |
| **Board use** | Share of kills from the board (pits, collisions, hazards, reactions) | 25 to 50% |
| **Teamwork** | Combos, cross-ally reactions and teammate-deck plays per fight | At least 2 |
| **Variety** | Card entropy in the expert's plays across seeds; different winning lines per fight | Higher is better |
| **Complexity cost** | Number of levers turned on, weighted by how much text a player must learn (each lever gets a `learnCost` in its data) | Lower is better |

**The fun score:**
- **The formula:** a weighted mix of how close each metric is to its target, minus the complexity cost. The weights are in `tuner.json`.
- **Hard limits** (any stall, expert win rate under 70%, random win rate over 20%) disqualify a preset regardless of score.
- **The report shows every metric**, never only the score.

## Part 4: Searching the lever space

There are too many combinations to try them all (50+ levers), so search in stages. Each stage is a sweep plan in `data/lab/sweeps/`:

1. **Baseline:** every existing preset (`current`, `cl_base`, `cl_puzzle`, `cl_cards`, `cl_brutal`, `cl_plus`, `cl_everything`) × all 12 fights × 30 seeds × all 4 profiles. This gives a baseline table.
2. **Screening (one lever at a time):**
   - From `cl_base` and from `cl_puzzle`, flip each on/off lever, and try 3 values for each numeric lever.
   - Run the fights that lever affects (each lever lists its `fights`, or all of them).
   - **Output:** a table of how each lever moves each metric, i.e. the lever's "effect sizes".
   - **Mark each lever** as helps, hurts, neutral, or "only interesting with another lever".
3. **Pairs:** for the top ~12 helpful levers, test all pairs, to find levers that are good together (e.g. `allyReactions` + `lingeringFields`) or bad together.
4. **Search:**
   - An evolutionary search, or hill climbing with random restarts. Use the top ~15 levers plus their numeric ranges.
   - **The goal:** the fun score with its hard limits, plus a complexity penalty, so a simpler preset wins ties.
   - **Robustness:** the score uses 20 seeds per fight. Candidates must hold up across all fights and at least 3 party compositions (balanced, all-melee, all-caster).
   - **Budget:** set in the plan (default 2 hours).
5. **Shortlist:**
   - Keep the top 5 candidates that **differ from each other**: at least 3 levers apart.
   - Save them as presets `tuned_1` to `tuned_5` in `data/lab/presets.json`, marked `"generated": true`, with a one-line summary of what makes each one different.

**The report:**
- `tools/lab_tune_report.gd` writes **`docs/LAB_TUNING.md`**:
  - the baseline table;
  - lever effect sizes (with charts as ASCII or a generated PNG in `tools/screenshots/`);
  - pair findings;
  - the shortlist with every metric;
  - and plain-language notes: "Fog adds real choices but makes novices lose twice as often."
- **Updates:** each run adds a dated section and never overwrites old results.

## Part 5: Agent playtesters (Claude subagents)

**A text play interface:**
- `tools/lab_play.gd` plays one fight a step at a time. The state is the fight, the preset, the seed and the list of actions so far. Each call replays them (deterministic) and prints the new state, so no save system is needed.

  `godot --headless --path . -s res://tools/lab_play.gd -- --fight=thin_ice --preset=tuned_2 --seed=4 --actions="3,1,7"`

- **What it prints each step** (plain text, made for a reader):
  - **The board:** an ASCII map with a legend (units, props, pits, ice, telegraphed tiles marked with the attacker's letter).
  - **The units:** each with HP, statuses, facing, gauge.
  - **Enemy plans:** each in words, with exact damage.
  - **The hand:** the active character's hand with costs and full text, plus the discard and deck counts.
  - **Legal actions:** numbered, each with its exact preview ("Shove Line north: Ghoul A falls into the pit (dies); Ghoul B collides with the crate: 2 damage").
  - **The log:** what just happened, in the plain-words log.
- **Commands:** play option N; "explain lever X" (prints the lever's rules text); "show discard"; "show ally deck size"; undo when the undo lever allows it.
- **Test:** replaying the same action list always gives the same state.

**Personas** (`data/lab/personas.json`):
- **The Newcomer:** skims rules and plays on instinct.
- **The Tactician:** loves *Into the Breach*, plans every turn.
- **The Deckbuilder:** loves *Slay the Spire*, looks for card engines.
- **The Casual:** wants fast, flashy turns and gets bored by long thinking.
- **The Breaker:** tries to find one broken strategy and abuse it.

**How Claude Code runs them:**
- **One subagent per persona** (use the Agent or Task tool). Each gets:
  - the persona text;
  - the rules as a player would learn them: the tutorial text plus the lever-panel text for that preset's levers;
  - instructions to play through `lab_play.gd` only. **No reading the source code or data** (that would be cheating; the persona must learn as a player would).
- **Each persona plays every shortlisted preset** (`tuned_1` to `tuned_5`, plus `current` and `cl_base` as references) on 4 fights: one easy, one board-heavy, one teamwork, and the boss.
- **Run them in parallel** where possible. Keep a cap in the plan (default: at most 5 subagents at once, about 140 fights total) so the run stays affordable.
- **The game log:** each agent keeps a short turn journal (options considered, why it chose, "felt clever" moments, confusion).
- **The rating card:** after each fight, the agent fills in the same card a human gets:
  - fun 1 to 5;
  - real options 1 to 5;
  - felt clever yes or no;
  - boring or annoying;
  - plus "rules I misunderstood" and "a broken strategy I found".
- **Where it's saved:** `user://lab/agents/<persona>/<preset>/<fight>.json`. The report tool reads it.
- **Summarize:** the main session (not a subagent) reads all agent results and adds an "Agent playtest" section to `docs/LAB_TUNING.md`:
  - average ratings per preset and per persona;
  - the most common confusions (these are **rule clarity bugs**, so fix their texts);
  - broken strategies the Breaker found (check each in a sweep; if real, add it to the report as a dominant-play finding);
  - quotes.
- **Agent notes vs metrics:** if the agent ratings and the metrics disagree, say so plainly. Don't average them away.

## Part 6: Hand-off to the user

- **Stop and write a final ranked list** in `docs/LAB_TUNING.md`: the top 3 presets, each with its strongest and weakest point, in plain words.
- **Lab screen:** set up "Tuned shortlist" A/B pairs so the user can play them (for example, `tuned_1` vs `tuned_2` on Thin Ice, then the winner vs `tuned_3` on the boss).
- **Then stop and ask the user to play.**
  - **Their Lab ratings outrank everything else.** `lab_report.gd` shows human ratings next to the agent and machine scores.
  - **CL Part 6** (the rollout) starts only after the user picks.

**When to re-run:**
- **After any rules or card change:** re-running the shortlist sweep must be one command: `--plan=res://data/lab/sweeps/shortlist.json`.
- **The agent playtest** can be re-run for one persona or preset at a time.

---

## Tests and done when

**Tests:**
- **The runner:** sweep determinism (the same plan and seed give the same results); resume after a stop; the stall watchdog records stalls; parallel jobs merge correctly.
- **AI profiles:** expert beats greedy beats random on `current`. The profiles never read hidden information: a test gives them a state where the deck order and enemy rolls are scrambled, and checks their choice doesn't change.
- **Metrics:** each metric is calculated correctly on a hand-built fight log.
- **The fun score:** the score and hard limits read `tuner.json`.
- **The search:** the search improves the score on a toy problem.
- **The shortlist:** shortlist diversity (at least 3 levers apart).
- **`lab_play.gd`:** deterministic replay; numbered actions match the legal moves; the printed preview matches what happens; it refuses unknown commands politely.
- **The report tool:** writes a valid `docs/LAB_TUNING.md` section from sample data.

**Done when:**
- The four AI profiles exist.
- Every stage in Part 4 has run on the user's PC (or in a session that can run Godot headless).
- `docs/LAB_TUNING.md` has the baseline, lever effects, pairs, the shortlist and the agent playtest section.
- `tuned_1` to `tuned_5` are in the Lab.
- The A/B shortlist is set up.
- PROGRESS.md says it's the user's turn to play.
