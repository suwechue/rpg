# Lab Tuning

Results of the Lab Tuner (docs/LAB_TUNER.md). Each run adds a dated section below; old sections stay. Machine numbers are proxies for fun, not fun: read them next to the agent notes, and the user's own Lab ratings outrank both.

## Tuning run, 2026-11-08 07:52:13

### Baseline (10080 fights, 2026-11-07T19:51:11)

|  | score | ok | exp | nov | grd | rnd | real | obv | load | close | rnds | boss | agcy | board | team | var | dom | line |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cl_base | 0.40 | no: stalls, random wins over 20% | 94% | 94% | 88% | 70% | 3.0 | 14% | 16.2 | 0% | 3.4 | 8.7 | 93% | 20% | 0.2 | 0.9 | 16% | 100% |
| cl_brutal | 0.43 | no: stalls, random wins over 20% | 94% | 94% | 88% | 66% | 3.0 | 13% | 15.6 | 0% | 3.6 | 8.1 | 90% | 21% | 0.2 | 0.8 | 15% | 100% |
| cl_cards | 0.41 | no: stalls, random wins over 20% | 95% | 96% | 88% | 73% | 3.8 | 8% | 16.3 | 0% | 3.2 | 8.3 | 91% | 33% | 0.2 | 0.9 | 16% | 100% |
| cl_everything | -0.50 | no: stalls, random wins over 20% | 96% | 99% | 88% | 64% | 3.5 | 21% | 14.2 | 1% | 2.9 | 6.3 | 0% | 20% | 2.7 | 0.8 | 29% | 97% |
| cl_plus | 0.31 | no: stalls, random wins over 20% | 94% | 94% | 88% | 74% | 3.0 | 12% | 16.9 | 0% | 3.4 | 10.7 | 88% | 24% | 0.2 | 0.8 | 15% | 70% |
| cl_puzzle | 0.43 | no: stalls, random wins over 20% | 94% | 94% | 88% | 70% | 3.0 | 14% | 16.2 | 0% | 3.4 | 8.7 | 93% | 20% | 0.2 | 0.9 | 16% | 100% |
| current | 0.37 | no: random wins over 20% | 99% | 99% | 93% | 38% | 3.9 | 13% | 5.2 | 0% | 2.5 | 4.5 | 96% | 7% | 0.0 | 0.9 | 8% | 23% |

Columns: **exp** Expert win rate (target 85% to 95%); **nov** Novice win rate (target 50% to 70%); **grd** Greedy win rate (target at most 50%); **rnd** Random win rate (target at most 10%); **real** Real choices per turn (target 2.0 to 4.0); **obv** Obvious turn share (target at most 35%); **load** Option load (target at most 40.0); **close** Close wins (target 25% to 45%); **rnds** Rounds (normal fights) (target 3.0 to 5.0); **boss** Rounds (boss) (target 6.0 to 8.0); **agcy** Telegraphed damage avoided (target 50% to 80%); **board** Board kills share (target 25% to 50%); **team** Teamwork plays per fight (target at least 2.0); **var** Card variety (entropy, 0 to 1) (target at least 0.6); **dom** Most-played card share (target at most 25%); **line** Most common winning opening (target at most 60%). **score** is the fun score (0 to 1, minus complexity); **ok** says whether a hard limit disqualifies it.

### Lever effects, one at a time (18304 fights)

**From cl_base** (its fun score: 0.29). Score change, verdict, then the biggest metric moves:

