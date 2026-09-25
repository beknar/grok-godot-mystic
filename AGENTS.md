## Which pack (read this first)

This repo has two map languages. Do not mix their pipelines, sheets,
or “done” checks.

| Maps | Pack | Code | Rules in this file |
|---|---|---|---|
| clearing, grove, hollow, ford, heath | Mystic Woods: `plains.png`, `grass.png` under `assets/pack/` | `scripts/terrain.gd`, `scripts/clearing.gd` | § Mystic Woods |
| forest | Painted Lands: `assets/pack/TILESET_brighter.png` | `scripts/forest_terrain.gd` | § Painted Lands |

`docs/scene-assembly.md` §0–5 is shared inventory. §6 is Painted Lands
only (20-recipe forest generator). Mystic Woods generation stays under
§ Mystic Woods.

Heath and forest both use seed `91003` on the current scenes. That is
coincidence. Heath still runs the Mystic Woods pipeline with
`include_water` false. Forest never calls `terrain.gd`.

## Scene assembly (backgrounds + playing field)

Doctrine: assemble from the pack for that map. Do not invent a new
art style or generate a full painted backdrop unless that pack is
missing a tile.

Source of truth:
- Pack root: `assets/pack/`
- Manifest: `docs/art-pack.md` and `assets/pack/tileset.json` (if present)
- Procedure: `docs/scene-assembly.md`
- Skills: `game-asset-core`, `game-tilesets` (seam checks). Maps: `generate2dmap`.

Hard rules (both packs)
1. Read the pack for *this* scene before drawing. List tile size, grid,
   camera, palette, and layer names.
2. All world art snaps to that pack’s tile size (16px here). No
   free-placed bitmaps that ignore the grid.
3. Playing field = tilemap layers, not one flattened JPEG:
   ground → terrain transitions → props/deco → collision/occluders →
   actors/UI (code, not baked into tiles).
4. Match that pack: pixel density, outline weight, lighting, saturation.
   If a generated tile fights the pack, discard it and reuse pack tiles.
5. Never generate a unique “hero rock” as a repeating ground tile.
   Distinctive motifs belong on the prop layer once.
6. New tiles only when *that* pack lacks a terrain or transition.
   Generate at exact cell size, then verify a 3×3 PIL composite
   (`game-tilesets`). Painted Lands dirt caps, edges, and knuckles
   already exist — do not generate replacements for those cells.
7. Collision comes from a layer or tile flags, not from guessing
   opaque pixels on the background.
8. Characters and UI stay separate sprites. Do not paint them into
   the background.

Done means: map loads on-grid, that pack’s tiles dominate the screen,
collision matches walkable ground, and a screenshot sits next to a
strip from the same pack.

## What this project can do

Godot 4.6, GL Compatibility. Window 3440×1440, camera zoom 5, nearest
filtering, so each 16px tile is 80 screen pixels.

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

Mystic Woods maps (pipeline: § Mystic Woods):

- `scenes/clearing/clearing.tscn` — seed `21021`, `player.png`
- `scenes/grove/grove.tscn` — seed `90511`, `assets/ai/characters/wanderer.png`
- `scenes/hollow/hollow.tscn` — seed `44107`, `assets/ai/characters/scout.png`
- `scenes/ford/ford.tscn` — seed `12809`, `assets/ai/characters/warrior-16x16-sheet.png`
  (6×10 of 16×16, same row order as `player.png`; `frame_size` 16)
- `scenes/heath/heath.tscn` — seed `91003`, `include_water` false,
  `assets/ai/characters/red-fighter-16x16.png`. Heath does not control
  a character. `Lineup` places all five Mystic Woods sheets 72px apart
  on one foot line.

Painted Lands map (pipeline: § Painted Lands):

- `scenes/forest/forest.tscn` — current seed `91003` (not the heath
  generator), `assets/pack/TILESET_brighter.png`.
  `character_sprite_sheet.png` is 3×4 of 32px (two tiles tall). Row 0
  idles, row 1 walks. No attack row. Movement is still eight-direction.
  New forest seeds use `recipe = seed % 20` from the table below.
