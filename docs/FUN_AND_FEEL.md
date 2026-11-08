# Fun and Feel Testing (separate milestone: FF)

This is a **separate milestone, FF (Fun and Feel)**, outside `docs/ROADMAP.md`. Don't renumber or edit the roadmap for it.

**Order (user request, Nov 8):** FF starts **after LT is finished** (`docs/LAB_TUNER.md`, through its Part 6 hand-off). Don't start it while LT is running. It builds on LT's sweep runner, AI profiles, metrics, `lab_play.gd` and persona playtests, and goes much deeper. Track it as "FF Fun and Feel testing" in `docs/PROGRESS.md` and commit it as "FF: Part N ...".

**The goal:** test whether combat (and later the whole game) is **fun** and **feels good**, as thoroughly as automation allows, with:
- in-depth metrics grounded in game design research;
- a wide, varied, calibrated set of agent playtesters;
- feel testing from captured frames, timing and audio;
- a human playtest kit, because humans are still the final word.

**What automation can and can't do:**
- **Machines are good at:** decision quality, fairness, dominant strategies, learning curves, pacing, clarity and missing feedback.
- **Vision agents judging frames are decent at:** readability and clutter, and whether a hit "reads".
- **Nobody but humans can judge:** whether it *feels* satisfying in the hands and ears. Part 6 exists for that.
- **The report** always shows the human, agent and machine signals side by side.

---

## Part 1: Deeper fun metrics

Add these to LT's metric set (`src/core/lab/metrics/`, one file per family). Targets and weights go in `data/lab/tuner.json`. Every metric gets:
- a plain-language description;
- a "why it matters" line;
- a test on a hand-built log.

### 1.1 Decisions (Sid Meier's "a series of interesting decisions")

- **Real choices per turn** (from LT), split by turn phase: opening, mid-fight, closing.
- **Decision regret:** for each human or agent turn, the value gap between the chosen play and the expert's best. A high average means players can't see good plays; near zero everywhere means the turns are too easy.
- **Aha moments:** turns where the expert's best play is worth much more than the greedy player's (a hidden clever play exists). Count per fight; the target is at least 1.
- **Dead turns:** turns where every option is about equally useless, or the only good play is "move away".
- **Dead draws:** cards in hand that can't be played usefully this turn, per character.
- **Plan continuity:** how often a setup made this turn pays off within 2 turns (a freeze then a shatter, Setup then Borrow). This shows multi-turn planning exists.
- **Decision load:** options × time-to-decide (for agents, tokens or steps spent). It catches turns that are exhausting rather than interesting.

### 1.2 Challenge and flow

- **Flow curve:** across the 12 Lab fights in order, and across story week 1 to 5, plot expert and novice win rate and closeness. **The goal:** challenge rises with the player's skill (from Part 2's learning agents).
- **Tension curve per fight:** "threat" each round, i.e. incoming telegraphed damage vs the party's remaining HP. Good fights have rising tension and a peak near the end. Report the shape (flat, rising, spiky, front-loaded) and the share of fights with a peak in the last third.
- **Close calls and comebacks** (from LT), plus **snowballing**: when the side ahead after round 2 always wins, the fight is decided too early.
- **Unfair losses:** after each loss, the expert re-searches the last 2 rounds. If no sequence would have survived, the loss was unavoidable. Count it, and list the fights and seeds. **Target 0.**
- **Mastery headroom:** win rate and rounds-to-win of the expert at search depth 1 vs 2 vs 3. Gains with more depth mean there's room to get better. No gain means the skill ceiling is low.

### 1.3 Agency and expression (autonomy and competence)

- **Strategy diversity:** cluster the winning action sequences and final decks across seeds. Many distinct clusters means many viable ways to win.
- **Build diversity:** in the arena sampler and in story runs, count how many different decks or lever-using styles win.
- **Character agency:** each party member's share of decisive plays (kills, cancels, setups that paid off). Nobody should be a passenger. **Flag** any class under 10%.
- **Role clarity:** do the classes contribute differently? Measure the distance between their contribution profiles.
- **Counterplay coverage:** for every enemy telegraph type, the share of situations where at least 2 different answers exist (move, push, block, kill, redirect).

### 1.4 Emergence and surprise

