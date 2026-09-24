## Scene assembly (backgrounds + playing field)

Doctrine: assemble from the asset pack. Do not invent a new art style
or generate a full painted backdrop unless a tile is missing.

Source of truth:
- Pack root: `assets/pack/`   # change this path
- Manifest: `docs/art-pack.md` and `assets/pack/tileset.json` (if present)
- Procedure: `docs/scene-assembly.md`
- Skills: `game-asset-core`, `game-tilesets` (seam checks). Maps: `generate2dmap`.

Hard rules
1. Read the pack before drawing anything. List tile size, grid, camera
   (top-down / ortho / side), palette, and layer names.
2. All world art snaps to the pack tile size (e.g. 16 or 32). No
   free-placed bitmaps that ignore the grid.
3. Playing field = tilemap layers, not one flattened JPEG:
   ground → terrain transitions → props/deco → collision/occluders →
   actors/UI (code, not baked into tiles).
4. Match the pack: same pixel density, outline weight, lighting
   direction, and saturation. If a generated tile fights the pack,
   discard it and reuse pack tiles.
5. Never generate a unique “hero rock” as a repeating ground tile.
   Distinctive motifs belong on the prop layer once.
6. New tiles only when the pack lacks a terrain or transition. Generate
   at exact cell size, then verify a 3×3 (or 2×2) PIL composite for
   seams and repeating blobs (`game-tilesets`).
7. Collision comes from a layer or tile flags, not from guessing
   opaque pixels on the background.
8. Characters and UI stay separate sprites. Do not paint them into
   the background.

Done means: map loads on-grid, pack tiles dominate the screen, no
visible tile grid, collision matches walkable ground, and a screenshot
of the scene sits next to a pack reference strip.

## What this project can do

Godot 4.6, GL Compatibility. One scene, `scenes/clearing/clearing.tscn`.
Window 3440×1440, camera zoom 5, nearest filtering, so each 16px tile
is 80 screen pixels.

Player (`scripts/player.gd`, `player.png`, 48×48, 6 columns):

- Eight-direction movement at 80 px/s. `Input.get_vector` normalizes
  diagonals. `CharacterBody2D` motion mode is floating.
- Four facings. Any horizontal input, including a diagonal, plays the
  side row. Pure up plays the back. Pure down plays the face. Left is
  `flip_h` on the side row. Idle is always row 0, facing the camera.
  Stored facing stays put while idle, and the swing uses that facing.
- Space plays attack rows 6–8 and locks movement until the clip ends.
  Only columns 0–3 of those rows have art. Columns 4 and 5 are blank
  and must not be played. The hitbox is on during frames 2 and 3,
  layer `hitbox`, mask `hurtbox`. Nothing occupies `hurtbox` yet.
- Feet sit on frame row 42. Sprite offset puts that row on the body
  origin so y-sort and the collision box share the feet.

Physics layers, in order: `world`, `player`, `enemy`, `hurtbox`, `hitbox`.
The player is on `player` and collides with `world`.

`scenes/grove/grove.tscn` is the second map, seed `90511`, same pack
tiles. Its character sheet is `assets/ai/characters/wanderer.png`.
`scenes/hollow/hollow.tscn` is the third map, seed `44107`, same pack
tiles, character sheet `assets/ai/characters/scout.png`.
`scenes/ford/ford.tscn` is the fourth map, seed `12809`, same pack
tiles. Its sheet is `assets/ai/characters/warrior-16x16-sheet.png`,
6 columns by 10 rows of 16×16, same row order as `player.png`.
Set `frame_size` to 16 for that sheet.
`scenes/heath/heath.tscn` is the fifth map, seed `91003`, same pack
tiles, `include_water` false so the lake and river are skipped.
Its sheet is `assets/ai/characters/red-fighter-16x16.png`, also 16×16
cells in the same ten-row order. The heath scene does not control any
character. `Lineup` places all five sheets 72px apart on one foot line.
`scenes/forest/forest.tscn` is the sixth map, seed `91003`. It uses
`assets/pack/TILESET_brighter.png` (The Painted Lands), not Mystic Woods.
Lawn, pond, and fence are separate systems. The dirt path follows the
procedure below. `character_sprite_sheet.png` is 3 columns by 4 rows of
32px, all facing the camera. Row 0 idles, row 1 walks. There is no
attack row. Movement is still eight-direction.