```
Line of sight = true               +0.103 +++++++++++++         helps   
Strike costs = quick               +0.033 ++++                  helps     (disqualified: stalls, random wins over 20%)
Instability rolls = false          +0.030 ++++                  helps     (disqualified: stalls, random wins over 20%)
Ice slides = false                 +0.026 +++                   helps     (disqualified: random wins over 20%)
Keywords = false                   +0.019 ++                    neutral   (disqualified: random wins over 20%)
Turn structure = alternate         +0.018 ++                    neutral   (disqualified: random wins over 20%)
Enemies hit each other = false     +0.015 ++                    neutral   (disqualified: stalls, random wins over 20%)
Terrain reactions = off            +0.014 ++                    neutral   (disqualified: random wins over 20%)
Things in the path take the shot = +0.013 ++                    neutral   (disqualified: stalls, random wins over 20%)
Tracking attack share = 0.3        +0.012 +                     neutral   (disqualified: random wins over 20%)
Combo chain = false                +0.011 +                     neutral   (disqualified: random wins over 20%)
Surge meter = false                +0.009 +                     neutral   (disqualified: random wins over 20%)
Enemy damage x = 2                 +0.008 +                     neutral   (disqualified: random wins over 20%)
Tracking attack share = 0          +0.003                       neutral   (disqualified: stalls, random wins over 20%)
Exhaust = false                    +0.001                       neutral   (disqualified: random wins over 20%)
Enemies avoid edges = false        +0.001                       neutral   (disqualified: stalls, random wins over 20%)
Kill refund = off                  +0.001                       neutral   (disqualified: random wins over 20%)
Split move = false                 +0.001                       neutral   (disqualified: random wins over 20%)
Ledge fall damage = 1              +0.000                       neutral   (disqualified: random wins over 20%)
Pit damage to party = 5            +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Party HP scale = 0.25              +0.000                       neutral   (disqualified: random wins over 20%)
Pit damage to party = 1            +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Pits kill enemies = false          +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Collision damage = 4               +0.000                       neutral   (disqualified: random wins over 20%)
Collision damage = 3               +0.000                       neutral   (disqualified: random wins over 20%)
Enemy abilities tier = 2           +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Quicks per turn = 0                +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Quicks per turn = 2                +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Undo = stack                       +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Undo = off                         +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Enemy abilities tier = 1           +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Shift damage per round = 3         +0.000                       neutral   (disqualified: random wins over 20%)
Round cap = 0                      +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Draw per turn = 2                  +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Draw per turn = 3                  +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Blind = miss_chance                +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Hard hit x = 3                     +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Max MP = 0                         +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Max MP = 4                         +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Max MP = 8                         +0.000                       neutral   (disqualified: stalls, random wins over 20%)
MP per turn = 1                    +0.000                       neutral   (disqualified: stalls, random wins over 20%)
MP per turn = 3                    +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Hard hit x = 1.5                   +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Telegraph timing = before_acting   -0.001                       neutral   (disqualified: stalls, random wins over 20%)
Collision damage = 1               -0.001                       neutral   (disqualified: stalls, random wins over 20%)
Actions per turn = 2               -0.001                       neutral   (disqualified: random wins over 20%)
Keep leftover cards = false        -0.002                       neutral   (disqualified: random wins over 20%)
Class decks = game                 -0.003                       neutral   (disqualified: random wins over 20%)
Enemy damage scale = 0.8           -0.003                       neutral   (disqualified: random wins over 20%)
Damage scale = 0.3                 -0.004                       neutral   (disqualified: random wins over 20%)
Hand size = 6                      -0.004                       neutral   (disqualified: random wins over 20%)
Misses = true                      -0.006 -                     neutral   (disqualified: stalls, random wins over 20%)
Surge size = 8                     -0.006 -                     neutral   (disqualified: random wins over 20%)
Enemy damage scale = 0.4           -0.007 -                     neutral   (disqualified: random wins over 20%)
Enemy HP x = 2                     -0.007 -                     neutral   (disqualified: stalls, random wins over 20%)
Enemy damage x = 1.5               -0.007 -                     neutral   (disqualified: random wins over 20%)
Discard cards = false              -0.008 -                     neutral   (disqualified: random wins over 20%)
Turn structure = initiative        -0.008 -                     neutral   (disqualified: random wins over 20%)
Enemy damage scale = 0.6           -0.008 -                     neutral   (disqualified: random wins over 20%)
Weak points = true                 -0.008 -                     neutral   (disqualified: stalls, random wins over 20%)
Move is separate = false           -0.009 -                     neutral   (disqualified: stalls, random wins over 20%)
Morale = true                      -0.009 -                     neutral   (disqualified: stalls, random wins over 20%)
Enemy damage x = 3                 -0.010 -                     neutral   (disqualified: random wins over 20%)
Enemy HP scale = 0.35              -0.010 -                     neutral   (disqualified: random wins over 20%)
All cards cost MP = false          -0.011 -                     neutral   (disqualified: random wins over 20%)
Party HP scale = 0.45              -0.011 -                     neutral   (disqualified: random wins over 20%)
Crits = true                       -0.011 -                     neutral   (disqualified: random wins over 20%)
Ledge fall damage = 4              -0.011 -                     neutral   (disqualified: random wins over 20%)
Extra enemies = 2                  -0.012 -                     neutral   (disqualified: stalls, random wins over 20%)
Extra Free and Follow-up cards = 2 -0.013 --                    neutral   (disqualified: random wins over 20%)
Enemy HP scale = 0.15              -0.014 --                    neutral   (disqualified: random wins over 20%)
Reshuffle the discard = never      -0.014 --                    neutral   (disqualified: random wins over 20%)
Draw per turn = 1                  -0.014 --                    neutral   (disqualified: random wins over 20%)
Difficulty damage multiplier = tru -0.014 --                    neutral   (disqualified: random wins over 20%)
Round cap = 10                     -0.014 --                    neutral   (disqualified: random wins over 20%)
Shift damage per round = 2         -0.014 --                    neutral   (disqualified: random wins over 20%)
Domino = true                      -0.015 --                    neutral   (disqualified: random wins over 20%)
Retreat = true                     -0.015 --                    neutral   (disqualified: random wins over 20%)
Retain = true                      -0.015 --                    neutral   (disqualified: stalls, random wins over 20%)
Reshuffle effect = hp_cost         -0.015 --                    neutral   (disqualified: stalls, random wins over 20%)
Delay = true                       -0.015 --                    neutral   (disqualified: stalls, random wins over 20%)
Hold a card = true                 -0.015 --                    neutral   (disqualified: stalls, random wins over 20%)
Upgrade in combat = true           -0.015 --                    neutral   (disqualified: stalls, random wins over 20%)
Enemy HP x = 1.5                   -0.015 --                    neutral   (disqualified: random wins over 20%)
Hand size = 3                      -0.015 --                    neutral   (disqualified: random wins over 20%)
Bonus objectives = true            -0.015 --                    neutral   (disqualified: stalls, random wins over 20%)
Fatigue on reshuffle = true        -0.015 --                    neutral   (disqualified: stalls, random wins over 20%)
Enemy HP x = 0.75                  -0.016 --                    neutral   (disqualified: random wins over 20%)
Round cap = 6                      -0.017 --                    neutral   (disqualified: random wins over 20%)
Hand size = 5                      -0.017 --                    neutral   (disqualified: random wins over 20%)
Damage scale = 0.6                 -0.018 --                    neutral   (disqualified: random wins over 20%)
Enemy HP scale = 0.5               -0.020 --                    neutral   (disqualified: stalls, random wins over 20%)
Small numbers = false              -0.022 ---                   hurts     (disqualified: stalls, random wins over 20%)
Initiative from cards = true       -0.023 ---                   hurts     (disqualified: stalls, random wins over 20%)
Kill refund = action               -0.025 ---                   hurts     (disqualified: stalls, random wins over 20%)
Body blocking = true               -0.025 ---                   hurts     (disqualified: random wins over 20%)
Reshuffle effect = surge           -0.029 ----                  hurts     (disqualified: random wins over 20%)
Overload = both                    -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
Overload = exhaust                 -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
Overload = hp                      -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
Status cards = true                -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
Enemy roles = true                 -0.030 ----                  hurts     (disqualified: random wins over 20%)
Environmental timers = true        -0.030 ----                  hurts     (disqualified: random wins over 20%)
Downed allies = carry              -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
Swap in reserves = true            -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
Waves in a fight = true            -0.030 ----                  hurts     (disqualified: random wins over 20%)
Vector weather = true              -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
Charge-up spells = true            -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
High ground = true                 -0.030 ----                  hurts     (disqualified: random wins over 20%)
Fog = true                         -0.030 ----                  hurts   
Duet cards = true                  -0.030 ----                  hurts     (disqualified: random wins over 20%)
Bond in combat = true              -0.030 ----                  hurts     (disqualified: random wins over 20%)
Enemies hit hard but rarely = true -0.038 -----                 hurts     (disqualified: random wins over 20%)
Signature card = true              -0.038 -----                 hurts     (disqualified: random wins over 20%)
Zones of control = extra_move      -0.039 -----                 hurts     (disqualified: stalls, random wins over 20%)
Class gauges = true                -0.041 -----                 hurts     (disqualified: random wins over 20%)
Teammate cards = false             -0.041 -----                 hurts     (disqualified: random wins over 20%)
Extra enemies = 1                  -0.042 -----                 hurts     (disqualified: random wins over 20%)
Cross-ally reactions = true        -0.045 -----                 hurts     (disqualified: stalls, random wins over 20%)
Lingering fields = true            -0.045 -----                 hurts     (disqualified: stalls, random wins over 20%)
Facing = true                      -0.053 ------                hurts     (disqualified: random wins over 20%)
Zones of control = free_hit        -0.053 ------                hurts     (disqualified: stalls, random wins over 20%)
Surge size = 3                     -0.056 -------               hurts     (disqualified: random wins over 20%)
Choose your order = true           -0.058 -------               hurts     (disqualified: stalls, random wins over 20%)
Props kept = 0.5                   -0.072 ---------             hurts     (disqualified: random wins over 20%)
Boss HP scale = 0.25               -0.095 ------------          hurts     (disqualified: random wins over 20%)
Props kept = 0                     -0.097 ------------          hurts     (disqualified: random wins over 20%)
Boss HP scale = 0.1                -0.139 -----------------     hurts     (disqualified: random wins over 20%)
Boss plans shown = 2               -0.164 --------------------  hurts     (disqualified: random wins over 20%)
```

