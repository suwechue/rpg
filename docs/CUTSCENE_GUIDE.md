# Writing cutscenes

Cutscenes are JSON files in `data/cutscenes/`. Each file holds a list:

```json
{ "cutscenes": [
  { "id": "my_scene", "markers": { "door": [12, 6] }, "steps": [
    { "type": "title_card", "text": "Friday Night" },
    { "type": "say", "speaker": "kelly", "text": "You came back.", "side": "right" },
    { "type": "narrator", "text": "She doesn't sound surprised." },
    { "type": "choice", "text": "What do you say?", "options": [
      { "label": "\"Of course.\"", "effects": { "bond": { "kelly": 2 } } },
      { "label": "Say nothing", "steps": [ { "type": "emote", "actor": "kelly", "emote": "..." } ] } ] }
  ] }
] }
```

## Steps

| Step | Fields | Does |
| --- | --- | --- |
| `say` | `speaker` (an NPC id), `text` or `textKey`, `side` (left/right), `portrait` (asset id, optional) | A dialogue line with the speaker's portrait and voice blip |
| `narrator` | `text` or `textKey` | A narrator line |
| `portrait_talk` | `left`, `right` (NPC ids), `speaker`, `text` | A line with two big portraits, for scenes without a map |
| `title_card` | `text`, `seconds` | Big centered text ("Week 1", "Wave 10") |
| `choice` | `text`, `options`: [{ `label`, `effects`, `steps` }] | Branches; effects use the same format as events |
| `if_flag` | `flag`, `then`, `else` | Branch on a run flag |
| `wait` / `wait_input` | `seconds` | Pause, or wait for E / a click |
| `fade` | `to` (black/clear), `seconds` | Fade the screen |
| `music` / `sfx` | `situation` / `event` | Play by situation (`data/audio.json`) or sound event (`data/audio_events.json`) |
| `image` | `id` (an asset id, e.g. `art_cutscene_<id>`; "" hides it) | A full-screen illustration; missing art shows a dim veil |
| `camera_shake` / `camera_pan` | `amount` / `to`, `seconds` | Camera moves (when the scene has a camera) |
| `move` / `face` / `emote` | `actor`, `to` (a marker name or `[x, y]` tile), `dir`, `emote` | Actors the current scene offers (NPCs, units) |
| `set_flag` / `give` | `flag`, `value` / `effects` | Change the run |
| `start_combat` | `enemies`, `layout`, `text` | Ends the cutscene and starts a fight |

Players can **skip** (Esc or the Skip button; choices take their first option, flags and effects still apply) and **fast-forward** (hold E). Typing speed comes from Options (`text/speed` in `user://settings.cfg`).

## Where cutscenes play

- **Story:** a step `{ "type": "cutscene", "id": "..." }` in any story (`data/story/*.json`).
- **Townsfolk:** an NPC's `daytimeScene` plays the first time you talk to them during school hours (TL Part 5; `data/cutscenes/town_life.json`). Skipping with a friend plays `skip_<id>`.
- **Combat:** an enemy record's `"cutscenes": { "start": "...", "phase2": "..." }` (bosses).
- **Arena:** `arena_first`, `arena_boss_first`, `arena_new_best` play automatically.
- **Intro:** `intro_moving_day` and `intro_night` frame character creation; `day1_*` play through week 1 Monday.

Try one with **F1 > Cutscenes**, or start the game with `-- --cutscene=my_scene`. A test checks every cutscene's steps. Markers are tile coordinates for now; M12's map markers replace them.