## Painted Lands dirt path (rounded ends)

Sheet: `assets/pack/TILESET_brighter.png`, 16×16 cells. Code:
`scripts/forest_terrain.gd` (`_lay_path`, `_widen_run`, `_path_gid`).
Do this only for that sheet. Leave the flat grass fill, the 5×3 pond
strip (columns 44–46, rows 0–2), and the fence kit alone.

Classify a sand cell by its four 8×8 quadrants, written NW NE / SW SE.
G means that quadrant is grass. D means dirt.

| Role | Quadrants | Atlas cell | Use |
|---|---|---|---|
| Fill | DD/DD | `(22, 1)` | Interior only. All four neighbors are path. |
| North edge | GG/DD | `(22, 0)` | Grass on the north. North row of a 2-wide run, and a 1-wide east-west run. |
| South edge | DD/GG | `(22, 2)` | Grass on the south. South row of a 2-wide run. |
| West edge | GD/GD | `(21, 1)` | Grass on the west. |
| East edge | DG/DG | `(23, 1)` | Grass on the east. |
| NW cap | GG/GD | `(21, 0)` | Dirt only in the SE quadrant. North cell of the west end column. |
| NE cap | GG/DG | `(23, 0)` | Dirt only in the SW quadrant. North cell of the east end column. |
| SW corner | GD/GG | `(21, 2)` | Dirt only in the NE quadrant. South cell of the west end column. |
| SE corner | DG/GG | `(23, 2)` | Dirt only in the NW quadrant. South cell of the east end column. |

Neighbor bits when choosing a GID: N=1, E=2, S=4, W=8. A set bit means
that neighbor is also path. Fill is mask 15 only. A cell with two or
more grass neighbors is never fill.

Procedure that produced the rounded ends:

1. Draw one 4-connected east-west polyline on walkable grass. On this
   sheet a vertical step opens a gap between the rounded pieces, so the
   working ribbon does not jog up or down.
2. If the run is at least 4 tiles, add a south cell under every
   centerline cell, including both ends. The south row then occupies
   the same columns as the north row. Drop any path cell outside that
   column span or outside those two rows.
3. Autotile every path cell from the mask above.
4. After autotile, force the two end columns. Do not leave this to the
   mask, and do not add a third cell beside the stack.

```
West column:  (21, 0) over (21, 2)
East column:  (23, 0) over (23, 2)
```

The north cell is the same rounded dirt-on-grass cap already used for
the top of the path. The south cell is that cap mirrored down: grass
toward the south and toward the outside of the road. Both rows stop in
that column. Nothing sits past it, and nothing hangs south of it.

What failed, and must not be repeated:

- Path fill `(22, 1)` on an end, or on any cell that touches grass on
  two adjacent sides. The end reads as a square cobble tooth.
- A south row that starts or ends one column inside the north row.
  That is an L: the extra south cell stays square, and a cap placed
  beside the stack comes back as an orphan tile.
- A 2-tile-tall blunt end (two fill tiles side by side).
- A vertical step or a one-tile jog. The sand edges connect east-west.
  They do not meet across a north-south join, so the ribbon breaks.
- Drawing a new rounded pixel. Only these sheet cells.

Accept when both ends show grass eating the outer corner on the top
and on the bottom, the long edges show the sheet's grass fringe, and
no path cell past the end columns remains.

## Art directories

