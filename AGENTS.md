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
   (`game-tilesets`). Painted Lands dirt caps, edges, knuckles, houses,
   patches, bushes, rocks, signs, and fires already exist — do not
   generate replacements for those cells.
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
- `scenes/wilds/wilds.tscn` — map id `74015`, recipe 15 Double lean.
  House prefab 1. Two short rises. Irregular dirt blobs use the patch
  atlas, then Mode A or B so the baked grass does not form a dark
  rectangle. A land rock and one sign. Same sheet and walker.

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
Code: `scripts/forest_terrain.gd`.

## How to use these notes

Two jobs, one sheet:

1. **How each system draws** — cobble path table, patch islands,
   water shores, four house prefabs, y-sort. Methods never change.
   Do not invent pixels or swap in Mystic Woods dirt from `plains.png`.
2. **Where systems go** — 20-recipe generator. A new seed changes
   recipe, house prefab, path graph, dirt *islands* (not just roads),
   bushes, rocks, signs, and fires.

A screenshot that only has cobble roads + one porch cottage + flowers
has failed the variety rules, even if the road autotile is perfect.

The 5×3 block at atlas columns 44–46, rows 0–2 is the **water autotile
source on the sheet**, not the size of the lake in the world.

Quadrant labels describe how to *pick* a 16×16 atlas cell. Never slice
that cell into four world tiles. Never split a cell to fake a 45° road.

## Dirt: two families (do not collapse them)

**PATH** — diamond cobble tube. Atlas `(21–23, *)` only. Walkable road.

**PATCH** — dirt *islands* on grass. Not a road. Not cobble. Not a
single square of fill. Walkable.

The square stubs in the last screenshot happened because a PATCH cell
was a raw fill (or one 8×8 quadrant) with no neighbor tiles to supply
the grass corners. A visible patch is a **mini-blob + autotile**, the
same idea as a pond.

### Patch blob (shape)

1. Pick a seed cell on lawn, ≥3 tiles from any cobble PATH cell and
   ≥2 from house / water / fence.
2. Grow a 4-connected blob of 3–8 cells (irregular recipes: CA or
   drunkard, then drop 1-cell diagonals). Round recipes: a 2×2, a
   3×2, or a plus. Never a lone 1×1 fill. Never a 1×N strip.
3. If the blob is still one cell after grow, replace that cell with a
   **standalone rounded island** tile (dirt-on-grass cap with grass
   on three or four sides from the PATCH atlas). Do not leave a square.
4. Min 4 tiles between two blobs.

### Patch autotile (paint)

Use the **dirt-on-grass family**, not cobble and not a subdivided
quarter sitting alone:

```
PATCH atlas (same roles as PATH, different cells)
NW (18,0)  N (19,0)  NE (20,0)
 W (18,1)  F (19,1)   E (20,1)
SW (18,2)  S (19,2)  SE (20,2)
```

Second style set, same layout: `(24–26, 0–2)`. Pick one set per blob.
Irregular recipes may swap in a ragged whole tile from row 3,
columns 24–27 (or `(20,3)`, `(24,3)`, `(25,3)`) only as the **interior**
of a blob that already has ROUND edge/corner neighbors — never as the
only cell.

Neighbor bits N=1 E=2 S=4 W=8 on the blob mask:

- 15 → F `(19,1)` or `(25,1)`
- one grass side → matching EDGE
- two adjacent grass sides → OUTER corner (NW/NE/SW/SE)
- three grass sides → standalone rounded island from that set
- a cell with no painted blob neighbor is illegal; delete it

Do not place F on the outline. Do not place an EDGE without its
opposite-side partner when the blob is two cells tall or wide.
Do not use PATH `(22,1)` or a lone 8×8 quadrant as the patch.

Reject a square dirt tooth on the lawn.

### Patch grass (the dark-green rectangle)

PATCH atlas cells bake their *own* grass into the tile. That grass is
a different green from FLAT_GRASS, so a raw stamp draws a dark square
behind the dirt (the last screenshot). Never leave that AABB visible.

After the blob is autotiled, pick **one paint mode per blob**
(`(seed + blob_i) % 2`):

**Mode A — match the lawn (default half).**  
Keep beige / dirt / brown pixels. Replace every baked-grass pixel in
the PATCH cells with the FLAT_GRASS pixel already on that world cell
(same speckle variant). Equivalent: blit dirt with grass treated as
transparent. The dirt outline stays rounded; the lawn color is
continuous. No second green.

**Mode B — accent grass, organic halo.**  
Keep the baked darker green, but it may only exist inside an organic
halo, never as the tile rectangle.

1. Dirt mask = beige/brown pixels of the autotiled blob.
2. Halo = that mask dilated 2–4 pixels with a 1-octave noise wobble
   so the halo edge is lumpy, not a circle or a box. Then AND with
   the 16px cells the blob occupies plus at most one neighbor ring.
3. Darker grass is painted only on `halo minus dirt`. Outside the
   halo, FLAT_GRASS stays.