- `scenes/wilds/wilds.tscn` — map id `74015`, recipe `74015 % 20` = 15
  Double lean. Same sheet and the forest walker. No pond. One road
  makes two short rises, separated by a straight run, and ends at the house.

There is no health, enemy, or save. The editor addon
`addons/godot_mcp` is how this repo is driven from the Godot MCP server.

## Art directories

`assets/pack/` holds *hand-painted* sheets for both languages:

- Mystic Woods: `plains.png`, `grass.png`, and the original woods set
- Painted Lands: `TILESET_brighter.png`

`assets/ai/` is generated in Grok Build (`assets/ai/README.md`).
Never put a generated sheet in `assets/pack/`. The wanderer sheet
matches the player grid: 48×48, 6 columns, 10 rows, attack columns
0–3 only.

---

# Mystic Woods

Do not apply this section to `forest.tscn` or `TILESET_brighter.png`.

`scripts/terrain.gd` writes a tile-id grid. `scripts/clearing.gd` paints
it. Clearing seed `21021`, size 70×46. Same grid every launch for that
seed. Output is atlas coordinates, never a painted bitmap.

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

Painting order: grass on `Ground` for every cell, feature ids on
`Features`, flowers on `Deco`, y-sorted trees and the shrine on
`Actors`. Collision is a static body on cliff cells, water cells, and
a ring outside the map. Grass and dirt stay open.

When extending Mystic Woods, add biomes as more ids from `plains.png`
or another *Mystic Woods* sheet. Keep this pipeline: noise, thresholds,
smooth, carve, re-autotile, scatter, then the three checks above.

---

# Painted Lands

Do not apply this section to clearing, grove, hollow, ford, or heath.
Do not call `terrain.gd` from forest.

Sheet: `assets/pack/TILESET_brighter.png`, 16×16 cells.
Code: `scripts/forest_terrain.gd` (`_lay_path`, `_widen_run`, `_path_gid`).

## How to use these notes

Two jobs, one sheet:

1. **How dirt, water, fences, cliffs, and the house draw** — autotile
   tables and y-sort. These methods never change. Do not invent pixels
   or swap in Mystic Woods dirt from `plains.png`.
2. **Where those systems go** — the 20-recipe generator below. A new
   seed changes recipe, POIs, path graph, pond count, and extras.
   That is not a regression of (1).

Do not freeze the current `forest.tscn` screenshot when baking a new
seed. Do not restyle the systems when editing one screenshot.

The 5×3 block at atlas columns 44–46, rows 0–2 is the **water autotile
source on the sheet**, not the size of the lake in the world. Do not
stamp a 5×3 rectangle of wave fill as the pond.

Quadrant labels (NW NE / SW SE) describe how to *pick* a 16×16 atlas
cell. Never slice that cell into four world tiles. Never split a cell
to fake a 45° road.

## Dirt path atlas

Classify a sand cell by its four 8×8 quadrants, written NW NE / SW SE.
G = grass in that quadrant of the *atlas cell*. D = dirt.

| Role | Quadrants | Atlas cell | Use |
|---|---|---|---|
| Fill | DD/DD | `(22, 1)` | Interior only. All four neighbors are path. A 2-wide tube has no fill cell. |
| North edge | GG/DD | `(22, 0)` | Grass on the north. |
| South edge | DD/GG | `(22, 2)` | Grass on the south. |
| West edge | GD/GD | `(21, 1)` | Grass on the west. |
| East edge | DG/DG | `(23, 1)` | Grass on the east. |
| NW cap | GG/GD | `(21, 0)` | Dirt only in the SE quadrant. North cell of a west end. |
| NE cap | GG/DG | `(23, 0)` | Dirt only in the SW quadrant. North cell of an east end. |
| SW corner | GD/GG | `(21, 2)` | Dirt only in the NE quadrant. South cell of a west end. |
| SE corner | DG/GG | `(23, 2)` | Dirt only in the NW quadrant. South cell of an east end. |
| Inner NW | GD/DD | `(23, 5)` | Grass only in the NW quadrant. Inside crotch of a bend. |
| Inner NE | DG/DD | `(21, 5)` | Grass only in the NE quadrant. |
| Inner SW | DD/GD | `(23, 3)` | Grass only in the SW quadrant. |
| Inner SE | DD/DG | `(21, 3)` | Grass only in the SE quadrant. |