Notes:

- Line of sight = true: random win rate goes down by 38 points, and telegraphed damage avoided goes up by 36 points.
- Strike costs = quick: most common winning opening goes down by 50 points, and random win rate goes up by 15 points.
- Instability rolls = false changes little.
- Ice slides = false: most-played card share goes up by 100 points, and board kills share goes up by 25 points.
- Keywords = false: novice win rate goes up by 5 points, and random win rate goes up by 5 points.
- Turn structure = alternate: most common winning opening goes down by 25 points, and card variety (entropy, 0 to 1) goes up by 0.2.
- Boss HP scale = 0.25: novice win rate goes up by 25 points, and random win rate goes up by 25 points.
- Props kept = 0: expert win rate goes up by 38 points, and most common winning opening goes up by 50 points.
- Boss HP scale = 0.1: random win rate goes up by 50 points, and novice win rate goes up by 25 points.
- Boss plans shown = 2: greedy win rate goes up by 75 points, and novice win rate goes up by 25 points.

**From cl_puzzle** (its fun score: 0.32). Score change, verdict, then the biggest metric moves:

```
Line of sight = true               +0.103 +++++++++++++         helps   
Strike costs = quick               +0.033 ++++                  helps     (disqualified: stalls, random wins over 20%)
Ice slides = false                 +0.026 +++                   helps     (disqualified: random wins over 20%)
Keywords = false                   +0.019 ++                    neutral   (disqualified: random wins over 20%)
Turn structure = alternate         +0.018 ++                    neutral   (disqualified: random wins over 20%)
Enemies hit each other = false     +0.015 ++                    neutral   (disqualified: stalls, random wins over 20%)
Terrain reactions = off            +0.014 ++                    neutral   (disqualified: random wins over 20%)
Things in the path take the shot = +0.013 ++                    neutral   (disqualified: stalls, random wins over 20%)
Tracking attack share = 0.3        +0.012 +                     neutral   (disqualified: random wins over 20%)
Combo chain = false                +0.011 +                     neutral   (disqualified: random wins over 20%)
Surge meter = false                +0.009 +                     neutral   (disqualified: random wins over 20%)
Enemy damage x = 2                 +0.008 +                     neutral   (disqualified: random wins over 20%)
Tracking attack share = 0          +0.003                       neutral   (disqualified: stalls, random wins over 20%)
Exhaust = false                    +0.001                       neutral   (disqualified: random wins over 20%)
Split move = false                 +0.001                       neutral   (disqualified: random wins over 20%)
Kill refund = off                  +0.001                       neutral   (disqualified: random wins over 20%)
Enemies avoid edges = false        +0.001                       neutral   (disqualified: stalls, random wins over 20%)
Hard hit x = 1.5                   +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Collision damage = 3               +0.000                       neutral   (disqualified: random wins over 20%)
Ledge fall damage = 1              +0.000                       neutral   (disqualified: random wins over 20%)
Pit damage to party = 5            +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Party HP scale = 0.25              +0.000                       neutral   (disqualified: random wins over 20%)
Pit damage to party = 1            +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Pits kill enemies = false          +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Collision damage = 4               +0.000                       neutral   (disqualified: random wins over 20%)
Enemy abilities tier = 2           +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Quicks per turn = 0                +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Quicks per turn = 2                +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Undo = stack                       +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Undo = off                         +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Enemy abilities tier = 1           +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Shift damage per round = 3         +0.000                       neutral   (disqualified: random wins over 20%)
Round cap = 0                      +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Draw per turn = 2                  +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Draw per turn = 3                  +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Blind = miss_chance                +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Hard hit x = 3                     +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Max MP = 0                         +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Max MP = 4                         +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Max MP = 8                         +0.000                       neutral   (disqualified: stalls, random wins over 20%)
MP per turn = 1                    +0.000                       neutral   (disqualified: stalls, random wins over 20%)
MP per turn = 3                    +0.000                       neutral   (disqualified: stalls, random wins over 20%)
Telegraph timing = before_acting   -0.001                       neutral   (disqualified: stalls, random wins over 20%)
Collision damage = 1               -0.001                       neutral   (disqualified: stalls, random wins over 20%)
Actions per turn = 2               -0.001                       neutral   (disqualified: random wins over 20%)
Keep leftover cards = false        -0.002                       neutral   (disqualified: random wins over 20%)
Enemy damage scale = 0.8           -0.003                       neutral   (disqualified: random wins over 20%)
Class decks = game                 -0.003                       neutral   (disqualified: random wins over 20%)
Hand size = 6                      -0.004                       neutral   (disqualified: random wins over 20%)
Damage scale = 0.3                 -0.004                       neutral   (disqualified: random wins over 20%)
Misses = true                      -0.006 -                     neutral   (disqualified: stalls, random wins over 20%)
Surge size = 8                     -0.006 -                     neutral   (disqualified: random wins over 20%)
Enemy damage x = 1.5               -0.007 -                     neutral   (disqualified: random wins over 20%)
Enemy HP x = 2                     -0.007 -                     neutral   (disqualified: stalls, random wins over 20%)
Enemy damage scale = 0.4           -0.007 -                     neutral   (disqualified: random wins over 20%)
Enemy damage scale = 0.6           -0.008 -                     neutral   (disqualified: random wins over 20%)
Weak points = true                 -0.008 -                     neutral   (disqualified: stalls, random wins over 20%)
Discard cards = false              -0.008 -                     neutral   (disqualified: random wins over 20%)
Turn structure = initiative        -0.008 -                     neutral   (disqualified: random wins over 20%)
Move is separate = false           -0.009 -                     neutral   (disqualified: stalls, random wins over 20%)
Morale = true                      -0.009 -                     neutral   (disqualified: stalls, random wins over 20%)
Enemy damage x = 3                 -0.010 -                     neutral   (disqualified: random wins over 20%)
Enemy HP scale = 0.35              -0.010 -                     neutral   (disqualified: random wins over 20%)
Ledge fall damage = 4              -0.011 -                     neutral   (disqualified: random wins over 20%)
Crits = true                       -0.011 -                     neutral   (disqualified: random wins over 20%)
All cards cost MP = false          -0.011 -                     neutral   (disqualified: random wins over 20%)
Party HP scale = 0.45              -0.011 -                     neutral   (disqualified: random wins over 20%)
Extra enemies = 2                  -0.012 -                     neutral   (disqualified: stalls, random wins over 20%)
Extra Free and Follow-up cards = 2 -0.013 --                    neutral   (disqualified: random wins over 20%)
Enemy HP scale = 0.15              -0.014 --                    neutral   (disqualified: random wins over 20%)
Difficulty damage multiplier = tru -0.014 --                    neutral   (disqualified: random wins over 20%)
Round cap = 10                     -0.014 --                    neutral   (disqualified: random wins over 20%)
Shift damage per round = 2         -0.014 --                    neutral   (disqualified: random wins over 20%)
Reshuffle the discard = never      -0.014 --                    neutral   (disqualified: random wins over 20%)
Draw per turn = 1                  -0.014 --                    neutral   (disqualified: random wins over 20%)
Enemy HP x = 1.5                   -0.015 --                    neutral   (disqualified: random wins over 20%)
Hold a card = true                 -0.015 --                    neutral   (disqualified: stalls, random wins over 20%)
Delay = true                       -0.015 --                    neutral   (disqualified: stalls, random wins over 20%)
Upgrade in combat = true           -0.015 --                    neutral   (disqualified: stalls, random wins over 20%)
Retain = true                      -0.015 --                    neutral   (disqualified: stalls, random wins over 20%)
Reshuffle effect = hp_cost         -0.015 --                    neutral   (disqualified: stalls, random wins over 20%)
Bonus objectives = true            -0.015 --                    neutral   (disqualified: stalls, random wins over 20%)
Retreat = true                     -0.015 --                    neutral   (disqualified: random wins over 20%)
Domino = true                      -0.015 --                    neutral   (disqualified: random wins over 20%)
Hand size = 3                      -0.015 --                    neutral   (disqualified: random wins over 20%)
Fatigue on reshuffle = true        -0.015 --                    neutral   (disqualified: stalls, random wins over 20%)
Enemy HP x = 0.75                  -0.016 --                    neutral   (disqualified: random wins over 20%)
Round cap = 6                      -0.017 --                    neutral   (disqualified: random wins over 20%)
Hand size = 5                      -0.017 --                    neutral   (disqualified: random wins over 20%)
Damage scale = 0.6                 -0.018 --                    neutral   (disqualified: random wins over 20%)
Enemy HP scale = 0.5               -0.020 --                    hurts     (disqualified: stalls, random wins over 20%)
Small numbers = false              -0.022 ---                   hurts     (disqualified: stalls, random wins over 20%)
Initiative from cards = true       -0.023 ---                   hurts     (disqualified: stalls, random wins over 20%)
Kill refund = action               -0.025 ---                   hurts     (disqualified: stalls, random wins over 20%)
Body blocking = true               -0.025 ---                   hurts     (disqualified: random wins over 20%)
Reshuffle effect = surge           -0.029 ----                  hurts     (disqualified: random wins over 20%)
Bond in combat = true              -0.030 ----                  hurts     (disqualified: random wins over 20%)
Duet cards = true                  -0.030 ----                  hurts     (disqualified: random wins over 20%)
Fog = true                         -0.030 ----                  hurts   
Overload = both                    -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
Overload = exhaust                 -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
Status cards = true                -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
Enemy roles = true                 -0.030 ----                  hurts     (disqualified: random wins over 20%)
Downed allies = carry              -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
Swap in reserves = true            -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
Waves in a fight = true            -0.030 ----                  hurts     (disqualified: random wins over 20%)
Environmental timers = true        -0.030 ----                  hurts     (disqualified: random wins over 20%)
Instability rolls = true           -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
High ground = true                 -0.030 ----                  hurts     (disqualified: random wins over 20%)
Charge-up spells = true            -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
Overload = hp                      -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
Vector weather = true              -0.030 ----                  hurts     (disqualified: stalls, random wins over 20%)
Signature card = true              -0.038 -----                 hurts     (disqualified: random wins over 20%)
Enemies hit hard but rarely = true -0.038 -----                 hurts     (disqualified: random wins over 20%)
Zones of control = extra_move      -0.039 -----                 hurts     (disqualified: stalls, random wins over 20%)
Teammate cards = false             -0.041 -----                 hurts     (disqualified: random wins over 20%)
Class gauges = true                -0.041 -----                 hurts     (disqualified: random wins over 20%)
Extra enemies = 1                  -0.042 -----                 hurts     (disqualified: random wins over 20%)
Cross-ally reactions = true        -0.045 -----                 hurts     (disqualified: stalls, random wins over 20%)
Lingering fields = true            -0.045 -----                 hurts     (disqualified: stalls, random wins over 20%)
Facing = true                      -0.053 ------                hurts     (disqualified: random wins over 20%)
Zones of control = free_hit        -0.053 ------                hurts     (disqualified: stalls, random wins over 20%)
Surge size = 3                     -0.056 -------               hurts     (disqualified: random wins over 20%)
Choose your order = true           -0.058 -------               hurts     (disqualified: stalls, random wins over 20%)
Props kept = 0.5                   -0.072 ---------             hurts     (disqualified: random wins over 20%)
Boss HP scale = 0.25               -0.095 ------------          hurts     (disqualified: random wins over 20%)
Props kept = 0                     -0.097 ------------          hurts     (disqualified: random wins over 20%)
Boss HP scale = 0.1                -0.139 -----------------     hurts     (disqualified: random wins over 20%)
Boss plans shown = 2               -0.164 --------------------  hurts     (disqualified: random wins over 20%)
```

