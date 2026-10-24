# Alpha build prompt for Claude Code

Paste everything inside the block into Claude Code (VS Code panel, opened on the project-vector folder).
To resume after a stop or a new session, send: "Continue the alpha build from docs/PROGRESS.md, following docs/PROMPT_alpha_run.md."

```text
You are building the alpha of Project Vector, a Godot 4.7 game, from milestone M2 through M8 in one long run.

READ FIRST, IN THIS ORDER
1. CLAUDE.md (rules, Godot path, test commands, art guide).
2. docs/DESIGN.md, the full design. Section 18 "Decisions" is final and overrides anything marked proposed or open.
3. docs/vector_system.md (the Vector system everything is built on).
4. docs/PROGRESS.md (what is done; update it as you go).
5. docs/characters.md: the full cast (source of truth for names, stats, classes, schedules, dialogue). docs/TOWN.md: the town plan (every location, its status, and every character's home).
6. The Nexus project, read-only, to port logic and tuning numbers, never code style or engine specifics:
   - C:\Users\itzju\nexus-project (current rebuild: docs/SPEC.md, src/, tests/)
   - C:\Users\itzju\Downloads\nexus-project\nexus-project\reference\js\config.js (beta numbers)
   Port what fits this design (invention/crafting pipeline, property bank, level-up and pity rules, matchups, bond rules). If Nexus and DESIGN.md disagree, DESIGN.md wins. Never modify either Nexus folder.

SETUP (once)
- Run the load check and the test suite (commands in CLAUDE.md). Both must pass before changing anything.
- Git and GitHub: the remote is https://github.com/suwechue/rpg.git (empty, branch main). If git is available: `git init -b main` if there is no repo, `git remote add origin https://github.com/suwechue/rpg.git` if it is missing, commit "M0/M1 baseline", and `git push -u origin main`. The first push may open a browser window for me to sign in to GitHub; wait for it. Push after every milestone commit. If git is missing or the push fails, keep working with local commits (or none) and note it in PROGRESS.md; never force-push.
- Sandbox art pass: HUD uses assets/packs/ninja_adventure/Ui/Font/NormalFont.ttf at an integer size; the player is a 4-direction walking sprite from assets/packs/ninja_adventure/Actor/Character/.

THE LOOP, FOR EACH MILESTONE M2 TO M8 (DESIGN.md Section 17)
1. Write a short plan for the milestone at the top of your work (5 to 10 bullets), then build it.
2. Rules go in src/core with tests in tests/. Content and tuning numbers go in data/ as JSON. Scenes only display and forward input.
3. Make it playable, not just tested: every milestone must be reachable from the running game (main menu or debug menu, F1), with placeholder art from assets/packs where real art is missing.
4. Before calling a milestone done: run the full test suite and the headless load check, fix every error and warning you introduced, and meet the milestone's "Done when" line.
5. Update docs/PROGRESS.md (status, notes, decisions, stubs) and the "Current state" section of CLAUDE.md, then commit "Mx: <summary>" and push to origin main.
6. Go straight on to the next milestone. Do not stop to ask me between milestones.

MILESTONE NOTES (in addition to DESIGN.md)
- M2: Character model, derived stats, card model with MP cost and Knowledge Tier caps, hybrid cards, deck (hand 7, reshuffle with Fatigue), leveling with class growth weights and pity. Done when a seeded mage levels to 5 identically every time.
- M3: Tactical grid combat like South Park: The Fractured but Whole, shown in 2.5D exactly as DESIGN.md Section 9 "Battlefield and camera (2.5D)" describes: flat logic grid in src/core, a GridProjection in the combat scene with rows receding up the screen and mildly narrowing, trapezoid cells, upright unscaled pixel sprites y-sorted by row with shadows, party left and enemies right, default 9x5 grid. Hand of cards at the bottom, initiative timeline at the top. Clicking a trapezoid must map back to the right cell (test the inverse projection). All 11 Form footprints, Vector grid effects (push, slow, root, burn, freeze), Contest damage, Instability and the Vector Wheel for improvised casts, initiative timeline, enemy AI by disposition Match. MP carries over between fights in a night. Downed allies are injured, not killed; player death ends the run. Use kenney_tiny_battle and ninja_adventure for units and tiles.
- M4: Full calendar (8 weekday parts, free weekends), AP, weekly class schedule screen, class attendance events from data, skipping and detention, Night card crafting with simple stub minigames that return a Performance score.
- M5: Build the town exactly as docs/TOWN.md lays out: 4 zones (school, downtown, residential with Maple Street, Elm Street and Hillside, outskirts) with TileMapLayer from the Kenney Tiny packs and Ninja Adventure interiors. Every location is a record in data/town/locations.json with its status (OPEN, EXTERIOR, CLOSED, STORY), residents, hours and door line. Every named character from docs/characters.md has an NPC record with a home and a schedule, and goes home outside their scheduled hours. EXTERIOR homes support doorstep conversations; CLOSED places look visibly shut (boards, fences, signs). Shops and money at the deli, forge, hospital and corner store.
- M6: Load every character's dialogue topics, gifts, traits and disposition from docs/characters.md into data/npcs/ (one file per character). Dialogue topics with Charisma gates, reception by Match against disposition, misinterpretation with misheard lines, Bonds and tiers, recruitment, portraits, and the narrator as a character with Bond-based tone. Script the full week 1 Monday Kelly scenario and track Kelly Risk. Recruitment is staggered per DESIGN.md Section 18. Todd's disappearances and the Innocent Bystander's week-by-week lines go in as town flavor.
- M7: Weekly signature shaped by town events, seeded daily floor generation Mon to Thu, Friday boss floor with returning (fled-first) enemies, week 1 boss The Hollow Mascot with phases, both Kelly outcomes, permadeath restart, Narrator's Journal that persists between runs, atomic autosave. Done when week 1 is playable end to end.
- M8: Weeks 2 to 5 with their bosses (DESIGN.md Section 10), advanced classes and class change at levels 5 and 12, crafting minigames, audio from ninja_adventure/Audio, title screen, balance pass. Mr. B escalates through weeks 2 to 4 and is revealed in week 5 (DESIGN.md Section 13). Week 5 ends with a placeholder scene named NARRATOR_REVEAL_TBD. Done when a full 5-week run can be completed.

CONTENT SCOPE
Hit the counts in DESIGN.md Section 15 where you can. Week 1 must be fully authored. Weeks 2 to 5 may use fewer events and simpler dialogue as long as each week has its signature, enemies, boss and story beat. Write placeholder text in the game's tone (wry narrator, small-town high school) rather than lorem ipsum.

WHEN SOMETHING IS UNCLEAR OR BLOCKED
Pick the simplest option that fits DESIGN.md, log it under "Decisions made during development" in PROGRESS.md, and keep going. If something truly can't be done (missing art, a Godot limitation), stub it with a TODO, log it under "Stubs and known issues", and move on. Only stop for something that would delete or overwrite my work.

CONTEXT
This is a long job. Keep PROGRESS.md current enough that a fresh session could continue from it at any moment. If you are running low on context, finish the current step, update PROGRESS.md, commit, and tell me to start a new session with the resume line.

WHEN YOU STOP
Report: milestones completed, test results, what to try in the game (exact steps), decisions you made, stubs left, and the next step.
```
