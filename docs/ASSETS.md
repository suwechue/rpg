# Assets

Generated from `data/assets/manifest.json` by `tools/gen_assets_doc.gd`. Don't edit by hand; run the tool again after changing the manifest:

`& "<godot>" --headless --path . -s res://tools/gen_assets_doc.gd`

## How to replace art

1. Find the asset below. Its **id** is the file name you'll use.
2. Draw it at the **target size**, with the frame layout shown. Save it as PNG (sounds: OGG or WAV; fonts: TTF or OTF).
3. Put it in `assets/custom/<type>/<id>.png`, for example `assets/custom/portraits/portrait_kelly.png`. Plain `assets/custom/<id>.png` works too.
4. Run the game. If it's already running, press **F1 > Art > Reload custom art**.
5. Tick the box here so you can see what's left.

No code or manifest changes are needed. Delete your file to go back to the pack art. If a file is missing or broken the game shows a magenta square with the id written on it instead of crashing.

Sizes: tiles 32x32, characters 32x32 (up to 32x48 for tall ones), portraits 64x64, card art 48x48, icons 16x16 (UI) or 32x32 (items). The game runs at 640x360 and scales up by whole numbers.

Pack art is a placeholder: the 16x16 packs are scaled up 2x (nearest neighbour) to fit the 32x32 grid until you replace them.

Replaced so far: Characters (walk sheets) 0/39, Portraits 0/35, Enemies and bosses 0/52, Tilesets 0/4, Single tiles 0/120, UI 0/19, Icons 0/26, Card art 0/11, VFX 0/0, Music 0/30, Sound effects 0/38, Ambience 0/9, Voice blips 0/10.

## Characters (walk sheets) (39)

Walk sheets: 4 columns (facing down, up, left, right), 4 rows (the walk cycle), each frame the target size, feet at the bottom center. Bosses are one row of idle frames.

| Done | Id | Target size | Layout | Anchor | Source | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | `npc_baxter_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_biology_teacher_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_blacksmith_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_coach_byrne_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_dex_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_diane_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_dr_reyes_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_earth_science_teacher_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_gary_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_innocent_bystander_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_jake_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_jon_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_kara_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_kayla_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_kelly_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_kris_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_mara_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_mayor_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_mel_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_mr_b_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_mr_j_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_mr_mustard_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_ms_g_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_ms_marlowe_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_ms_nonsense_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_narrator_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_parent_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_patti_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_penny_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_phase_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_priya_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_sam_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_sam_unmasked_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_theo_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `npc_todd_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `player_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure | The player character. |
| [ ] | `debug_ally_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure | Debug-menu party members. |
| [ ] | `dungeon_event_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure | Event figure in Upside-Down rooms. |
| [ ] | `dungeon_merchant_walk` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure | The Upside-Down merchant. |

## Portraits (35)

Faces shown when you talk to someone.

| Done | Id | Target size | Layout | Anchor | Source | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | `portrait_baxter` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_biology_teacher` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_blacksmith` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_coach_byrne` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_dex` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_diane` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_dr_reyes` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_earth_science_teacher` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_gary` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_innocent_bystander` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_jake` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_jon` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_kara` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_kayla` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_kelly` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_kris` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_mara` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_mayor` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_mel` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_mr_b` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_mr_j` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_mr_mustard` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_ms_g` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_ms_marlowe` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_ms_nonsense` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_narrator` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_parent` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_patti` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_penny` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_phase` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_priya` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_sam` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_sam_unmasked` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_theo` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |
| [ ] | `portrait_todd` | 64x64 | - | top left | pack: ninja_adventure | Face and shoulders, readable at 1x. |

## Enemies and bosses (52)

Walk sheets: 4 columns (facing down, up, left, right), 4 rows (the walk cycle), each frame the target size, feet at the bottom center. Bosses are one row of idle frames.