Notes:

- Line of sight = true: random win rate goes down by 38 points, and telegraphed damage avoided goes up by 36 points.
- Strike costs = quick: most common winning opening goes down by 50 points, and random win rate goes up by 15 points.
- Ice slides = false: most-played card share goes up by 100 points, and board kills share goes up by 25 points.
- Keywords = false: novice win rate goes up by 5 points, and random win rate goes up by 5 points.
- Turn structure = alternate: most common winning opening goes down by 25 points, and card variety (entropy, 0 to 1) goes up by 0.2.
- Enemies hit each other = false: rounds (boss) goes down by 0.8, and real choices per turn goes up by 0.2.
- Boss HP scale = 0.25: novice win rate goes up by 25 points, and random win rate goes up by 25 points.
- Props kept = 0: expert win rate goes up by 38 points, and most common winning opening goes up by 50 points.
- Boss HP scale = 0.1: random win rate goes up by 50 points, and novice win rate goes up by 25 points.
- Boss plans shown = 2: greedy win rate goes up by 75 points, and novice win rate goes up by 25 points.

### Pairs (top 12 levers on cl_puzzle, 5280 fights)

| pair | score | alone | verdict |
|---|---|---|---|
| Keywords false + Strike costs quick | 0.464 (dq) | 0.429 / 0.415 | good together |
| Terrain reactions off + Surge meter false | 0.449 (dq) | 0.410 / 0.405 | good together |
| Enemy damage x 2 + Keywords false | 0.448 (dq) | 0.415 / 0.404 | good together |
| Combo chain false + Surge meter false | 0.446 (dq) | 0.407 / 0.405 | good together |
| Strike costs quick + Surge meter false | 0.445 (dq) | 0.429 / 0.405 | adds up |
| Ice slides false + Strike costs quick | 0.444 (dq) | 0.429 / 0.301 | adds up |
| Enemies hit each other false + Strike costs quick | 0.444 (dq) | 0.429 / 0.411 | adds up |
| Combo chain false + Keywords false | 0.440 (dq) | 0.415 / 0.407 | good together |
| Things in the path take the shot false + Strike costs quick | 0.440 (dq) | 0.429 / 0.409 | adds up |
| Keywords false + Surge meter false | 0.435 (dq) | 0.415 / 0.405 | adds up |
| Keywords false + Turn structure alternate | 0.433 (dq) | 0.415 / 0.414 | adds up |
| Keywords false + Enemies hit each other false | 0.430 (dq) | 0.415 / 0.411 | adds up |
| Ice slides false + Keywords false | 0.430 (dq) | 0.301 / 0.415 | adds up |
| Combo chain false + Strike costs quick | 0.430 (dq) | 0.429 / 0.407 | adds up |
| Enemies hit each other false + Turn structure alternate | 0.429 (dq) | 0.414 / 0.411 | adds up |
| Keywords false + Terrain reactions off | 0.429 (dq) | 0.415 / 0.410 | adds up |
| Things in the path take the shot false + Turn structure alternate | 0.429 (dq) | 0.414 / 0.409 | adds up |
| Ice slides false + Turn structure alternate | 0.429 (dq) | 0.301 / 0.414 | adds up |
| Enemy damage x 2 + Turn structure alternate | 0.428 (dq) | 0.414 / 0.404 | adds up |
| Keywords false + Things in the path take the shot false | 0.428 (dq) | 0.415 / 0.409 | adds up |
| Keywords false + Tracking attack share 0.3 | 0.427 (dq) | 0.415 / 0.408 | adds up |
| Surge meter false + Tracking attack share 0.3 | 0.426 (dq) | 0.408 / 0.405 | adds up |
| Surge meter false + Turn structure alternate | 0.425 (dq) | 0.414 / 0.405 | adds up |
| Terrain reactions off + Enemies hit each other false | 0.425 (dq) | 0.411 / 0.410 | adds up |
| Ice slides false + Terrain reactions off | 0.425 (dq) | 0.301 / 0.410 | adds up |
| Things in the path take the shot false + Enemies hit each other false | 0.424 (dq) | 0.411 / 0.409 | adds up |
| Things in the path take the shot false + Terrain reactions off | 0.423 (dq) | 0.410 / 0.409 | adds up |
| Ice slides false + Tracking attack share 0.3 | 0.423 (dq) | 0.301 / 0.408 | adds up |
| Things in the path take the shot false + Tracking attack share 0.3 | 0.422 (dq) | 0.409 / 0.408 | adds up |
| Combo chain false + Enemies hit each other false | 0.422 (dq) | 0.411 / 0.407 | adds up |
| Combo chain false + Ice slides false | 0.422 (dq) | 0.301 / 0.407 | adds up |
| Combo chain false + Things in the path take the shot false | 0.421 (dq) | 0.409 / 0.407 | adds up |
| Enemies hit each other false + Tracking attack share 0.3 | 0.420 (dq) | 0.411 / 0.408 | adds up |
| Enemies hit each other false + Surge meter false | 0.420 (dq) | 0.411 / 0.405 | adds up |
| Ice slides false + Surge meter false | 0.420 (dq) | 0.301 / 0.405 | adds up |
| Enemy damage x 2 + Ice slides false | 0.419 (dq) | 0.301 / 0.404 | adds up |
| Enemy damage x 2 + Enemies hit each other false | 0.418 (dq) | 0.411 / 0.404 | adds up |
| Combo chain false + Turn structure alternate | 0.418 (dq) | 0.414 / 0.407 | adds up |
| Things in the path take the shot false + Surge meter false | 0.418 (dq) | 0.409 / 0.405 | adds up |
| Line of sight true + Strike costs quick | 0.418 (dq) | 0.421 / 0.429 | adds up |
| Enemy damage x 2 + Things in the path take the shot false | 0.417 (dq) | 0.409 / 0.404 | adds up |
| Ice slides false + Enemies hit each other false | 0.412 (dq) | 0.301 / 0.411 | adds up |
| Enemy damage x 2 + Surge meter false | 0.411 (dq) | 0.405 / 0.404 | adds up |
| Ice slides false + Things in the path take the shot false | 0.411 (dq) | 0.301 / 0.409 | adds up |
| Terrain reactions off + Strike costs quick | 0.411 (dq) | 0.429 / 0.410 | adds up |
| Combo chain false + Tracking attack share 0.3 | 0.407 (dq) | 0.408 / 0.407 | adds up |
| Strike costs quick + Turn structure alternate | 0.402 (dq) | 0.429 / 0.414 | adds up |
| Keywords false + Line of sight true | 0.402 (dq) | 0.421 / 0.415 | adds up |
| Enemy damage x 2 + Tracking attack share 0.3 | 0.399 (dq) | 0.408 / 0.404 | adds up |
| Combo chain false + Enemy damage x 2 | 0.397 (dq) | 0.407 / 0.404 | adds up |
| Enemy damage x 2 + Strike costs quick | 0.396 (dq) | 0.429 / 0.404 | adds up |
| Combo chain false + Line of sight true | 0.395 (dq) | 0.421 / 0.407 | adds up |
| Line of sight true + Tracking attack share 0.3 | 0.395 (dq) | 0.421 / 0.408 | adds up |
| Strike costs quick + Tracking attack share 0.3 | 0.395 (dq) | 0.429 / 0.408 | adds up |
| Line of sight true + Terrain reactions off | 0.394 (dq) | 0.421 / 0.410 | adds up |
| Line of sight true + Surge meter false | 0.392 (dq) | 0.421 / 0.405 | adds up |
| Enemy damage x 2 + Line of sight true | 0.391 (dq) | 0.421 / 0.404 | adds up |
| Combo chain false + Terrain reactions off | 0.388 (dq) | 0.410 / 0.407 | adds up |
| Line of sight true + Turn structure alternate | 0.387 (dq) | 0.421 / 0.414 | bad together |
| Enemy damage x 2 + Terrain reactions off | 0.385 (dq) | 0.410 / 0.404 | adds up |
| Line of sight true + Things in the path take the shot false | 0.384 (dq) | 0.421 / 0.409 | bad together |
| Line of sight true + Enemies hit each other false | 0.384 (dq) | 0.421 / 0.411 | bad together |
| Ice slides false + Line of sight true | 0.384 (dq) | 0.421 / 0.301 | adds up |
| Terrain reactions off + Tracking attack share 0.3 | 0.366 (dq) | 0.410 / 0.408 | bad together |
| Terrain reactions off + Turn structure alternate | 0.363 (dq) | 0.414 / 0.410 | bad together |
| Tracking attack share 0.3 + Turn structure alternate | 0.348 (dq) | 0.414 / 0.408 | bad together |