- **Chain reactions:** events with 3 or more linked effects (a push into a barrel that ignites oil that hits two enemies). Count per fight, and count the distinct chain types.
- **Board-kill variety:** distinct kinds of board kills per fight and per preset.
- **Novelty decay:** over 20 fights with the same preset, does the variety of plays and chains drop off? A steep drop means it gets samey.

### 1.5 Pacing and friction

- **Fight length**, **time per decision** and **wait share** (time spent watching vs deciding; Part 4 measures it in real seconds).
- **Clicks per action:** count the clicks needed to play the most common actions.
- **Undo rate:** humans only. A high undo rate means previews or rules confused people.
- **Rules lookups:** in agent runs, how often an agent asks "explain lever X". A high count means a rule is unclear.

### 1.6 Teamwork (relatedness, within the party)

- **Interaction density:** plays that involve 2 or more party members (combos, Pass, Borrow, Setup, cross-ally reactions, body blocks) per round.
- **Synergy dependence:** win rate with the teamwork cards removed vs kept. Teamwork should matter, but not be required to function.

### 1.7 Scorecards

- **A scorecard per preset:** one line per family (Decisions, Challenge, Agency, Emergence, Pacing, Teamwork, Clarity, Feel), each graded A to F against its targets, with the 3 biggest problems written out in words.
- **No single "fun number" is ever the headline.**

---

## Part 2: Learning agents (onboarding and the learning curve)

- **Agents that start knowing nothing:** they get only the tutorial and in-game text. They keep a **notes file** between fights (what they learned, mistakes to avoid) and play the 12 Lab fights in order, then 5 again.
- **What it measures:**
  - **the learning curve:** decision regret and win rate per fight;
  - **when each mechanic is first used on purpose;**
  - **mechanics never discovered;**
  - **what the notes say they misunderstood.**
- **The tutorial comprehension test:** after the tutorial floor, ask the agent 10 rules questions, auto-graded from data. A wrong answer is a tutorial bug. Re-run it after every tutorial change.
- **The "first 15 minutes" test:** a Newcomer plays the start of a new story run to the first fight. **Report:** time to the first meaningful decision, confusing moments, and where it wanted to quit.

---

## Part 3: Agent variety and calibration

### 3.1 The persona library (`data/lab/personas/*.json`)

Build personas along several axes instead of a short list, so a test can sample a varied panel. Each persona file has:
- **motivations** (weights 0 to 1), using the motivation families gamers report: action and destruction, excitement, competition, completion, strategy, discovery, story, power fantasy, and building or customizing;
- **skill** (newcomer, average, expert);
- **patience** (low, medium, high);
- **reading** (skims, normal, reads everything);
- **genre background** (tactics, deckbuilders, JRPGs, action games, none);
- **taste notes** (what delights or annoys them);
- **voice** (how they write their journal).