| Done | Id | Target size | Layout | Anchor | Source | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | `enemy_hollow_mascot` | 60x60 frames x 6 (strip 360x60) | frames in one row, left to right (idle) | bottom center (feet) | pack: ninja_adventure | Boss: 64x64 or larger. |
| [ ] | `enemy_cold_cut` | 62x52 frames x 5 (strip 310x52) | frames in one row, left to right (idle) | bottom center (feet) | pack: ninja_adventure | Boss: 64x64 or larger. |
| [ ] | `enemy_forge_revenant` | 50x50 frames x 5 (strip 250x50) | frames in one row, left to right (idle) | bottom center (feet) | pack: ninja_adventure | Boss: 64x64 or larger. |
| [ ] | `enemy_night_ward` | 50x50 frames x 5 (strip 250x50) | frames in one row, left to right (idle) | bottom center (feet) | pack: ninja_adventure | Boss: 64x64 or larger. |
| [ ] | `enemy_mirror_town` | 50x50 frames x 5 (strip 250x50) | frames in one row, left to right (idle) | bottom center (feet) | pack: ninja_adventure | Boss: 64x64 or larger. |
| [ ] | `enemy_pom_pom_wisp` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_megaphone_mimic` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_bleacher_creeper` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_locker_lurker` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_spirit_stick` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_detention_slip` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_varsity_shade` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_frost_wolf` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_freezer_burn` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_meat_hook` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_ice_larva` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_head_chef` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_slag_imp` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_chain_wraith` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_ember_moth` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_anvil_crab` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_foreman_ghost` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_iv_wisp` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_gurney_ghoul` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_night_nurse` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_chief_of_staff` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_mirror_kid` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_glass_hound` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_town_echo` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_mr_b_aide` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_hall_rusher` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_firecracker_imp` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_nurse_moth` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_locker_hive` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_riot_shield` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_pothole` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_bell_tower_eye` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_split_slime` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_ember_crawler` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_mirror_mime` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_static_leech` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_anchor_golem` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_dust_gremlin` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_paper_wasp` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure | Palette swap of the pack sprite (tint #c9a66b) until you draw your own. |
| [ ] | `enemy_frost_mite` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure | Palette swap of the pack sprite (tint #9fdcff) until you draw your own. |
| [ ] | `enemy_slimelet` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_spark_imp` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_rust_mite` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure | Palette swap of the pack sprite (tint #c97a4a) until you draw your own. |
| [ ] | `enemy_pill_bug` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |
| [ ] | `enemy_bandage_wisp` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure | Palette swap of the pack sprite (tint #f2f2e6) until you draw your own. |
| [ ] | `enemy_glass_shard` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure | Palette swap of the pack sprite (tint #b8f0ff) until you draw your own. |
| [ ] | `enemy_echo_kid` | 32x32 frames (sheet 128x128) | 4 columns (down, up, left, right) x 4 rows (walk cycle); extra rows are ignored | bottom center (feet) | pack: ninja_adventure |  |

## Tilesets (4)

Whole tilesets. Replacing one swaps every tile in it at once (keep the same grid so tile numbers still line up).

| Done | Id | Target size | Layout | Anchor | Source | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | `tileset_town` | 32x32 tiles (sheet 384x352) | grid of 32x32 tiles, 12 columns x 11 rows; tiles are numbered left to right, top to bottom | top left | pack: kenney_tiny_town |  |
| [ ] | `tileset_city` | 32x32 tiles (sheet 384x352) | grid of 32x32 tiles, 12 columns x 11 rows; tiles are numbered left to right, top to bottom | top left | pack: kenney_tiny_city |  |
| [ ] | `tileset_interior` | 32x32 tiles (sheet 704x544) | grid of 32x32 tiles, 22 columns x 17 rows; tiles are numbered left to right, top to bottom | top left | pack: ninja_adventure |  |
| [ ] | `tileset_dungeon` | 32x32 tiles (sheet 384x352) | grid of 32x32 tiles, 12 columns x 11 rows; tiles are numbered left to right, top to bottom | top left | pack: kenney_tiny_dungeon |  |

## Single tiles (120)

Single tiles inside a tileset. Replacing one changes it everywhere it's used. Draw it at the tile size; it's pasted into its cell of the tileset.

| Done | Id | Target size | Layout | Anchor | Source | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | `tile_ground_grass_0` | 32x32 | - | top left | tile 0 of `tileset_town` |  |
| [ ] | `tile_ground_grass_1` | 32x32 | - | top left | tile 1 of `tileset_town` |  |
| [ ] | `tile_ground_grass_2` | 32x32 | - | top left | tile 2 of `tileset_town` |  |
| [ ] | `tile_ground_concrete_0` | 32x32 | - | top left | tile 88 of `tileset_city` |  |
| [ ] | `tile_ground_concrete_1` | 32x32 | - | top left | tile 100 of `tileset_city` |  |
| [ ] | `tile_ground_dirt` | 32x32 | - | top left | tile 25 of `tileset_town` |  |
| [ ] | `tile_ground_path` | 32x32 | - | top left | tile 43 of `tileset_town` |  |
| [ ] | `tile_ground_water` | 32x32 | - | top left | tile 34 of `tileset_city` |  |
| [ ] | `tile_ground_field_1` | 32x32 | - | top left | tile 42 of `tileset_town` |  |
| [ ] | `tile_road_h_top` | 32x32 | - | top left | tile 63 of `tileset_city` |  |
| [ ] | `tile_road_h_bottom` | 32x32 | - | top left | tile 75 of `tileset_city` |  |
| [ ] | `tile_road_v_left` | 32x32 | - | top left | tile 61 of `tileset_city` |  |
| [ ] | `tile_road_v_right` | 32x32 | - | top left | tile 62 of `tileset_city` |  |
| [ ] | `tile_house_red_roof_top_l` | 32x32 | - | top left | tile 52 of `tileset_town` |  |
| [ ] | `tile_house_red_roof_top_m` | 32x32 | - | top left | tile 53 of `tileset_town` |  |
| [ ] | `tile_house_red_roof_top_r` | 32x32 | - | top left | tile 54 of `tileset_town` |  |
| [ ] | `tile_house_red_roof_bottom_l` | 32x32 | - | top left | tile 64 of `tileset_town` |  |
| [ ] | `tile_house_red_roof_bottom_m` | 32x32 | - | top left | tile 65 of `tileset_town` |  |
| [ ] | `tile_house_red_roof_bottom_r` | 32x32 | - | top left | tile 66 of `tileset_town` |  |
| [ ] | `tile_house_red_roof_gable` | 32x32 | - | top left | tile 67 of `tileset_town` |  |
| [ ] | `tile_house_red_wall_l` | 32x32 | - | top left | tile 72 of `tileset_town` |  |
| [ ] | `tile_house_red_wall_m` | 32x32 | - | top left | tile 73 of `tileset_town` |  |
| [ ] | `tile_house_red_wall_r` | 32x32 | - | top left | tile 75 of `tileset_town` |  |
| [ ] | `tile_house_red_base_left` | 32x32 | - | top left | tile 84 of `tileset_town` |  |
| [ ] | `tile_house_red_base_door` | 32x32 | - | top left | tile 85 of `tileset_town` |  |
| [ ] | `tile_house_gray_roof_top_l` | 32x32 | - | top left | tile 48 of `tileset_town` |  |
| [ ] | `tile_house_gray_roof_top_m` | 32x32 | - | top left | tile 49 of `tileset_town` |  |
| [ ] | `tile_house_gray_roof_top_r` | 32x32 | - | top left | tile 50 of `tileset_town` |  |
| [ ] | `tile_house_gray_roof_bottom_l` | 32x32 | - | top left | tile 60 of `tileset_town` |  |
| [ ] | `tile_house_gray_roof_bottom_m` | 32x32 | - | top left | tile 61 of `tileset_town` |  |
| [ ] | `tile_house_gray_roof_bottom_r` | 32x32 | - | top left | tile 62 of `tileset_town` |  |
| [ ] | `tile_house_gray_roof_gable` | 32x32 | - | top left | tile 63 of `tileset_town` |  |
| [ ] | `tile_stone_red_wall_l` | 32x32 | - | top left | tile 76 of `tileset_town` |  |
| [ ] | `tile_stone_red_wall_m` | 32x32 | - | top left | tile 77 of `tileset_town` |  |
| [ ] | `tile_stone_red_wall_r` | 32x32 | - | top left | tile 79 of `tileset_town` |  |
| [ ] | `tile_stone_red_base_left` | 32x32 | - | top left | tile 88 of `tileset_town` |  |
| [ ] | `tile_stone_red_base_door` | 32x32 | - | top left | tile 89 of `tileset_town` |  |
| [ ] | `tile_shop_brick_roof_top_l` | 32x32 | - | top left | tile 0 of `tileset_city` |  |
| [ ] | `tile_shop_brick_roof_top_m` | 32x32 | - | top left | tile 1 of `tileset_city` |  |
| [ ] | `tile_shop_brick_roof_top_r` | 32x32 | - | top left | tile 2 of `tileset_city` |  |
| [ ] | `tile_shop_brick_roof_mid_l` | 32x32 | - | top left | tile 12 of `tileset_city` |  |
| [ ] | `tile_shop_brick_roof_mid_m` | 32x32 | - | top left | tile 13 of `tileset_city` |  |
| [ ] | `tile_shop_brick_roof_mid_r` | 32x32 | - | top left | tile 14 of `tileset_city` |  |
| [ ] | `tile_shop_brick_roof_bottom_l` | 32x32 | - | top left | tile 24 of `tileset_city` |  |
| [ ] | `tile_shop_brick_roof_bottom_m` | 32x32 | - | top left | tile 25 of `tileset_city` |  |
| [ ] | `tile_shop_brick_roof_bottom_r` | 32x32 | - | top left | tile 26 of `tileset_city` |  |
| [ ] | `tile_shop_brick_wall_l` | 32x32 | - | top left | tile 36 of `tileset_city` |  |
| [ ] | `tile_shop_brick_wall_m` | 32x32 | - | top left | tile 37 of `tileset_city` |  |
| [ ] | `tile_shop_brick_wall_r` | 32x32 | - | top left | tile 41 of `tileset_city` |  |
| [ ] | `tile_shop_brick_wall_window` | 32x32 | - | top left | tile 40 of `tileset_city` |  |
| [ ] | `tile_shop_brick_base_left` | 32x32 | - | top left | tile 48 of `tileset_city` |  |
| [ ] | `tile_shop_brick_base_mid` | 32x32 | - | top left | tile 49 of `tileset_city` |  |
| [ ] | `tile_shop_brick_base_right` | 32x32 | - | top left | tile 53 of `tileset_city` |  |
| [ ] | `tile_shop_brick_base_door` | 32x32 | - | top left | tile 52 of `tileset_city` |  |
| [ ] | `tile_shop_brown_roof_top_l` | 32x32 | - | top left | tile 6 of `tileset_city` |  |
| [ ] | `tile_shop_brown_roof_top_m` | 32x32 | - | top left | tile 7 of `tileset_city` |  |
| [ ] | `tile_shop_brown_roof_top_r` | 32x32 | - | top left | tile 8 of `tileset_city` |  |
| [ ] | `tile_shop_brown_roof_mid_l` | 32x32 | - | top left | tile 18 of `tileset_city` |  |
| [ ] | `tile_shop_brown_roof_mid_m` | 32x32 | - | top left | tile 19 of `tileset_city` |  |
| [ ] | `tile_shop_brown_roof_mid_r` | 32x32 | - | top left | tile 20 of `tileset_city` |  |
| [ ] | `tile_shop_brown_roof_bottom_l` | 32x32 | - | top left | tile 30 of `tileset_city` |  |
| [ ] | `tile_shop_brown_roof_bottom_m` | 32x32 | - | top left | tile 31 of `tileset_city` |  |
| [ ] | `tile_shop_brown_roof_bottom_r` | 32x32 | - | top left | tile 32 of `tileset_city` |  |
| [ ] | `tile_shop_brown_wall_l` | 32x32 | - | top left | tile 42 of `tileset_city` |  |
| [ ] | `tile_shop_brown_wall_m` | 32x32 | - | top left | tile 43 of `tileset_city` |  |
| [ ] | `tile_shop_brown_wall_r` | 32x32 | - | top left | tile 47 of `tileset_city` |  |
| [ ] | `tile_shop_brown_wall_window` | 32x32 | - | top left | tile 46 of `tileset_city` |  |
| [ ] | `tile_shop_brown_base_left` | 32x32 | - | top left | tile 54 of `tileset_city` |  |
| [ ] | `tile_shop_brown_base_mid` | 32x32 | - | top left | tile 55 of `tileset_city` |  |
| [ ] | `tile_shop_brown_base_right` | 32x32 | - | top left | tile 59 of `tileset_city` |  |
| [ ] | `tile_shop_brown_base_door` | 32x32 | - | top left | tile 58 of `tileset_city` |  |
| [ ] | `tile_shop_brown_base_window_0` | 32x32 | - | top left | tile 56 of `tileset_city` |  |
| [ ] | `tile_shop_brown_base_window_1` | 32x32 | - | top left | tile 57 of `tileset_city` |  |
| [ ] | `tile_civic_base_door` | 32x32 | - | top left | tile 50 of `tileset_city` |  |
| [ ] | `tile_civic_base_doubledoor_1` | 32x32 | - | top left | tile 51 of `tileset_city` |  |
| [ ] | `tile_prop_lamp` | 32x32 | - | top left | tile 86 of `tileset_city` |  |
| [ ] | `tile_prop_bin` | 32x32 | - | top left | tile 109 of `tileset_city` |  |
| [ ] | `tile_prop_hydrant` | 32x32 | - | top left | tile 102 of `tileset_city` |  |
| [ ] | `tile_prop_busstop` | 32x32 | - | top left | tile 96 of `tileset_city` |  |
| [ ] | `tile_prop_planter` | 32x32 | - | top left | tile 70 of `tileset_city` |  |
| [ ] | `tile_prop_well` | 32x32 | - | top left | tile 104 of `tileset_town` |  |
| [ ] | `tile_prop_crate` | 32x32 | - | top left | tile 103 of `tileset_town` |  |
| [ ] | `tile_prop_target` | 32x32 | - | top left | tile 95 of `tileset_town` |  |
| [ ] | `tile_prop_sign` | 32x32 | - | top left | tile 83 of `tileset_town` |  |
| [ ] | `tile_prop_mailbox` | 32x32 | - | top left | tile 97 of `tileset_city` |  |
| [ ] | `tile_prop_grave` | 32x32 | - | top left | tile 103 of `tileset_city` |  |
| [ ] | `tile_prop_tower` | 32x32 | - | top left | tile 87 of `tileset_city` |  |
| [ ] | `tile_prop_hoop` | 32x32 | - | top left | tile 85 of `tileset_city` |  |
| [ ] | `tile_prop_bench_0` | 32x32 | - | top left | tile 93 of `tileset_city` |  |
| [ ] | `tile_prop_bench_1` | 32x32 | - | top left | tile 94 of `tileset_city` |  |
| [ ] | `tile_prop_bench_2` | 32x32 | - | top left | tile 95 of `tileset_city` |  |
| [ ] | `tile_prop_car_0` | 32x32 | - | top left | tile 122 of `tileset_city` |  |
| [ ] | `tile_prop_car_1` | 32x32 | - | top left | tile 123 of `tileset_city` |  |
| [ ] | `tile_prop_default` | 32x32 | - | top left | tile 17 of `tileset_town` |  |
| [ ] | `tile_tree_0` | 32x32 | - | top left | tile 16 of `tileset_town` |  |
| [ ] | `tile_tree_1` | 32x32 | - | top left | tile 4 of `tileset_town` |  |
| [ ] | `tile_tree_2` | 32x32 | - | top left | tile 28 of `tileset_town` |  |
| [ ] | `tile_tree_3` | 32x32 | - | top left | tile 5 of `tileset_town` |  |
| [ ] | `tile_tree_4` | 32x32 | - | top left | tile 15 of `tileset_town` |  |
| [ ] | `tile_fence_left` | 32x32 | - | top left | tile 44 of `tileset_town` |  |
| [ ] | `tile_fence_mid` | 32x32 | - | top left | tile 45 of `tileset_town` |  |
| [ ] | `tile_fence_right` | 32x32 | - | top left | tile 46 of `tileset_town` |  |
| [ ] | `tile_fence_post` | 32x32 | - | top left | tile 47 of `tileset_town` |  |
| [ ] | `tile_chainfence` | 32x32 | - | top left | tile 127 of `tileset_city` |  |
| [ ] | `tile_interior_floor_34` | 32x32 | - | top left | tile 34 of `tileset_interior` |  |
| [ ] | `tile_interior_wall_266` | 32x32 | - | top left | tile 266 of `tileset_interior` |  |
| [ ] | `tile_interior_floor_166` | 32x32 | - | top left | tile 166 of `tileset_interior` |  |
| [ ] | `tile_interior_wall_286` | 32x32 | - | top left | tile 286 of `tileset_interior` |  |
| [ ] | `tile_interior_floor_297` | 32x32 | - | top left | tile 297 of `tileset_interior` |  |
| [ ] | `tile_interior_wall_319` | 32x32 | - | top left | tile 319 of `tileset_interior` |  |
| [ ] | `tile_dungeon_floor_0` | 32x32 | - | top left | tile 48 of `tileset_dungeon` |  |
| [ ] | `tile_dungeon_floor_1` | 32x32 | - | top left | tile 49 of `tileset_dungeon` |  |
| [ ] | `tile_dungeon_floor_2` | 32x32 | - | top left | tile 50 of `tileset_dungeon` |  |
| [ ] | `tile_dungeon_wall` | 32x32 | - | top left | tile 40 of `tileset_dungeon` |  |
| [ ] | `tile_dungeon_stairs` | 32x32 | - | top left | tile 36 of `tileset_dungeon` |  |
| [ ] | `tile_dungeon_chest` | 32x32 | - | top left | tile 89 of `tileset_dungeon` |  |
| [ ] | `tile_dungeon_chestOpen` | 32x32 | - | top left | tile 91 of `tileset_dungeon` |  |
| [ ] | `tile_dungeon_fire` | 32x32 | - | top left | tile 29 of `tileset_dungeon` |  |
| [ ] | `tile_dungeon_merchant` | 32x32 | - | top left | tile 84 of `tileset_dungeon` |  |
| [ ] | `tile_dungeon_bones` | 32x32 | - | top left | tile 64 of `tileset_dungeon` |  |

## UI (19)



| Done | Id | Target size | Layout | Anchor | Source | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | `ui_panel` | 24x24 | 9-slice: corners 6px stay fixed, edges and middle stretch | - | skin placeholder | Every window and panel. |
| [ ] | `ui_panel_tooltip` | 24x24 | 9-slice: corners 6px stay fixed, edges and middle stretch | - | skin placeholder | Tooltips and hover info. |
| [ ] | `ui_button` | 16x16 | 9-slice: corners 4px stay fixed, edges and middle stretch | - | skin placeholder | Button, normal state. |
| [ ] | `ui_button_hover` | 16x16 | 9-slice: corners 4px stay fixed, edges and middle stretch | - | skin placeholder | Button, hover state. |
| [ ] | `ui_button_pressed` | 16x16 | 9-slice: corners 4px stay fixed, edges and middle stretch | - | skin placeholder | Button, pressed state. |
| [ ] | `ui_button_disabled` | 16x16 | 9-slice: corners 4px stay fixed, edges and middle stretch | - | skin placeholder | Button, disabled state. |
| [ ] | `ui_button_focus` | 16x16 | 9-slice: corners 4px stay fixed, edges and middle stretch | - | skin placeholder | Button, focus state. |
| [ ] | `ui_field` | 16x12 | 9-slice: corners 4px stay fixed, edges and middle stretch | - | skin placeholder | Text fields. |
| [ ] | `ui_bar_bg` | 12x8 | 9-slice: corners 2px stay fixed, edges and middle stretch | - | skin placeholder | Progress bar background. |
| [ ] | `ui_bar_fill` | 12x8 | 9-slice: corners 2px stay fixed, edges and middle stretch | - | skin placeholder | Progress bar fill; white, tinted in game. |
| [ ] | `ui_card_spell` | 56x84 | Card frame: art window 48x48 at (4,13), header row above, text box below; light grey, tinted with the Vector color in game | top left | skin placeholder | Spell cards. |
| [ ] | `ui_card_basic` | 56x84 | Card frame: art window 48x48 at (4,13), header row above, text box below; light grey, tinted with the Vector color in game | top left | skin placeholder | Basic cards. |
| [ ] | `ui_card_item` | 56x84 | Card frame: art window 48x48 at (4,13), header row above, text box below; light grey, tinted with the Vector color in game | top left | skin placeholder | Item cards. |
| [ ] | `ui_card_select` | 56x84 | Outline drawn over a selected card | top left | skin placeholder |  |
| [ ] | `ui_cursor` | 12x12 | Mouse cursor, hotspot top left; scaled with the window | top left | skin placeholder |  |
| [ ] | `font_ui` | - | - | - | skin placeholder | Pixel font drawn at its native 9 px (or an integer multiple). .ttf or .otf. |
| [ ] | `font_dialogue` | - | - | - | skin placeholder | Dialogue and narrator text. A pixel font at its native size or a whole multiple. .ttf or .otf. |
| [ ] | `font_title` | - | - | - | skin placeholder | Titles and big headings (drawn at 2x). A pixel font at its native size or a whole multiple. .ttf or .otf. |
| [ ] | `font_damage_numbers` | - | - | - | skin placeholder | Floating damage and heal numbers in combat. A pixel font at its native size or a whole multiple. .ttf or .otf. |

## Icons (26)



| Done | Id | Target size | Layout | Anchor | Source | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | `icon_vector_heat` | 16x16 | 16x16 white shape with dark outline; tinted with the Vector color | center | skin placeholder |  |
| [ ] | `icon_vector_cold` | 16x16 | 16x16 white shape with dark outline; tinted with the Vector color | center | skin placeholder |  |
| [ ] | `icon_vector_force` | 16x16 | 16x16 white shape with dark outline; tinted with the Vector color | center | skin placeholder |  |
| [ ] | `icon_vector_motion` | 16x16 | 16x16 white shape with dark outline; tinted with the Vector color | center | skin placeholder |  |
| [ ] | `icon_vector_binding` | 16x16 | 16x16 white shape with dark outline; tinted with the Vector color | center | skin placeholder |  |
| [ ] | `icon_vector_light` | 16x16 | 16x16 white shape with dark outline; tinted with the Vector color | center | skin placeholder |  |
| [ ] | `icon_vector_transmutation` | 16x16 | 16x16 white shape with dark outline; tinted with the Vector color | center | skin placeholder |  |
| [ ] | `icon_vector_vitality` | 16x16 | 16x16 white shape with dark outline; tinted with the Vector color | center | skin placeholder |  |
| [ ] | `icon_vector_corrosion` | 16x16 | 16x16 white shape with dark outline; tinted with the Vector color | center | skin placeholder |  |
| [ ] | `icon_status_root` | 16x16 | 16x16 white shape with dark outline | center | skin placeholder |  |
| [ ] | `icon_status_slow` | 16x16 | 16x16 white shape with dark outline | center | skin placeholder |  |
| [ ] | `icon_status_blind` | 16x16 | 16x16 white shape with dark outline | center | skin placeholder |  |
| [ ] | `icon_status_haste` | 16x16 | 16x16 white shape with dark outline | center | skin placeholder |  |
| [ ] | `icon_status_rally` | 16x16 | 16x16 white shape with dark outline | center | skin placeholder |  |
| [ ] | `icon_status_infusion` | 16x16 | 16x16 white shape with dark outline | center | skin placeholder |  |
| [ ] | `icon_status_guard` | 16x16 | 16x16 white shape with dark outline | center | skin placeholder |  |
| [ ] | `icon_status_shield` | 16x16 | 16x16 white shape with dark outline | center | skin placeholder |  |
| [ ] | `icon_kind_spell` | 16x16 | 16x16 white shape with dark outline | center | skin placeholder |  |
| [ ] | `icon_kind_basic` | 16x16 | 16x16 white shape with dark outline | center | skin placeholder |  |
| [ ] | `icon_kind_item` | 16x16 | 16x16 white shape with dark outline | center | skin placeholder |  |
| [ ] | `icon_intent_attack` | 16x16 | 16x16 white shape with dark outline; drawn over an enemy's head | center | skin placeholder |  |
| [ ] | `icon_intent_special` | 16x16 | 16x16 white shape with dark outline; drawn over an enemy's head | center | skin placeholder |  |
| [ ] | `icon_intent_buff` | 16x16 | 16x16 white shape with dark outline; drawn over an enemy's head | center | skin placeholder |  |
| [ ] | `icon_intent_defend` | 16x16 | 16x16 white shape with dark outline; drawn over an enemy's head | center | skin placeholder |  |
| [ ] | `icon_intent_move` | 16x16 | 16x16 white shape with dark outline; drawn over an enemy's head | center | skin placeholder |  |
| [ ] | `icon_intent_tracking` | 16x16 | 16x16 white shape with dark outline; drawn over an enemy's head | center | skin placeholder |  |

## Card art (11)



| Done | Id | Target size | Layout | Anchor | Source | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | `card_art_heat` | 48x48 | 48x48 card illustration | top left | skin placeholder | Default art for heat cards. Give one card its own art with assets/custom/cards/card_art_<card id>.png. |
| [ ] | `card_art_cold` | 48x48 | 48x48 card illustration | top left | skin placeholder | Default art for cold cards. Give one card its own art with assets/custom/cards/card_art_<card id>.png. |
| [ ] | `card_art_force` | 48x48 | 48x48 card illustration | top left | skin placeholder | Default art for force cards. Give one card its own art with assets/custom/cards/card_art_<card id>.png. |
| [ ] | `card_art_motion` | 48x48 | 48x48 card illustration | top left | skin placeholder | Default art for motion cards. Give one card its own art with assets/custom/cards/card_art_<card id>.png. |
| [ ] | `card_art_binding` | 48x48 | 48x48 card illustration | top left | skin placeholder | Default art for binding cards. Give one card its own art with assets/custom/cards/card_art_<card id>.png. |
| [ ] | `card_art_light` | 48x48 | 48x48 card illustration | top left | skin placeholder | Default art for light cards. Give one card its own art with assets/custom/cards/card_art_<card id>.png. |
| [ ] | `card_art_transmutation` | 48x48 | 48x48 card illustration | top left | skin placeholder | Default art for transmutation cards. Give one card its own art with assets/custom/cards/card_art_<card id>.png. |
| [ ] | `card_art_vitality` | 48x48 | 48x48 card illustration | top left | skin placeholder | Default art for vitality cards. Give one card its own art with assets/custom/cards/card_art_<card id>.png. |
| [ ] | `card_art_corrosion` | 48x48 | 48x48 card illustration | top left | skin placeholder | Default art for corrosion cards. Give one card its own art with assets/custom/cards/card_art_<card id>.png. |
| [ ] | `card_art_basic` | 48x48 | 48x48 card illustration | top left | skin placeholder | Default art for basic cards. Give one card its own art with assets/custom/cards/card_art_<card id>.png. |
| [ ] | `card_art_item` | 48x48 | 48x48 card illustration | top left | skin placeholder | Default art for item cards. Give one card its own art with assets/custom/cards/card_art_<card id>.png. |

## VFX (0)

None yet.

## Music (30)

Background music by situation (data/audio.json). Tracks loop; jingles play once.

| Done | Id | Target size | Layout | Anchor | Source | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | `music_title` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_town` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_school` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_weekend` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_night` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_dungeon` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_dungeon_boss_floor` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_battle` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_battle_boss` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_death` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_story` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_reveal` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_ending` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `jingle_victory` | - | - | - | pack: ninja_adventure | A short jingle that plays once. |
| [ ] | `jingle_defeat` | - | - | - | pack: ninja_adventure | A short jingle that plays once. |
| [ ] | `jingle_level_up` | - | - | - | pack: ninja_adventure | A short jingle that plays once. |
| [ ] | `music_elite` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_town_morning` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_town_after_school` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_zone_downtown` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_zone_residential` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_zone_outskirts` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_upside_down_week2` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_upside_down_week3` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_upside_down_week4` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_upside_down_week5` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_cutscene_tense` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_cutscene_sad` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_cutscene_funny` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |
| [ ] | `music_arena` | - | - | - | pack: ninja_adventure | Looping track (.ogg). |

## Sound effects (38)

Short sound effects.

| Done | Id | Target size | Layout | Anchor | Source | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | `sfx_cast` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_hit` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_heal` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_fail` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_win` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_lose` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_levelup` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_click` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_turn_party` | - | - | - | pack: ninja_adventure | Soft cue when a party member's turn starts (CT Part 2b). |
| [ ] | `sfx_turn_enemy` | - | - | - | pack: ninja_adventure | Cue when an enemy's turn starts (CT Part 2b). |
| [ ] | `sfx_cancel` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_coin` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_door` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_step` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_secret` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_click_2` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_card_hover` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_ap_spent` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_card_play_heat` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_card_play_cold` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_card_play_force` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_card_play_motion` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_card_play_binding` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_card_play_light` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_card_play_transmutation` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_card_play_vitality` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_card_play_corrosion` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_card_play_basic` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_step_grass` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_step_grass_2` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_step_floor` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_telegraph_warning` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_enemy_windup` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_hit_2` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_hit_3` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_explosion` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_charge` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |
| [ ] | `sfx_combo_discovered` | - | - | - | pack: ninja_adventure | Short one-shot (.wav or .ogg). |

## Ambience (9)

Quiet background loops by place and time. Some aren't in the packs yet: drop your own in assets/custom/ambience/.

| Done | Id | Target size | Layout | Anchor | Source | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | `amb_town_day` | - | - | - | pack: ninja_adventure | A quiet background loop (.ogg or .wav). |
| [ ] | `amb_town_night` | - | - | - | pack: ninja_adventure | A quiet background loop (.ogg or .wav). |
| [ ] | `amb_school_hall` | - | - | - | missing (add yours) | Not in the packs yet: add assets/custom/ambience/amb_school_hall.ogg. |
| [ ] | `amb_upside_down_week1` | - | - | - | pack: ninja_adventure | A quiet background loop (.ogg or .wav). |
| [ ] | `amb_upside_down_week2` | - | - | - | pack: ninja_adventure | A quiet background loop (.ogg or .wav). |
| [ ] | `amb_upside_down_week3` | - | - | - | pack: ninja_adventure | A quiet background loop (.ogg or .wav). |
| [ ] | `amb_upside_down_week4` | - | - | - | pack: ninja_adventure | A quiet background loop (.ogg or .wav). |
| [ ] | `amb_upside_down_week5` | - | - | - | pack: ninja_adventure | A quiet background loop (.ogg or .wav). |
| [ ] | `amb_rift` | - | - | - | pack: ninja_adventure | A quiet background loop (.ogg or .wav). |

## Voice blips (10)

The little blips that play as a character's text types out. Each character's pitch is in their NPC data.

| Done | Id | Target size | Layout | Anchor | Source | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| [ ] | `voice_default` | - | - | - | pack: ninja_adventure | A tiny blip played as this voice's text types out. Pitch is set per character in their NPC data. |
| [ ] | `voice_narrator` | - | - | - | pack: ninja_adventure | A tiny blip played as this voice's text types out. Pitch is set per character in their NPC data. |
| [ ] | `voice_kelly` | - | - | - | pack: ninja_adventure | A tiny blip played as this voice's text types out. Pitch is set per character in their NPC data. |
| [ ] | `voice_gary` | - | - | - | pack: ninja_adventure | A tiny blip played as this voice's text types out. Pitch is set per character in their NPC data. |
| [ ] | `voice_mara` | - | - | - | pack: ninja_adventure | A tiny blip played as this voice's text types out. Pitch is set per character in their NPC data. |
| [ ] | `voice_theo` | - | - | - | pack: ninja_adventure | A tiny blip played as this voice's text types out. Pitch is set per character in their NPC data. |
| [ ] | `voice_dex` | - | - | - | pack: ninja_adventure | A tiny blip played as this voice's text types out. Pitch is set per character in their NPC data. |
| [ ] | `voice_priya` | - | - | - | pack: ninja_adventure | A tiny blip played as this voice's text types out. Pitch is set per character in their NPC data. |
| [ ] | `voice_mr_b` | - | - | - | pack: ninja_adventure | A tiny blip played as this voice's text types out. Pitch is set per character in their NPC data. |
| [ ] | `voice_ms_g` | - | - | - | pack: ninja_adventure | A tiny blip played as this voice's text types out. Pitch is set per character in their NPC data. |