Good together: 5 pairs. Bad together: 6 pairs.

### The search and the shortlist

Base: cl_puzzle. 288 lever sets tried over 24 generations; 7 finalists played every fight, 20 seeds, 3 parties. A finalist's score is its worst party's.

Search space: Line of sight, Strike costs, Ice slides, Keywords, Turn structure, Enemies hit each other, Terrain reactions, Things in the path take the shot, Tracking attack share, Combo chain, Surge meter, Enemy damage x, Enemies avoid edges, Exhaust, Kill refund, Enemy HP x, Party HP scale, Enemy HP scale, Extra enemies.

**tuned_1** (score 0.718): Combo chain off, Enemies avoid edges off, Enemy damage x 4, Enemy HP x 3, Exhaust off, Extra enemies 2, Keywords off, Kill refund off, Line of sight on, Party HP scale 0.16, Things in the path take the shot off, Enemies hit each other off, Strike costs quick, Surge meter off, Tracking attack share -1, Turn structure alternate.

**tuned_2** (score 0.696): Enemies avoid edges off, Enemy damage x 4, Enemy HP x 3, Exhaust off, Extra enemies 2, Ice slides off, Keywords off, Line of sight on, Enemies hit each other off, Strike costs quick, Surge meter off, Tracking attack share -1, Turn structure alternate.

