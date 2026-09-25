# Scene assembly

Shared inventory and QC. Map-specific generators live in `AGENTS.md`:
§ Mystic Woods vs § Painted Lands. Do not run one pack’s pipeline on
the other’s scenes.

## 0. Inventory the pack (required first step)

Write `docs/art-pack.md` if missing. Inventory **the sheet this scene
uses**, not both packs at once.

| Field | This repo |
|---|---|
| Tile size | 16×16 world tiles |
| Sheets | Mystic Woods: `plains.png` + `grass.png`. Painted Lands: `TILESET_brighter.png` |
| Camera | top-down, no perspective |
| Palette | extract from *that* sheet’s ground + wall tiles |
| Lighting | none / top-left, no cast shadows on ground |
| Layers | terrain, walls/water/fence, deco, overlays |

Slice rule: `tileId = row * cols + col`. Record GID / firstgid if using Tiled.

| Scenes | Pack | Generator |
|---|---|---|
| clearing, grove, hollow, ford, heath | Mystic Woods | `scripts/terrain.gd` — `AGENTS.md` § Mystic Woods |
| forest | Painted Lands | `scripts/forest_terrain.gd` — `AGENTS.md` § Painted Lands and §6 below |

Heath and forest may share a numeric seed. They do not share a generator.

## 1. Build a palette + scale lock

- Sample 8–12 tiles from the sheet this scene uses.
- Any new pixel must be near that palette (quantize if needed).
- Scale actors so a character is N tiles tall (pick N per sheet and keep it).
  Forest’s 32px character is two 16px tiles tall.

## 2. Compose the playing field

Use the Godot TileMap, not a collage:

1. **Ground** — 2–4 variants of the same terrain so the repeat is not wallpaper.
2. **Transitions** — only official autotile / blob tiles from *this* sheet.
3. **Solid structure** — Mystic Woods: cliffs and water. Painted Lands:
   fences, optional plateau (recipes 4 and 16), water blob, house body,
   blocking bushes / land rocks when the recipe says obstacle.
4. **Deco** — trees, PATCH dirt islands, bushes, signs, torches, campfire
   as **props** (y-sorted), not ground fill.
5. **Playable hole** — spawn, lanes, cover. Do not fill every cell with deco.
6. **Overlay** — foam, grass tufts, water plants on a separate layer.

Empty space is a design tool. A good field is readable at 1× zoom.

## 3. If a tile is missing

Only when **this** sheet lacks that terrain. Painted Lands already has
path caps, PATCH islands, four houses, bushes, land/water rocks, water
plants, campfire, torches, and eight signs — do not generate those.

1. Crop 2–4 tiles from the same sheet as style references.
2. Generate **one cell** at exact tile size (not a 1024px painting).
3. Prompt: same camera, same outline, “anonymous texture, continues off
   every edge, no hero motif, no directional shadow.”
4. Quantize to that sheet’s palette.
5. Composite 3×3 to `/tmp/tile-qc.png`. Seam or repeating motif = fail.

Do not generate a whole level painting and then slice it.

## 4. Background vs field

- **Parallax / sky / distant hills:** one wide strip behind the tilemap.
  Desaturate slightly so the field stays primary.
- **Playable ground:** only that pack’s tiles + approved generated tiles.
- Never use a generated cinematic plate as the walkable floor.

## 5. Verify before calling it done

Both packs:

- [ ] Tile size matches the sheet; no fractional scaling on world art
- [ ] 3×3 ground preview has no seam or checkerboard
- [ ] Collision matches solids for *this* pack
- [ ] Player / sprites share the intended pixels-per-tile
- [ ] Screenshot vs *that* pack’s reference strip
- [ ] No UI or text painted into tiles

Mystic Woods only: spawn flood-fill reaches the shrine; interior 3×3
dirt/plateau windows are unique (`clearing.gd` report).

Painted Lands only:

- [ ] Path caps and knuckles are not fill `(22, 1)`
- [ ] Pond shores are rounded (not a 5×3 wave rectangle)
- [ ] Actor does not draw through `HOUSE_BODY` when the recipe has a house
- [ ] No 1-tile 45° stair
- [ ] House count is 0 or 1, or 2 only on recipe 10
- [ ] House prefab matches the recipe (not always the porch cottage)
- [ ] Each PATCH is a 3–8 cell blob autotiled with `(18–20, 0–2)` or
      `(24–26, 0–2)` corners/edges — no lone square fill, no lone 8×8
      quadrant
- [ ] Bushes / land rocks / water plants / water rocks / campfire / torches /
      signs match the recipe flags
- [ ] Land rocks sit on lawn; water rocks sit on water or shore
- [ ] Signs are real sign tiles (`SIGN[0..7]`), not crates

## 6. Painted Lands forest generator

Atlas numbers, house counts, PATCH blob autotile, and the 20-row
table: `AGENTS.md` § Painted Lands. `recipe = seed % 20`.
Houses default to 0 or 1. Two houses only on recipe 10.

Do not use `plains.png` dirt, meadow `(80, 155, 102)`, or the
Mystic Woods default cliff threshold `0.64` here.

### Systems

- FLAT_GRASS — quiet speckle. Not a tuft icon on every cell.
- GRASS_DECO — flowers/tufts. Not a substitute for bushes or rocks.
- PATH_* — cobble `(21–23, *)` only. Fill `(22, 1)` is interior only.
- PATCH_* — multi-cell dirt *islands*. Grow 3–8 cells, then autotile
  with dirt-on-grass `(18–20, 0–2)` or `(24–26, 0–2)`:
  NW `(18,0)` N `(19,0)` NE `(20,0)` / W `(18,1)` F `(19,1)` E `(20,1)` /
  SW `(18,2)` S `(19,2)` SE `(20,2)`. Ragged row-3 tiles only as
  interiors. Never a lone square or a lone quadrant.
- WATER_* — autotile source columns 44–46, rows 0–2. Then water plants
  and water rocks from the same cluster.
- FENCE / GATE — recipe.
- CLIFF_* — recipes 4 and 16 only.
- HOUSE count 0 or 1, or 2 on recipe 10. Prefabs 0 porch, 1 flower,
  2 gable, 3 hut. Body collides (sort at doorstep). Roof does not
  (sort at eave).
- BUSH, LAND_ROCK, WATER_PLANT, WATER_ROCK, CAMPFIRE, TORCH, SIGN[0..7].
- TREES — Poisson; count and gap from the recipe.

Layers: Ground (grass) → Features (path, patches, water, fence, cliff) →
Deco (flowers, bushes, plants) → Actors (trees, rocks, signs, fire,
torches, house parts, characters).

### Generator order

1. `recipe = seed % 20`; house count from the table.
2. fBm height + moisture (4 octaves).
3. Pond / plateau candidates; drop specks; keep only if the recipe wants them.
4. Flatten spawn + each house disk.
5. A* cobble PATH; widen 2; force caps and knuckles.
6. Grow PATCH blobs (3–8 cells); autotile PATCH atlas; no lone squares.
7. Fence / gate / plateau.
8. Bushes, land rocks, water plants/rocks, campfire, torches, signs.
9. Trees + flower deco.
10. Verify walkability and the Painted Lands reject list.

### Path vs patch

Path = 4-connected cobble tube.
Patch = small dirt blob whose **outline uses corner and edge tiles**
so grass eats the corners. Same method as a tiny pond. Do not stamp
one fill cell and call it a patch.

### Recipes 0–19

Full flags in `AGENTS.md`. Houses: 0 on 5/12/18, **2 on 10 only**,
1 on every other recipe. Patch column is blob count after autotile,
not raw square stamps.