**At least 16 personas.** The first ones:
- The Newcomer;
- The Tactician;
- The Deckbuilder;
- The Casual;
- The Breaker (exploit hunter);
- The Speedrunner (fewest rounds);
- The Completionist (bonus objectives, every combo);
- The Roleplayer (plays "in character" and cares about the cast and story beats);
- The Power Fantasist (wants big moments);
- The Cautious Player (never takes risks);
- The Rules Lawyer (checks every preview against the result; files bugs);
- The Teen Player (the game's audience: high-school setting, short attention, loves banter);
- The Streamer (narrates out loud; notes moments that would be fun to watch);
- The Frustrated Player (low tolerance; quits after 2 unfair moments);
- The Accessibility Tester (Part 4.4);
- The Game Designer Critic (writes a design review: what to cut and what to double down on).

### 3.2 Model and run variety

- **Different models per persona:** smaller, faster models for low-skill or low-patience personas, and the strongest model for the Tactician, Breaker and Critic. This way skill differences are real, not only acted.
- **Repeats:** each persona plays each preset twice with different seeds, and once with a "fresh mind" (no notes). This checks consistency.

### 3.3 Instruments (what agents fill in)

- **After each fight:** the LT rating card, plus short scales in the game's own wording, based on standard player-experience questions:
  - competence ("I felt skillful");
  - autonomy ("I had meaningful freedom");
  - tension ("I was on the edge of my seat");
  - challenge ("It was the right difficulty");
  - frustration ("It felt unfair");
  - boredom ("I was waiting or doing busywork");
  - clarity ("I understood what would happen");
  - teamwork ("The characters worked together").
- **Free text:**
  - the best moment;
  - the worst moment;
  - one thing to change;
  - "would you play another fight now?" (yes or no). This is the single most useful question.
- **After a session:** rank the presets played, and say why.

### 3.4 Calibration (so agent opinions mean something)

- **Reference presets** in `data/lab/presets.json`, marked `"calibration": true`:
  - **`ref_boring`:** obvious moves only, long fights, no board;
  - **`ref_unfair`:** unavoidable damage, random misses back on;
  - **`ref_chaos`:** every lever on, cluttered;
  - **`ref_solid`:** the best LT preset.
- **Every agent panel plays these blind**, mixed in with the real presets under neutral names.
- **Checking agents:** a persona that can't rank `ref_boring` and `ref_unfair` below `ref_solid` is flagged as unreliable, and its scores are down-weighted in the report.
- **Agreement:** report how much the agents agree with each other (inter-rater agreement) per question. Low agreement on a question means the question is vague, or the preset splits opinions. Either way, the report says so.
- **Calibrating against humans:** when human ratings exist (Part 6), report which personas track humans best. **Weight those higher** in future reports (weights in `tuner.json`).

### 3.5 Cost control

- **Panels:** each panel is a plan in `data/lab/panels/*.json` (which personas, presets, fights, repeats and models), with a fight and token budget.
- **The default "quick panel":** 6 personas × 4 presets × 3 fights.
- **The "full panel":** all personas, the shortlist plus references, and 6 fights.
- **Stop when the budget is hit,** and report what finished.

---

## Part 4: Feel testing

### 4.1 Capturing what the player sees and hears

- **The tool:** `tools/feel_capture.gd` plays scripted moments in the real combat scene (not headless) and records:
  - frames at 30 fps (PNG, at the 640x360 base, scaled 2x);
  - an **event timeline** (input, preview shown, animation start and impact, VFX, sound, shake, hitstop, number popup, log line, all with frame timestamps);
  - the audio events with their ids and volumes.
- **Moments to capture** (in `data/lab/feel_moments.json`):
  - a card hover and preview;
  - a Strike;
  - a spell hit;
  - a crit-free big hit;
  - a push into a pit;
  - a collision chain;
  - a barrel explosion;
  - a cross-ally reaction;
  - a telegraph appearing;
  - an enemy turn with 3 enemies;
  - a party member going down;
  - a revive;
  - Surge spending;
  - a boss phase change;
  - victory;
  - defeat.
- **Output:** `tools/feel/<moment>/` with frames, a contact sheet (a grid of key frames with timestamps), a GIF, and `timeline.json`.

### 4.2 Measured feel metrics (from the timeline)

| Metric | What it measures | Target (tunable, in `data/lab/feel.json`) |
| --- | --- | --- |
| **Response time** | Frames from click to the first visible change | 3 frames (100 ms) or less |
| **Preview delay** | Hover to preview shown | 100 ms or less |
| **Feedback channels per event** | Of: animation, VFX, sound, shake, hitstop, flash, number, log | Hits at least 4, kills at least 5, board kills at least 6 |
| **Anticipation, impact, recovery** | Each attack animation has a wind-up, an impact frame and a recovery, and the impact lines up with the sound and number (within 1 frame) | All of them |
| **Hitstop** | Present on hits and kills, length by size | 40 to 120 ms |
| **Wait share** | Share of fight time the player can't act (enemy turns, animations) | Under 35% at default speed |
| **Enemy turn length** | Seconds per enemy action at default speed | 1.2 s or less |
| **Clicks per common action** | Card on a target, Strike, Move | 2 or fewer |
| **Sound coverage** | Every event type in the juice table has a sound; no clipping or stacking over a limit; levels balanced (measure peak and loudness) | 100%; no clipping |

### 4.3 The juice table

- **The table:** `data/lab/juice.json` lists, for each event type, the feedback it must have.
- **The test:** a test fails if a captured moment is missing one. The user can edit the table.

### 4.4 Readability and clarity, judged from frames

- **Automated checks on captured frames:**
  - the smallest text size;
  - text contrast against its background (aim for 4.5 to 1 or better);
  - overlapping labels;
  - telegraph tile contrast against every floor tileset;
  - unit outline contrast;
  - clutter (how much of the board is covered by UI or effects at peak);
  - a **colorblind simulation** (protanopia, deuteranopia, tritanopia) of every contact sheet, re-running the contrast checks on telegraphs and Vector colors.
- **Vision agent reviews:** an agent that can see images gets each contact sheet (and the matching frames) **without the log**, and answers:
  - "What just happened? Who did it, to whom, and what was the result?";
  - "Where will enemies attack next?";
  - "Which unit is acting?";
  - "Is anything confusing or cluttered?";
  - "Does the hit look and feel strong (1 to 5)?"

  The tool compares its answers with the real log to give a **clarity score** per moment. Misread moments become clarity bugs, with the frame attached.
- **The Accessibility Tester persona** plays through `lab_play.gd` with the colorblind-simulated frames and reading-light text, and reports what it couldn't tell apart.

### 4.5 Feel A/B

- **The setup:** for feel levers (hitstop length, shake strength, kill cam, animation speed, enemy turn speed), capture the same moment with 2 or 3 settings.
- **The judging:** vision agents and the user compare them side by side ("Which hit feels stronger? Which is easier to follow?").
- **The output:** a short feel report with a recommended setting per lever.

---

## Part 5: The fun report

- **The tool:** `tools/fun_report.gd` writes **`docs/FUN_REPORT.md`** (new dated section per run, nothing overwritten) and a simple HTML dashboard, `tools/fun_dashboard.html`, that opens in a browser.
- **The report has:**
  - the per-preset scorecards (Part 1.7);
  - the tension curves;
  - the learning curve;
  - agent panel results with reliability flags;
  - feel metrics with the worst moments' contact sheets;
  - clarity bugs;
  - the top 10 problems ranked by how many signals agree (machine, agents, feel, humans);
  - a "what to try next" list of lever or content changes. Each suggestion names the evidence.
- **Re-running:** one command re-runs a chosen panel and feel capture after any change, and diffs against the last report ("Clarity went from C to B; wait share dropped from 41% to 29%").

---

## Part 6: Human playtest kit (the ground truth)

- **The guide:** `docs/PLAYTEST.md` gets an "FF sessions" section: how to run a 30-minute session with a friend.
  - **Before:** no instructions beyond the tutorial.
  - **During:** ask them to think aloud. Record the screen and voice with OBS, with their OK.
  - **After:** the same instruments as the agents (Part 3.3).
  - **Then:** a 5-minute chat with 4 set questions.
- **In-game telemetry for humans:** in a playtest build, written to the feedback zip:
  - hover time per card and option (hesitation);
  - undo use;
  - time per decision;
  - restarts and quits mid-fight;
  - the rating cards.
- **A hesitation map:** a report of where on the board and in which UI players hesitated.
- **The human vs agent comparison:**
  - **When:** whenever human sessions exist, the fun report shows humans and agents on the same scales.
  - **Learning from it:** it reports which personas predicted humans best, and updates the persona weights (Part 3.4).
  - **What wins:** human data always wins where they disagree.

---

## Tests and done when

**Tests:**
- **Metrics:** every new metric on a hand-built log; unfair-loss detection on a fight built to be unwinnable and on one built to be winnable.
- **Agents:** learning-agent notes carry between fights; the tutorial quiz grading; persona files validate.
- **Calibration:** calibration presets are hidden under neutral names in panels; the unreliable-agent flag fires on a fake agent that rates at random.
- **Feel:** `feel_capture` writes frames, a timeline and a contact sheet; juice-table checks fail on a moment missing a channel; contrast and colorblind checks run on a sample frame.
- **The report:** `fun_report` writes the report and the dashboard from sample data.

**Done when:**
- **Metrics and agents:** every Part 1 metric family is in the report; learning agents and the tutorial quiz work; at least 16 personas exist and calibration runs.
- **Feel:** all feel moments are captured with measured metrics, juice checks, readability checks, vision-agent clarity reviews and colorblind sheets; a feel A/B report exists for the feel levers.
- **The report:** `docs/FUN_REPORT.md` and the dashboard show a first full run.
- **Humans:** the human playtest kit is ready.
- **Then:** stop and ask the user to run one human session, so the agents can be calibrated against it.