Neighbor bits: N=1, E=2, S=4, W=8. A set bit means that neighbor is
path. Fill is mask 15 only. A cell with two or more grass neighbors
is never fill.

## Dirt path — rounded ends

1. Draw one 4-connected polyline on walkable grass. No 1-tile jog.
2. If the run is at least 4 tiles, add a south cell under every
   centerline cell (or a second column on a north–south run). Both
   rows of a tube occupy the same columns. Drop cells outside that span.
3. Autotile from the table.
4. Force the end columns. Do not leave this to the mask. Do not add
   a third cell beside the stack.

```
West column:  (21, 0) over (21, 2)
East column:  (23, 0) over (23, 2)
North-bound cap: (21, 0)/(23, 0) over the matching inner edges
South-bound cap: (21, 2)/(23, 2) under the matching inner edges
```

Failed patterns (do not repeat):

- Fill `(22, 1)` on an end, or on any cell that touches grass on two
  adjacent sides.
- One row shorter than the other at an end or knuckle.
- 2-tall blunt end of two fill tiles.
- One-tile jog, or a stair one cell east and one cell north.
- New pixels. Only the atlas cells above.

## Dirt path — 90° and approximate 45°

Every cell is 4-connected. No diagonal neighbor is “connected.”
Do not place fill along 45°. Do not slice tiles to fake a diagonal.

90° = one 2×2 knuckle. Outer elbow = cap/outer cell (grass on the two
lawn sides). Inner crotch = inner-bite cell. Never a 2×2 of fill.
Force the knuckle after autotile; the mask will mark the inner cell
as fill because all four neighbors are path.

Approximate 45° = two 90° knuckles + a short riser. Riser is 2–4 tiles
of path *after* the first knuckle, not a 1-tile jog. Past 6 tiles it
reads as a second highway. Default cap is one lean per path leg, at
most two leans on the whole map, never on adjacent cells.

Example lean (east, north, east):

```
################
################
              ##
              ##
              ##########
              ##########
```

Lower knuckle (east then north; outside lawn south and east):

```
inner (23, 5)     east edge (23, 1)
south edge (22, 2)    outer (23, 2)
```

Upper knuckle (north then east; outside lawn north and west):

```
outer (21, 0)      north edge (22, 0)
west edge (21, 1)      inner (21, 3)
```

Mirror knuckles for SE / NW / SW. Straight runs keep edge tiles from
the table.

## Pond, fences, cliffs, house

Pond: compact blob from moisture (see generator). Wave fill only where
water has water on all four sides. Every water–lawn neighbor is a shore
cell from atlas columns 44–46, rows 0–2. Four outer corners are convex
shores. Optional 1–3 reeds on south/east shore. No 1-tile canals.
World pond size is the blob, not 5×3.

Fences: 4-connected rails, real corner GIDs, min run 3. Collision on
rails. Overlay on flat grass. Shape comes from the recipe (yard, gate
line, or omit).

Cliffs: only recipes that list a plateau. One blob ≥4 tiles in both
axes. Cap on every high cell. Brown face only on the south silhouette.
Corners at every turn. If any singleton face would remain, drop the
plateau and omit cliffs. Never sprinkle cliff fragments on a recipe
that does not list a plateau.

House: two objects when the recipe includes a house.

- `HOUSE_BODY` — walls, door, porch. Collision. Sort Y = doorstep.
  Actor south of that line draws in front. Actor cannot walk through
  the body.
- `HOUSE_ROOF` — gables and overhang. No collision. Sort Y = eave.
  Actor north of the house, in the roof’s X span, is hidden by the
  roof only.

Do not y-sort the cottage as one sprite.

## Forest generator (organic, 20 recipes)

Same loop as Mystic Woods (noise → blobs → drop specks → arenas →
A* → scatter → verify) but **paint** only with this sheet. Do not use
Mystic Woods cliff threshold `0.64` as a default biome here.

