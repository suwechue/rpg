# Phase 2 build prompt for Claude Code

Paste this into Claude Code (VS Code, on the project-vector folder). To resume later, send: "Continue Phase 2 from docs/PROGRESS.md, following docs/ROADMAP.md."

```text
Phase 2 of Project Vector. Read CLAUDE.md, docs/ROADMAP.md (this plan; note the 32x32 tile and 640x360 decision at the top, which overrides DESIGN.md's 16x16 / 480x270), docs/DESIGN.md (Section 18 decisions are final), docs/characters.md, docs/TOWN.md and docs/PROGRESS.md before doing anything.

Work through docs/ROADMAP.md milestones M9 to M23 in order, the same way as the alpha:
1. Write a short plan for the milestone, then build it.
2. Rules in src/core with tests; content and tuning in data/; scenes only display and forward input; all art and sound by asset id once M10 exists.
3. Make it playable and reachable from the game or the F1 debug menu.
4. Run the full test suite, the load check and the smoke tests; fix every error you introduced; meet the milestone's "Done when".
5. Update docs/PROGRESS.md (add a Phase 2 table) and CLAUDE.md "Current state", take screenshots into tools/screenshots/, commit "Mx: <summary>" and push to origin main. Confirm the push succeeded; if it fails, stop and tell me why.
6. Continue to the next milestone without asking.

Write the user-facing guides the roadmap asks for (ASSETS.md, MAP_GUIDE.md, CUTSCENE_GUIDE.md, PLAYTEST.md, ACT2.md) in plain language for someone new to Godot.

If a decision in "Open decisions for the user" blocks you, use the default noted here and log it in PROGRESS.md: art sizes are decided (32x32 tiles, 640x360, 32x32 characters, 64x64 portraits; no hardcoded sizes); the narrator stays NARRATOR_REVEAL_TBD; the parent is chosen at character creation (mom, dad or guardian); Act 2 is a design stub only; Permadeath stays the default with Narrator's Mercy offered at new run.

Stop only for something that would delete or overwrite my work, or a failed push. When you stop, report milestones done, test results, what to try in the game, decisions made and the next step.
```