4. Soften the halo rim with the lawn speckle (copy 30–50% of rim
   pixels from the destination FLAT_GRASS). No straight 16px edge of
   dark green against light green.

A 2×2 of PATCH tiles whose dark grass meets in a larger rectangle is
a Mode B failure — run the halo mask or fall back to Mode A.

Reject a dark-green square or rectangle under a dirt mound.

## Dirt path atlas (cobble PATH only)

Classify a sand *path* cell by its four 8×8 quadrants, written
NW NE / SW SE. G = grass in that quadrant of the atlas cell. D = dirt.

| Role | Quadrants | Atlas cell | Use |
|---|---|---|---|
| Fill | DD/DD | `(22, 1)` | Interior only. A 2-wide tube has no fill cell. |
| North edge | GG/DD | `(22, 0)` | Grass on the north. |
| South edge | DD/GG | `(22, 2)` | Grass on the south. |
| West edge | GD/GD | `(21, 1)` | Grass on the west. |
| East edge | DG/DG | `(23, 1)` | Grass on the east. |
| NW cap | GG/GD | `(21, 0)` | North cell of a west end. |
| NE cap | GG/DG | `(23, 0)` | North cell of an east end. |
| SW corner | GD/GG | `(21, 2)` | South cell of a west end. |
| SE corner | DG/GG | `(23, 2)` | South cell of an east end. |
| Inner NW | GD/DD | `(23, 5)` | Inside crotch. |
| Inner NE | DG/DD | `(21, 5)` | Inside crotch. |
| Inner SW | DD/GD | `(23, 3)` | Inside crotch. |
| Inner SE | DD/DG | `(21, 3)` | Inside crotch. |

Neighbor bits: N=1, E=2, S=4, W=8. Fill is mask 15 only.

## Dirt path — rounded ends, 90°, approx 45°

4-connected only. No 1-tile jog. No 45° fill line. No sliced cells.

Widen to 2 when a run is ≥4. Both rows of a tube end in the same
column. Autotile, then force end columns:

```
West: (21, 0) over (21, 2)
East: (23, 0) over (23, 2)
```

90° = 2×2 knuckle (outer cap + inner bite + edges). Never a 2×2 of
fill. Force after autotile.

Approx 45° = two knuckles + riser of 2–4 tiles. At most two leans
per map. Example east-north-east:

```
Lower: inner (23,5) / east (23,1)
       south (22,2) / outer (23,2)
Upper: outer (21,0) / north (22,0)
       west  (21,1) / inner (21,3)
```

## Houses (0 or 1, unless the recipe names more)

Default is **zero or one** house per map. Two or more only when the
recipe `Houses` cell is an integer ≥ 2.

The sheet has four complete buildings. Never mix tiles from two
prefabs. When the recipe has exactly one house,
`house_id = (seed // 20) % 4` unless the recipe names an id.

| id | Name | What it is |
|---|---|---|
| 0 | Porch cottage | Large purple-roof house with wooden deck |
| 1 | Flower cottage | Mid size, flowers on the wall / window box |
| 2 | Gable cottage | Tall pointed roof, compact footprint |
| 3 | Hut | Small hut / L-wing cottage |

Split every placed prefab:

- `HOUSE_BODY` — walls, door, porch. Collision. Sort Y = doorstep.
- `HOUSE_ROOF` — gables + overhang. No collision. Sort Y = eave.

Recipes with `Houses = 0` place none. Recipes with `Houses = 2` place
two prefabs (different ids, ≥8 tiles apart, each with body/roof).

## Props that must appear when the recipe asks

All of these exist on `TILESET_brighter.png`. If a recipe flag is set
and none are placed, the seed has failed. Do not substitute flowers
for these.

**Bushes** — hedge squares, holey shrubs, and the small bush clusters
near the tree strip (top-left of the sheet + under the trees). Place
on lawn. Dense hedges may block (`world`). Loose shrubs are deco.

**Land rocks** — stones whose *bottom pixels are grass*, in the crate /
rock pile cluster. Lawn only. Blocking when the recipe says obstacle.

**Water plants** — reeds / cattails / water grass beside the water
autotile block. Only on WATER_SHORE or the first water ring.

**Water rocks** — stones whose *bottom pixels are water*, in the same
water-prop cluster (including the rock/creature sitting in water).
Only on water or shore. Never on lawn.

**Campfire** — the fire strip at the bottom of the prop cluster
(several frames; use frame 0 as the tile, animate if the scene
already supports it). Y-sorted actor. Collision. At most one.

**Torches** — the two standing torch tiles next to that strip. Place
on fence posts, gate sides, or the house approach. No collision
required.

**Signs** — eight distinct sign / notice / post tiles in the crate and
fence cluster. Enumerate them in `forest_terrain.gd` as `SIGN[0..7]`.
A recipe that lists signs must pick 1–3 different ids from that eight,
never the same id three times, never a crate standing in for a sign.

## Pond, fences, cliffs

