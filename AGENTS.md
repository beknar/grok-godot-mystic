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