```
seed = map_id
rng  = rng(seed)
recipe = seed % 20
height, moist = fBm(seed, 4 octaves)
               height freq 0.055, moist freq 0.05 offset (40, 20)
lawn = all cells
pond_mask = CA(height < 0.34 and moist < 0.38)
            drop components < 12 cells; drop tetrominoes
plateau_mask = CA(height > 0.72) then erode
               drop components < 40 cells
               KEEP only if recipe.plateau else discard
flatten spawn disk (r=5) and house disk (r=4) if recipe.house
POIs = spawn, house (or map-center if no house),
       optional second landmark from rng
path = A* 4-connected lawn, cost 1; water/fence/body blocked
       widen 2 if run ≥ 4
       if recipe.lean: insert 2–4 tile riser + two knuckles
       autotile table; force caps and knuckles
apply recipe extras (ponds, fences, plateau, extra branches)
Poisson trees (gap recipe.tree_gap), deco (recipe.deco)
verify walk spawn → house-or-far-path-end
reject if fill on cap/knuckle, square pond, orphan cliff,
        actor would clip HOUSE_BODY, or 1-tile stair
```

Successive seeds look different because `recipe`, POI cells, pond
yes/no (from moisture), and branch count all change. Do not expect
grass-hash alone to read as a new map.

### Recipe table (`recipe = seed % 20`)

Flags: H house, P pond (keep largest valid blob; P2 = keep two if
two valid components exist), F fence yard, G gate line across the
path (no full yard), C plateau, T tree count band, L allow one
approx-45° lean, B extra A* branches, D deco density.

| # | Name | H | Water | Height | Path | Trees | Deco |
|---|---|---|---|---|---|---|---|
| 0 | Pastoral | yes | P | F | 1 trunk + L toward house | 3–6, gap 5–6 | 8% |
| 1 | Crossroads | yes | none | none | 2 trunks, 90° only | 3–6 | 8% |
| 2 | Pond walk | yes | P | none | trunk skirts shore (≥1 tile lawn) | 3–6 | 8% |
| 3 | Garden | yes | none | F + G | 1 trunk through gate | 3–5 | 10% near fence |
| 4 | Lookout | yes | none | C | trunk to plateau foot, L ok | 3–5 | 6% |
| 5 | Open meadow | no | none | none | 1 long edge-to-edge trunk | 2–4 | 12% flowers |
| 6 | Twin water | yes | P2 | none | trunk between the two blobs | 3–6 | 8% |
| 7 | South road | yes N | none | none | trunk locked to south third | 3–6 | 8% |
| 8 | Shore spur | yes | P | none | trunk + B=1 ending 1 cell off shore | 3–6 | 8% |
| 9 | Three-way | yes | none | none | trunk + B=2, 90° only | 3–6 | 7% |
| 10 | West hamlet | yes W | P | F | from east edge, L toward house | 3–6 | 8% |
| 11 | East hamlet | yes E | P | F | from west edge, L toward house | 3–6 | 8% |
| 12 | Wild lane | no | moisture only | none | 1 trunk, no extras | 4–7 | 6% |
| 13 | Orchard | yes | none | none | short trunk from nearest edge | 8–12, gap 4 | 5% |
| 14 | Shore hamlet | yes | P next to house | F between house and pond | short trunk | 3–5 | 9% |
| 15 | Double lean | yes | none | none | one trunk, two L (not adjacent) | 3–6 | 8% |
| 16 | Below the rim | yes | none | C | trunk in the lawn south of plateau | 3–5 | 6% |
| 17 | Gate road | yes | none | G only | trunk through a 3–5 tile gate | 3–6 | 8% |
| 18 | Sparse wild | no | P if blob exists else none | none | 1 trunk | 2–3, gap 7 | 4% |
| 19 | Switchback | yes | none | none | U of two 90° knuckles back to same edge | 3–6 | 8% |

Recipe 0 is the current `forest.tscn` vibe. Recipes 4 and 16 are the
only plateau maps. Recipes 5, 12, 18 have no house — skip body/roof
objects and sort checks.

If a flag cannot be placed without breaking autotile (pond too small,
plateau fails the blob test), drop that extra and keep the path.
Do not invent tiles to force the flag.

Reject a Painted Lands screenshot if: lawn is a motif stamp; fill sits
on a cap or knuckle; pond corners are square wave tiles; a cliff
fragment is orphaned; the actor draws through `HOUSE_BODY`; a 1-tile
stair fakes 45°.