Pond: compact blob from moisture. Fill only where water is surrounded.
Shore on every water–lawn edge. Then water plants / water rocks per
recipe. No 1-tile canals. World size is the blob, not 5×3.

Fences: 4-connected rails, real corners, min run 3. Torches may sit
on posts. Signs may sit next to a gate, not on the rail tile.

Cliffs: only recipes 4 and 16. Blob ≥4 tiles both axes. Cap + south
face + corners. Else omit.

## Forest generator

```
seed = map_id
recipe = seed % 20
n_houses = recipe.houses          # 0, 1, or 2 only if table says 2
house_ids = named id, else (seed // 20) % 4 for the first;
            second house = (first + 1 + seed) % 4
height, moist = fBm(seed, 4 octaves, freq 0.055 / 0.05)
pond_mask = CA(low+wet); drop <12 cells and tetrominoes
plateau_mask = CA(high); drop <40; keep only if recipe.plateau
flatten spawn disk and each house disk
path = A* 4-connected; widen 2; autotile PATH table; force caps
patches = grow 3–8 cell blobs; autotile PATCH atlas (18–20 or 24–26);
          Mode A or B grass paint; never a dark-green tile rectangle
          or a lone square fill; min 3 tiles from cobble
extras = fences/gate/plateau/pond per recipe
props  = bushes, land rocks, water plants/rocks, campfire,
         torches, signs per recipe
trees  = Poisson
verify walk + reject list
```

### Recipe table (`recipe = seed % 20`)

Houses = 0, 1, or 2 (2 only here when written). P/P2 = pond(s).
F = fence yard. G = gate line. C = plateau. L = approx-45° lean.
Patch = count of *blobs* after autotile (R round shape, I irregular
shape). Props: bushes, land rocks (LR), water plants (WP), water
rocks (WR), campfire (CF), torches (T), signs (S).

| # | Name | Houses | Water | Height | Path | Patch blobs | Props |
|---|---|---|---|---|---|---|---|
| 0 | Pastoral | 1×0 | P + WP + WR | F | trunk + L | R 2–3 | bushes, LR, T, S=1 |
| 1 | Crossroads | 1×1 | none | none | 2 trunks 90° | I 2–3 | bushes, LR, S=2 |
| 2 | Pond walk | 1×2 | P + WP + WR | none | skirts shore | R 2 | bushes, S=1 |
| 3 | Garden | 1×3 | none | F+G | through gate | R 2 | bushes, LR, T, S=2 |
| 4 | Lookout | 1×0 | none | C | to plateau foot | I 2 | LR obstacles, S=1 |
| 5 | Open meadow | 0 | none | none | edge-to-edge | R 3–4 | bushes, LR, no signs |
| 6 | Twin water | 1×1 | P2 + WP + WR | none | between blobs | R 1–2 | S=1 |
| 7 | South road | 1×2 | none | none | south third | I 2–3 | bushes, CF, T |
| 8 | Shore spur | 1×3 | P + WP + WR | none | trunk + spur | R 2 | S=2, T |
| 9 | Three-way | 1×0 | none | none | +2 branches 90° | I 2–3 | bushes, LR, S=3 |
| 10 | West hamlet | **2** (1 and 3) | P + WP | F | from east, L | RI 2 | CF, T, S=2 |
| 11 | East hamlet | 1×2 | P + WR | F | from west, L | R 2 | T, S=1, bushes |
| 12 | Wild lane | 0 | moisture P | none | 1 trunk | I 3–4 | bushes, LR obstacles |
| 13 | Orchard | 1×3 | none | none | short trunk | R 2 | bushes heavy, S=1 |
| 14 | Shore hamlet | 1×0 | P + WP + WR | F between | short trunk | R 1–2 | CF, T, S=2 |
| 15 | Double lean | 1×1 | none | none | two L | I 2–3 | LR, S=1 |
| 16 | Below the rim | 1×2 | none | C | lawn south of plateau | I 2 | LR, S=1, T |
| 17 | Gate road | 1×3 | none | G | through gate | R 2 | T on gate, S=2 |
| 18 | Sparse wild | 0 | P if blob | none | 1 trunk | I 1–2 | LR only |
| 19 | Switchback | 1×0 | none | none | U of two 90° | RI 2 | bushes, CF, S=1 |

`1×N` means one house of prefab N. Only recipe 10 places two houses.
Recipes 5, 12, 18 place zero.

If a flag cannot be placed without breaking autotile, drop *that extra*
only. Do not drop patch blobs, bushes, or signs just to keep the old
pastoral screenshot.

Reject a Painted Lands screenshot if: lawn is a motif stamp; fill sits
on a cap or knuckle; pond corners are square wave tiles; a cliff
fragment is orphaned; the actor draws through `HOUSE_BODY`; a 1-tile
stair fakes 45°; a PATCH cell is a square fill or a lone quadrant;
two houses appear on a recipe that lists 0 or 1; a PATCH sits on a
dark-green square/rectangle of baked grass; land rocks sit in
water or water rocks on lawn; a crate stands in for a sign.
