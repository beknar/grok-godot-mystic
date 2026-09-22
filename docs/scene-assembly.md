# Scene assembly

## 0. Inventory the pack (required first step)

Write `docs/art-pack.md` if missing:

| Field | Example |
|---|---|
| Tile size | 32×32 |
| Sheet layout | 16 cols, 8 rows, no padding / 1px padding |
| Camera | top-down, no perspective |
| Palette | extract 16–32 colors from ground + wall tiles |
| Lighting | none / top-left, no cast shadows on ground |
| Layers in pack | terrain, walls, water, deco, overlays |

Slice rule: `tileId = row * cols + col`. Record GID / firstgid if using Tiled.

## 1. Build a palette + scale lock

- Sample 8–12 pack tiles (grass, dirt, stone, wall).
- Any new pixel must be near that palette (quantize if needed).
- Scale actors so a character is N tiles tall (pick N and keep it).

## 2. Compose the playing field

Use the engine tilemap (Tiled / Phaser / Godot TileMap), not a collage:

1. **Ground** — 2–4 variants of the same terrain so the repeat is not wallpaper.
2. **Transitions** — only official autotile / blob / Wang tiles from the pack.
3. **Solid structure** — walls, cliffs, water; these own collision.
4. **Deco** — trees, crates, rugs as **props** (y-sorted), not ground tiles.
5. **Playable hole** — keep a clear arena: spawn, lanes, cover. Do not fill
   every cell with deco.
6. **Overlay** — shadows, foam, grass tufts as a separate layer so you can
   hide them.

Empty space is a design tool. A good field is readable at 1× zoom.

## 3. If a tile is missing

1. Crop 2–4 pack tiles as style references.
2. Generate **one cell** at exact tile size (not a 1024px painting).
3. Prompt: same camera, same outline, “anonymous texture, continues off
   every edge, no hero motif, no directional shadow.”
4. Quantize to pack palette.
5. Mandatory: composite 3×3 to `/tmp/tile-qc.png` and look for seam lines
   and a motif that appears in every quadrant. Fail = retry or use pack.

Do not generate a whole level painting and then try to slice it.

## 4. Background vs field

- **Parallax / sky / distant hills:** one wide strip, not tiled ground.
  Sit *behind* the tilemap. Desaturate slightly so the field stays primary.
- **Playable ground:** only pack tiles + approved generated tiles.
- Never use a generated cinematic plate as the walkable floor.

## 5. Verify before calling it done

- [ ] Tile size matches pack; no fractional scaling on world art
- [ ] 3×3 ground preview has no seam or checkerboard
- [ ] Collision layer matches walls/pits/water
- [ ] Player / sprites share the same pixels-per-tile
- [ ] Screenshot vs pack reference: same contrast and outline weight
- [ ] No UI, health bars, or text painted into tiles
