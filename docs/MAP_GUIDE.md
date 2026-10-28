# Map guide

The town's four zones are scenes you can open and edit in Godot: `src/world/zones/downtown.tscn`, `residential.tscn`, `outskirts.tscn` and `school.tscn`. Interiors (shops, houses, the school halls) are still described in `data/town/interiors.json`.

## What's in a zone scene

| Node | What it's for |
| --- | --- |
| **Ground** | Floor tiles: grass, roads, paths. Walkable. |
| **Objects** | Buildings, fences, trees, props. Anything painted here blocks walking. |
| **Collision** (red tint) | Invisible walls: paint here to block a tile without drawing anything. |
| **Water** (blue tint) | Water tiles. Drawn as animated water in the game and not walkable. |
| **Blocks** | Pieces dropped in from `src/world/blocks/` (lots, roads, a park, fences, props). |
| **Markers** | Doors, spots, signs, exits, spawn points and the camera limits. |

The root node has the zone's id and its size in tiles (`tiles`). One tile is 32x32 pixels; turn on grid snapping (the magnet icon, step 32) so blocks and markers land on tiles.

**Markers** (scripts in `src/world/markers/`; add a Node2D and drag the script onto it, or duplicate an existing marker):

| Marker | Settings | Does |
| --- | --- | --- |
| DoorMarker | `loc` (a location id), `sign_text`, `building` (the building's tiles, relative to the door) | The door you press E on. The building blocks walking and lights its windows when someone's home. The sign shows `sign_text`, or the location's name (houses get a nameplate). |
| NpcSpot | `spot_id`, `tags` | A place people stand. Outdoor locations (the town square, the bus stop) are spots. |
| Interactable | `says`, `map_label` | A sign to read (`says`), or a label drawn on the map (`map_label`). |
| ZoneExit | `to`, `tiles`, `spawn` | Walking onto it goes to zone `to`, arriving at tile `spawn` there. |
| SpawnPoint | `spawn_id` | Where the player appears for a start ("morning", "before_school"). |
| CameraBounds | `tiles` | Limits the camera (optional; the zone's size is used otherwise). |

## Add a building (no code)

Example: a bakery downtown.

1. **Add the location.** Open `data/town/locations.json` and add one line, copying a shop:
   ```json
   { "id": "bakery", "name": "The Bakery", "zone": "downtown", "status": "OPEN", "kind": "building", "hours": "morning,afternoon", "upsideDown": false }
   ```
2. **Open** `src/world/zones/downtown.tscn`.
3. **Place a lot.** Drag `src/world/blocks/lot_shop_brick.tscn` from the FileSystem dock onto the **Blocks** node, then move it to an empty spot (snapping on). Check nothing else is under it.
4. **Set the door.** Expand the new block, select its **Door** marker, set `loc` to `bakery` and `sign_text` to `The Bakery`. Right-click the block > Editable Children if you can't see the marker.
5. **Save** and run the game. The bakery's door works: press E on it. To give it an inside, add an entry for it in `data/town/interiors.json` (copy another shop's).
6. **Run the tests.** `tests/run_tests.gd` checks every location has a door or spot, every exit lands on a walkable tile, and every NPC's home exists. It names anything you missed.

## Add a street

Drag `road_horizontal.tscn`, `road_vertical.tscn` or `road_crossing.tscn` into **Blocks** and line them up end to end. Roads don't block walking. For a sidewalk, paint concrete on the Ground layer around it. Add `props_street.tscn` for lamps, a bench and a bin.

## Add an outdoor place

For somewhere without a building (a lookout, a basketball court), add a location with `"kind": "outdoor"`, then add an **NpcSpot** marker in the zone with `spot_id` set to the location's id.

## Paint by hand

Select the Ground or Objects layer and use the TileMap panel at the bottom. The tiles come from `src/world/world_tileset.tres`: town (houses, nature), city (roads, shops) and floor (interiors). Painting on Objects makes a tile solid. Your own art in `assets/custom/` still replaces these tiles in the game.

## Rebuilding from data

`tools/build_world.gd` made these scenes from the old zone data (`data/town/zones/*.json`), which the game still uses for a zone with no scene. Re-running its phase 2 **overwrites** the zone scenes, so only do that before you start editing them by hand.
