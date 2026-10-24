# Playtest checklist

A guide for playing Project Vector and writing down how it feels. You don't need to know Godot. Plan on about an hour for week 1, and another hour or two for week 5.

## Starting the game

1. Open Godot 4.7.2, choose **Import**, and pick `project.godot` in the project-vector folder. Press **F5** (or the ▶ button at the top right) to run.
2. Or run this in PowerShell:
   `& "C:\Users\itzju\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path C:\Users\itzju\Documents\project-vector`
3. On the title screen, choose **New run**, pick a class, and leave the seed empty (or type a number to replay the exact same run later).

## Controls

| Key | Does |
| --- | --- |
| WASD or arrows | Walk, move the cursor |
| E or Enter | Talk, open doors, confirm |
| Space | End the current part of the day |
| Esc or Backspace | Back, cancel |
| F5 / F9 | Save / load the run |
| F1 | Debug menu (jump to any week, give XP, start any fight) |

A gamepad works too: D-pad to move, A to confirm, B to go back, Y to end the part of the day.

## Week 1 (play it straight, no debug menu)

Tick each box and add a note when something feels off. Short notes are fine ("too slow", "didn't know what to do").

- [ ] The title screen and class pick make sense without explanation.
- [ ] Monday morning: I understood the schedule screen and what AP is.
- [ ] Monday lunch with Kelly: the choice felt like it mattered.
- [ ] Monday night: the tutorial floor taught me how to move and play cards.
- [ ] I could find my way around town (school, downtown, residential, outskirts).
- [ ] Talking to people: I understood Bond, mood and why a topic was greyed out.
- [ ] A misheard line happened at least once and I understood what went wrong.
- [ ] Shops: buying and equipping something was easy.
- [ ] Night workbench: crafting a card and the minigame felt fair.
- [ ] Fights Tuesday to Thursday: I could read the battlefield (who is where, HP, statuses).
- [ ] Fights felt winnable but not trivial.
- [ ] Friday boss (The Hollow Mascot): the phases were clear and the fight was exciting.
- [ ] I never ran out of things to do, and never felt like I had too few AP to do anything.
- [ ] Nothing crashed or got stuck. (If it did, write what you pressed just before.)

**Questions for week 1**
- What did you spend most of your AP on? Did you wish you had more or less?
- Which character did you like most? Least?
- Was there a moment you were bored? Where?

## Week 5 (use the debug menu to get there)

1. Start a new run, then press **F1 > Time** and jump to week 5, Monday morning.
2. Press **F1 > Leveling** a few times to get the player to about level 12 (a Class Change screen will appear at 5 and 12; pick whatever looks fun).
3. Optional: **F1 > Social** to raise Bonds and recruit a party, since a real week 5 would have one.

- [ ] Class Change and perk picks were exciting choices.
- [ ] The week's story beats made sense even after skipping ahead.
- [ ] Fights felt different from week 1 (new enemies, more to think about).
- [ ] The week 5 boss and the finale played through to an ending.
- [ ] The ending screen told me what happened and invited another run.

**Questions for week 5**
- Did the party feel like *your* party, or just numbers?
- Was any class or card clearly too strong or too weak?
- Would you start another run? Why or why not?

## The gameplay log

While you play (in a normal window, not in tests), the game quietly keeps a log on your computer. Nothing is uploaded. Each line is one in-game day: how much AP went to each kind of action (talking, shops, activities, crafting, gifts, hangouts...), fights won and lost, and how many real seconds the day took.

- Where it is: `%APPDATA%\Godot\app_userdata\Project Vector\gameplay_log.jsonl` (paste that into the File Explorer address bar).
- To see the totals, run:
  `& "C:\Users\itzju\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path C:\Users\itzju\Documents\project-vector -s res://tools/play_log_report.gd`
- To start fresh, delete the file. M19 (day balance) uses this data, so keep it if you can.

## Sending feedback

Copy this file, fill in the boxes and notes, and put it next to your gameplay log. That's everything the balance pass needs.
