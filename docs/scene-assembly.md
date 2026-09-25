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
| forest, wilds | Painted Lands | `scripts/forest_terrain.gd`, `scripts/wilds_terrain.gd` — `AGENTS.md` § Painted Lands and §6 below |

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
   fences, optional plateau (recipes 4 and 16 only), water blob, house body.
4. **Deco** — trees, crates as **props** (y-sorted), not ground tiles.
5. **Playable hole** — spawn, lanes, cover. Do not fill every cell with deco.
6. **Overlay** — foam, grass tufts on a separate layer.

Empty space is a design tool. A good field is readable at 1× zoom.

## 3. If a tile is missing

Only when **this** sheet lacks that terrain. Painted Lands already has
dirt caps, edges, knuckles, and water shores — do not generate those.

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

Painted Lands only: path caps and knuckles are not fill `(22, 1)`;
pond shores are rounded (not a 5×3 wave rectangle); actor does not
draw through `HOUSE_BODY` when the recipe has a house; no 1-tile
45° stair; recipe extras that failed the blob test were dropped
instead of faked.

## 6. Painted Lands forest generator

Atlas numbers and knuckle diagrams: `AGENTS.md` § Painted Lands.
`recipe = seed % 20`. Same organic loop as Mystic Woods, different
paint and a 20-row recipe table.

Do not use `plains.png` dirt, meadow `(80, 155, 102)`, or the
Mystic Woods default cliff threshold `0.64` here.

### Systems

- FLAT_GRASS — quiet speckle. Not a tuft icon on every cell.
- GRASS_DECO — density from the recipe, no lattice.
- PATH_* — cobble table in AGENTS.md. Fill `(22, 1)` is interior only
  and does not appear on a 2-wide tube.
- WATER_* — autotile *source* is sheet columns 44–46, rows 0–2.
  That 5×3 is not the world pond’s footprint.
- FENCE — yard, gate line, or omit (recipe).
- CLIFF_* — recipes 4 and 16 only; blob ≥4 tiles both axes; else omit.
- HOUSE_BODY / HOUSE_ROOF — when the recipe has a house.
- TREES — Poisson; count and gap from the recipe.

Layers: Ground (grass) → Features (path, water, fence, cliff) →
Deco → Actors (trees, house parts, characters).

### Generator order

1. `recipe = seed % 20`
2. fBm height + moisture (4 octaves, same freqs as Mystic Woods
   *sampling*, not its biome paint).
3. Pond candidates from low+wet; CA; drop <12 cells and tetrominoes.
4. Plateau candidates from high height; CA + erode; drop <40 cells;
   keep only if the recipe lists a plateau.
5. Flatten spawn disk and house disk.
6. A* 4-connected path per recipe (trunk, optional branches, optional
   2–4 tile riser). Widen 2. Autotile. Force caps and knuckles.
7. Place pond/fence/gate/plateau extras. If an extra fails its test,
   omit it.
8. Poisson trees + deco.
9. Verify walkability and the Painted Lands reject list.

### Path

4-connected. 2-wide when a run is ≥4. Both rows of a tube end in the
same column. Force end columns after autotile:

```
West: (21, 0) over (21, 2)
East: (23, 0) over (23, 2)
```

90° = 2×2 knuckle. Approx 45° = two knuckles + riser of 2–4 tiles.
At most two leans per map. Never a 1-tile stair. Never slice a 16×16
cell into world 8×8 tiles.

### Pond

Blob from moisture. Fill only where water is surrounded. Shore on
every water–lawn edge. No 1-tile canals. Do not stamp the atlas 5×3.

### Height

Fences or gate when the recipe says so. Cliffs only on recipes 4 and
16, and only if cap + south face + corners cover the whole blob.

### Recipes 0–19

Full flag table is in `AGENTS.md` § Painted Lands. Short list:

0 Pastoral (current forest.tscn), 1 Crossroads, 2 Pond walk,
3 Garden, 4 Lookout, 5 Open meadow, 6 Twin water, 7 South road,
8 Shore spur, 9 Three-way, 10 West hamlet, 11 East hamlet,
12 Wild lane, 13 Orchard, 14 Shore hamlet, 15 Double lean,
16 Below the rim, 17 Gate road, 18 Sparse wild, 19 Switchback.

New forest seeds must change recipe with `seed % 20`. Autotile
methods stay those in AGENTS.md. Do not run 0–19 on Mystic Woods maps.
