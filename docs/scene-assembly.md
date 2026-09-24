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
| forest, garden | Painted Lands | `scripts/forest_terrain.gd`, `scripts/garden_terrain.gd` — `AGENTS.md` § Painted Lands and §6 below |

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
   fences (default) or one legal plateau; water blob; house body.
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
draw through `HOUSE_BODY`; no 1-tile 45° stair.

## 6. Painted Lands layout (`TILESET_brighter.png`)

Atlas numbers and knuckle diagrams: `AGENTS.md` § Painted Lands.
This section is the layout contract those tables implement.

Do not use `plains.png` dirt, meadow `(80, 155, 102)`, or the
Mystic Woods cliff/water thresholds here.

### Systems

- FLAT_GRASS — quiet speckle. Not a tuft icon on every cell.
- GRASS_DECO — flowers/tufts on ~6–10% of lawn, no lattice.
- PATH_* — cobble table in AGENTS.md. Fill `(22, 1)` is interior only
  and does not appear on a 2-wide tube.
- WATER_* — autotile *source* is sheet columns 44–46, rows 0–2.
  That 5×3 is not the world pond’s footprint.
- FENCE — default pastoral height. Min run 3, real corners.
- CLIFF_* — recipe E only; blob ≥4 tiles both axes; else omit.
- HOUSE_BODY / HOUSE_ROOF — split prefab. Body collides, sort at
  doorstep. Roof does not collide, sort at eave.
- TREES — Poisson, gap 5–6, 3–6 per screen, y-sorted.

Layers: Ground (grass) → Features (path, water, fence, cliff) →
Deco → Actors (trees, house parts, characters).

### Path

4-connected. 2-wide when a run is ≥4. Both rows of a tube end in the
same column. Force end columns after autotile:

```
West: (21, 0) over (21, 2)
East: (23, 0) over (23, 2)
```

90° = 2×2 knuckle. Approx 45° = two knuckles + riser of 2–4 tiles.
Never a 1-tile stair. Never slice a 16×16 cell into world 8×8 tiles.
Force knuckles after autotile.

### Pond

One blob, ≥3×3 interior. Fill only where water is surrounded. Shore
on every water–lawn edge. No 1-tile canals. Do not stamp the atlas
5×3 block as the lake.

### Height

Fences by default. Cliffs only on Lookout, and only if cap + south
face + corners cover the whole blob.

### Recipes (Painted Lands seeds only)

1. Lawn. 2. House if the recipe has one. 3. Path trunk + optional
approx-45° branch. 4. Optional pond. 5. Fence yard *or* one plateau.
6. Trees + sparse deco.

- A Pastoral — current `forest.tscn` vibe
- B Crossroads — two trunks, no pond
- C Pond walk — path skirts a complete shore
- D Garden — `garden.tscn`: fence rectangle, gate on the riser, no cliffs
- E Lookout — one legal plateau; no fences

Max two extras besides the trunk. New forest seeds may change pond /
fence / path graph. Autotile *methods* stay those in AGENTS.md.
Do not run A–E on Mystic Woods maps.