`assets/pack/` is hand-painted Mystic Woods. `assets/ai/` is generated
in Grok Build and is labeled in `assets/ai/README.md`. Never put a
generated sheet in `assets/pack/`. The wanderer sheet matches the
player grid: 48×48, 6 columns, 10 rows, attack columns 0–3 only.

There is no health, enemy, or save. The editor addon
`addons/godot_mcp` is how this repo is driven from the Godot MCP server.

## Terrain generation

`scripts/terrain.gd` writes a tile-id grid. `scripts/clearing.gd` paints
it. Seed `21021`, size 70×46. The same grid comes up every launch.
Output is atlas coordinates, never a painted bitmap.

`plains.png` is 6×12 cells of 16px:

- Rows 0–3: dirt on meadow grass. Rounded outer corners and a
  one-tile east-west trail live here.
- Rows 4–6: cliff top and the south-facing wall. The sheet has no
  north-facing wall. A plateau reads as higher ground because the
  south rim uses the wall tiles.
- Rows 8–11: water. Same corner layout as the dirt block, eight rows
  down.
- Meadow fill is the single cell in `grass.png`, color `(80, 155, 102)`.
  Cliff-top green `(83, 160, 59)` stays on the plateau and is not
  mixed into that fill.

Pipeline, in order:

1. Height and moisture are value-noise fBm, 4 octaves, amplitude
   halved and frequency doubled each octave. Height samples at
   `(x * 0.055, y * 0.055)`. Moisture samples at
   `(x * 0.05 + 40, y * 0.05 + 20)`.
2. Biome thresholds. Height above `0.64` is cliff. Height below `0.36`
   and moisture below `0.40` is water. Everything else is grass.
3. Three cellular passes. A cliff or water cell with fewer than 4 of
   its 8 neighbors of the same kind becomes grass. A grass cell with
   6 or more becomes that kind.
4. Two erode passes on cliffs. A cliff cell with fewer than 2 cardinal
   cliff neighbors becomes grass. Then drop cliff components smaller
   than 40 cells and water components smaller than 12.
5. Prefab arenas. Spawn is `(width/2, height * 0.62)`, flattened to
   grass in a disk of radius 5. The shrine is the farthest of 40
   seeded candidates and is flattened in a disk of radius 4.
6. Autotile from the 4 cardinal neighbors. Bits are N=1, E=2, S=4,
   W=8. The pack paints the rounded corner into the two-neighbor
   tile, which is how an 8-neighbor corner is represented with this
   sheet. Fully surrounded dirt and plateau cells pick a fill variant
   from the hash of the cell so a 3×3 interior does not repeat.
7. Carve, then autotile again. A* from spawn to shrine treats cliff
   cost as 12 and water cost as 8. The route and the cell to its east
   become dirt, two tiles wide, and the arenas and the map edge stay
   grass. A short water link is stamped from the nearest water toward
   the west column, skipping both arenas.
8. If two fully interior 3×3 dirt windows or plateau windows share
   the same nine ids, the center cell of the later window changes
   variant.
9. Poisson scatter on grass outside the arenas. Trees at least 6.5
   tiles apart, flowers and tufts 3.2, blocking rocks 8. The shrine
   prefab is a small tree, two rocks, and a flower from the pack,
   placed on the shrine tile.
10. Verify before the scene is trusted. Every id exists in the pack.
    A grass-and-dirt flood fill from the spawn reaches the shrine.
    Interior dirt 3×3s and plateau 3×3s are unique. The report string
    is printed from `clearing.gd`.

Painting order in the scene: grass on `Ground` for every cell, feature
ids on `Features`, flowers on `Deco`, y-sorted trees and the shrine on
`Actors`. Collision is a static body on cliff cells, water cells, and
a ring outside the map. Grass and dirt stay open.

When extending this, add biomes as more ids from `plains.png` or
another pack sheet. Keep the same pipeline: noise, thresholds, smooth,
carve, re-autotile, scatter, then the three checks above.