**tuned_3** (score 0.681): Enemies avoid edges off, Enemy damage x 4, Enemy HP x 3, Exhaust off, Extra enemies 2, Ice slides off, Keywords off, Kill refund action, Line of sight on, Party HP scale 0.25, Things in the path take the shot off, Terrain reactions off, Strike costs quick, Surge meter off, Turn structure alternate.

**tuned_4** (score 0.678): Enemies avoid edges off, Enemy damage x 4, Enemy HP x 3, Exhaust off, Extra enemies 2, Keywords off, Kill refund off, Line of sight on, Things in the path take the shot off, Enemies hit each other off, Strike costs quick, Surge meter off, Tracking attack share 0, Turn structure alternate.

**tuned_5** (score 0.661): Enemies avoid edges off, Enemy damage x 4, Enemy HP x 3, Exhaust off, Extra enemies 2, Ice slides off, Keywords off, Line of sight on, Party HP scale 0.25, Terrain reactions off, Enemies hit each other off, Strike costs quick, Surge meter off, Turn structure alternate.

### Shortlist re-run (3840 fights, 2026-11-08T07:22:46)

|  | score | ok | exp | nov | grd | rnd | real | obv | load | close | rnds | boss | agcy | board | team | var | dom | line |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cl_base | 0.38 | no: stalls, random wins over 20% | 94% | 93% | 88% | 69% | 3.0 | 15% | 16.8 | 0% | 3.4 | 10.0 | 94% | 20% | 0.2 | 0.9 | 16% | 100% |
| current | 0.37 | no: random wins over 20% | 99% | 99% | 93% | 37% | 4.0 | 13% | 5.2 | 0% | 2.6 | 4.4 | 96% | 7% | 0.0 | 0.9 | 8% | 25% |
| tuned_1 | 0.61 | no: stalls | 91% | 91% | 82% | 18% | 3.4 | 12% | 15.8 | 0% | 4.3 | 7.9 | 85% | 15% | 0.4 | 0.9 | 17% | 87% |
| tuned_2 | 0.48 | no: stalls | 90% | 91% | 67% | 20% | 3.4 | 12% | 17.1 | 0% | 5.9 | 7.1 | 96% | 17% | 0.3 | 0.9 | 12% | 100% |

