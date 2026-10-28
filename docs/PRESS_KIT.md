# Press kit

## Pitch

**Project Vector** is a small-town life sim with a tactical card RPG underneath. You're the new kid in a town with a hole in its story. By day you go to school, make friends and spend your hours wisely. By night you go down into the Upside-Down, a twisted copy of the town, and fight with spells you design yourself from Vectors: Heat, Cold, Force, Motion, Binding and Light. Combine two and you get something new.

## Features

- **Design your own spells.** Pick Vectors, a Form and a Magnitude at the workbench, play a quick crafting minigame, and get a card. Pairs of Vectors make 15 named combos (Magma Ram, Glacier Slide, Flash Step...) to discover.
- **Tactical grid fights** with 2 Actions and a Quick, enemies that show their next move, cover, terrain and statuses.
- **A week of school life:** classes, shops, jobs, friends who remember what you said, and a narrator with opinions.
- **Your spark:** a narrator's quiz finds your strongest Vector, so every run starts a little different.
- **The Endless Arena:** wave after wave, new themes every 5 waves, card picks and Techniques.

## Screenshots

Run `tools/capture_shots.gd` (see its header) to fill `tools/press_kit/`:

| File | Moment |
| --- | --- |
| `title.png` | The title screen |
| `town_sunset.png` | The town after school |
| `boss_telegraph.png` | The Hollow Mascot telegraphing an attack |
| `spark_quiz.png` | The spark quiz |
| `compendium.png` | The Vector Compendium |
| `kelly_cutscene.png` | Kelly on the first floor |
| `arena.png` | The Endless Arena |

**GIFs and video:** Godot's Movie Maker mode records a scripted moment frame by frame. Add `--write-movie tools/press_kit/<name>.avi --fixed-fps 30` before the `--` in a moment's command, for example:
`Godot_console.exe --path . --write-movie tools/press_kit/boss.avi --fixed-fps 30 -- --seed=3 --fight=hollow_mascot --scene=res://src/scenes/combat/combat.tscn --frames=300 --shot=tools/press_kit/boss.png`
Convert to a GIF with any tool (for example `ffmpeg -i boss.avi -vf "fps=15,scale=640:-1:flags=neighbor" boss.gif`).

## itch.io page (draft)

**Title:** Project Vector (demo)
**Short description:** A small-town life sim with a tactical card RPG underneath. Design your own spells from Vectors.

**Body:**
> New town. New school. A hole in the town's story, and a twisted copy of it underneath.
>
> Spend your days on classes, friends and part-time jobs. Spend your nights in the Upside-Down, fighting with spells you build yourself. Heat and Force make Magma Ram. Cold and Motion make Glacier Slide. There are 15 pairs to find.
>
> This demo covers the first week, up to the Hollow Mascot (about an hour), plus the Endless Arena from the title screen. Press F8 anytime to send feedback. Thank you for playing!

**Controls:** WASD or arrows to move, E to interact, Esc to cancel, F8 for feedback. A controller works too.

## README.txt for the zip

```
Project Vector (demo)
Run ProjectVector.exe. Windows 10 or later.
The demo ends after the first week's boss (about an hour). The Endless Arena is on the title screen.
Press F8 at any time to send feedback: it saves a zip and opens the folder. Please send those zips back. Thanks!
```