Columns: **exp** Expert win rate (target 85% to 95%); **nov** Novice win rate (target 50% to 70%); **grd** Greedy win rate (target at most 50%); **rnd** Random win rate (target at most 10%); **real** Real choices per turn (target 2.0 to 4.0); **obv** Obvious turn share (target at most 35%); **load** Option load (target at most 40.0); **close** Close wins (target 25% to 45%); **rnds** Rounds (normal fights) (target 3.0 to 5.0); **boss** Rounds (boss) (target 6.0 to 8.0); **agcy** Telegraphed damage avoided (target 50% to 80%); **board** Board kills share (target 25% to 50%); **team** Teamwork plays per fight (target at least 2.0); **var** Card variety (entropy, 0 to 1) (target at least 0.6); **dom** Most-played card share (target at most 25%); **line** Most common winning opening (target at most 60%). **score** is the fun score (0 to 1, minus complexity); **ok** says whether a hard limit disqualifies it.

### Agent rating cards (80 fights)

| | fights | fun | options | felt clever |
|---|---|---|---|---|
| breaker (persona) | 16 | 2.9 | 2.6 | 38% |
| casual (persona) | 16 | 3.4 | 2.6 | 25% |
| deckbuilder (persona) | 16 | 3.1 | 3.1 | 56% |
| newcomer (persona) | 16 | 3.3 | 2.6 | 19% |
| tactician (persona) | 16 | 2.9 | 3.2 | 50% |
| cl_base (preset) | 20 | 3.0 | 2.7 | 45% |
| current (preset) | 20 | 3.0 | 3.1 | 25% |
| tuned_1 (preset) | 20 | 3.3 | 2.8 | 45% |
| tuned_2 (preset) | 20 | 3.1 | 2.7 | 35% |

## Why the shortlist is scaled, and what didn't pass (2026-11-08)

**No lever set passed every hard limit.** `tuned_1` and `tuned_2` are the two best candidates. Both carry `"passed": false` and say so in their text. The limits in `data/lab/tuner.json` were not changed.

| Attempt | Fights | Result |
| --- | --- | --- |
| Search finalists (one global difficulty, enemy damage x4, HP x3) | 7 sets | All failed. Expert 42 to 51%. Easy fights near 100%, hard fights 0 to 13%. |
| Difficulty ladder (milder global levels) | 12,960 | 0 of 15 sets passed. Random play won too often at mild levels; the expert lost too often at hard ones. |
| Scaled, per-fight difficulty, first pick | about 8,000 with the scan | Expert 80 to 96%, random 15 to 29%, 5 stalls in 2,880. |
| Scaled, pick floor lowered to 70%, four fights set by hand | re-check | Best set: expert 76 to 95%, every fight 63% or better, random 4 to 24%. |

**Why the best set still fails:** one stall in 1,440 fights (the limit is zero), and random play at 24% with the melee party (the limit is 20%). Random play's melee wins come mostly from Flood Drill and Hold the Line, at 7 of 10. Those fights' wins don't depend much on fighting well: rising water does the work in one, and the other is survive 4 rounds. They need changes to the fights, not more difficulty.

**How the scaled sets were picked.** Each fight is scanned at 9 difficulty steps, and one step is picked (`data/lab/sweeps/scaled.json`, `pick`), then re-tested on 10 new seeds with every AI and party. Flood Drill, Hold the Line, Hollow Mascot and Hand-Off are set by hand in `pick.force`; that is a judgement call, not a search result.

**Limits of the numbers:**
- The sweeps ran at about 4 to 8 fights a second, under the doc's target of 20.
- Ladder fights used 6 seeds, not 20. The scaled scan used 4 and its check used 10. The shortlist re-run used 20.
- The novice AI wins about as often as the expert under every preset, including `current`. The AI's skill gap is not measuring player skill.
- Close wins stay at 0 to 2% against a target of 25 to 45%. Scaling fixed who wins, but not how close it feels.

## Agent playtest (80 fights, 2026-11-08)

Five personas played four fights (Ledge Day, Fire Sale, Hand-Off, Hollow Mascot) under each preset, through the text interface only. That is 80 of the planned 140 fights: with two candidates, there were no more presets to play. These ratings are AI opinions, not player data.

| Preset | Fun (1 to 5) | Options felt | Felt clever | Agent results |
| --- | --- | --- | --- | --- |
| `tuned_1` | 3.30 | 2.8 | 9 of 20 | 20 wins |
| `tuned_2` | 3.15 | 2.7 | 7 of 20 | 17 wins, 3 losses (all Fire Sale) |
| `current` | 3.05 | 3.1 | 5 of 20 | 20 wins |
| `cl_base` | 3.00 | 2.7 | 9 of 20 | 20 wins |

| Persona | `tuned_1` | `tuned_2` | `current` | `cl_base` |
| --- | --- | --- | --- | --- |
| Newcomer | 3.25 | 3.25 | 3.25 | 3.25 |
| Tactician | 3.25 | 2.75 | 3.00 | 2.75 |
| Deckbuilder | 3.50 | 3.25 | 3.00 | 2.75 |
| Casual | 3.50 | 3.25 | 3.25 | 3.50 |
| Breaker | 3.00 | 3.25 | 2.75 | 2.75 |

The gaps are small: 20 ratings per preset, on whole numbers from 1 to 5. Treat them as a lean, not a result.

### Where agents and metrics disagree

- **Machine says the tuned presets are harder; agents say they are still solved.** Random play falls to 18 to 20%, yet 17 of 20 agent fights on `tuned_2` and all 20 on `tuned_1` were wins, and all five personas report the same trick (below).
- **Machine scores don't see the exploit.** The AI's agency score is high (0.82 to 0.97) because it dodges telegraphs. Agents call that same dodging the reason fights feel solved.
- **`tuned_2` scores lower on the machine (0.47 vs 0.60) and only slightly lower with agents**, but it is the only preset that made agents lose.

### What the Breaker and others found (to check in sweeps)

1. **Hit, then step off.** Locked telegraphs are voided by one step when the target acts before the attacker, and split move lets you hit and leave. All five personas reported it, on both presets. The Breaker counted one attack landing in 14 rounds on `tuned_1`.
2. **Two Strikes a turn.** On `tuned_1`, the Strike card (Action) plus the basic Strike (Quick) deals about 8 for 0 MP on Brick.
3. **Basic Strike out-hits cards.** It costs 0 MP and hits for 4 where Finisher hits for 3.
4. **The boss can die in round 2.** Hollow Mascot has 27 HP under the scaled picks. Strike plus Heavy Slam from behind took most of it. Crossing its phase line also cancels its attack.
5. **Surge is never spent.** Dodging fills it and cards cost 0 or 1 MP.
6. **Fire decides fights.** Enemies walk through burning tiles. One Steam Vent did huge damage.

### Dead or thin cards

Pass, Setup and Borrow sit unused unless the player is hunting for engines (the Deckbuilder loved them). Afterimage Step was never playable. Deep Pocket can fizzle and still spend the Action. Heavy forbids moving first, which makes it nearly dead on melee.

### Clarity bugs

**Fixed:**
- Enemy-phase damage, knockdowns and pushes now show in `lab_play`'s log. They were missing, which caused many "what just happened" reports.
- The goal line says when one hero going down loses the fight. That rule is real (`playerDownEndsFight`) and was never stated; it explains the Fire Sale losses.
- Keywords that do nothing under a preset's levers no longer print on cards.
- The Keywords hint now defines Free, Swift, Heavy and Follow-up. Swift spends the Action and gives the Move back.
- The "attacks of about 1 to 4" hint now says that's before difficulty.

**Still open:**
- Borrow previews a push that may not happen after a Strike.
- Enemy plans list allies as hit, though enemies don't hurt each other.
- Some plans read "? 0 damage", and several enemies can plan the same tile.
- Under alternate turns, it's unclear which plans fire before you can respond.
- "Works the tiles" says nothing about what a card does, and Ash can get 45 or more tile options.
- The Strike card and Strike step look alike, cost different things, and only the card targets props.
- "Blocked, loses its attack" and opportunity strikes are unexplained.
- Cards are refused with no reason given (probably line of sight).
- The goal-line warning is in `lab_play` only. The combat screen doesn't show it yet.

**Not reproduced:** the Breaker reported Hollow Mascot ending with the boss at 2/27 HP. The end check requires every enemy to be dead, so the boss most likely died to something the old log didn't print.

### Quotes

- "The boss had three scary attacks queued and never got to use one." (Breaker, `tuned_1`)
- "The first fight where I was building turns across two decks, and I want a lot more of this." (Deckbuilder, `tuned_1`)
- "One great Slam and then five rounds of tickling two big guys who could never catch me." (Casual, `tuned_2`)
- "A boss that loses most of its health offscreen and rearranges the board without telling me is the exact opposite of why I play this genre." (Tactician, `tuned_2`)
- "Blowing up barrels is great, but nothing ever actually hit me because I always got to move first." (Newcomer, `tuned_1`)

## Final ranking (LT Part 6)

No preset passed every limit, so this ranks the best available. Your ratings outrank all of it.

1. **`tuned_1` (does not pass).** A trimmed rule set: Keywords, Surge, Exhaust, redirect and path blocking off, line of sight on, alternating turns, per-fight difficulty.
   - **Strongest:** the best agent ratings of the four (3.30), the highest machine score, and skill matters (random 18%, expert 91%).
   - **Weakest:** it removes a lot of what makes the Lab's combat distinctive, and Strike twice a turn lets fights end early.
2. **`tuned_2` (does not pass).** Plain `cl_puzzle` rules with per-fight difficulty only.
   - **Strongest:** keeps every rule, and it's the only preset that beat the agents (Fire Sale). It also punishes greedy play most (67%).
   - **Weakest:** Hand-Off drags (2.4 fun, 8 to 10 rounds), and random play still wins Hold the Line and Flood Drill often.
3. **`current` (today's rules, also fails the limits).**
   - **Strongest:** no stalls, and it's what the game plays like today.
   - **Weakest:** expert 99% and random 37%, so fights barely challenge anyone.

**Before any of these ships, three things need attention, whichever you pick:** the hit-then-step-off exploit, Flood Drill and Hold the Line, and the 30-round stalls on Hollow Mascot and Hand-Off.

## Hit-then-step-off and the turn grid (2026-11-08)

Fired Up alone did not fix it: telegraphed damage avoided went from 86% to 83% on `tuned_1` and stayed 96% on `tuned_2`, within noise, because enemy hits (7 to 15) outweigh a bonus of 3 to 5.

**Turn grid** (`data/lab/sweeps/turn_grid.json`; 20 setups, 12 fights, 6 seeds, 4 AIs, `tuned_1` plus two `tuned_2` checks, all with Fired Up on):

| Change | Expert | Random | Rounds | Note |
| --- | --- | --- | --- | --- |
| Fired Up only (reference) | 93% | 18% | 4.2 | |
| Quicks 0 or 2 | 93% | 18% | 4.2 | No change at all: the AI never plays two Quick cards in a turn, so this lever is untested in practice |
| Strike costs an Action | 89% | 7% | 5.8 | Removes the double Strike |
| Move or act (1 action, no separate move) | 85% | 24% | 6.4 | 4 stalls |
| 2 Actions, move separate off | 96% | 13% | 3.7 | Fights get too easy |
| 3 Actions, move separate off | 96% | 19% | 3.0 | |
| 2 Actions, Strike an Action | 90% | 4% | 4.9 | Lowest random wins |
| 2 enemy actions | 43% | 1% | 3.1 | Close wins 23%, but nearly all damage is untelegraphed (35.6 vs 2.3) |
| Half of attacks tracking | 93% | 15% | 4.2 | Shifts about 4 damage per fight from avoidable to not |
| All attacks tracking | 90% | 21% | 4.3 | |

**Combined candidate (`ff_candidate`, Fired Up, Strike an Action, half tracking), 10 seeds:** expert 82%, novice 85%, greedy 67%, random 10%, rounds 5.4, score 0.642, against `tuned_1` at 90%, 91%, 78%, 15%, 4.3, 0.628. It still has one stall in 480, so it does not pass the zero-stall limit, and it carries `tuned_1`'s per-fight steps without re-tuning them. The "avoided" metric only counts telegraphed attacks, so it cannot show tracking working.

Screening's flat results for `actionsPerTurn` were a test fault: with `moveSeparate` on, that lever is ignored.

