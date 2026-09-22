# Art pack

Source: `I:\game assets\mystic_woods_2.2` (Mystic Woods 2.2, Game Endeavor).
Project copy: `assets/pack/sprites/`. Enemies are not copied into this slice.

| Field | Value |
|---|---|
| Tile size | 16×16 |
| Character frame | 48×48, 6 columns. Slime in the source pack is 32×32 and is unused. |
| Sheet layout | No padding. `tileId = row * cols + col`. |
| Camera | Top-down, no perspective. |
| Palette | Meadow green `(80, 155, 102)`, tuft shadow `(41, 102, 64)`, tuft highlight `(105, 181, 127)`, dirt `(157, 118, 88)`, fence wood, water blue `(103, 117, 152)`. Cliff-top green `(83, 160, 59)` is a separate family and is not mixed into the meadow. |
| Lighting | Flat tiles. Props carry small top-left highlights. No cast shadows on the ground. |
| Layers in pack | `tilesets/grass.png` (meadow fill), `tilesets/plains.png` (dirt, cliff, water transitions), `tilesets/decor_16x16.png` (overlay), `tilesets/fences.png`, `tilesets/walls/`, `objects/objects.png`, characters. |

## What this slice uses

- Ground fill is `grass.png`, one seamless meadow cell. Every pixel is `(80, 155, 102)`.
- Variety sits on the deco layer. `decor_16x16.png` uses that same green as its background, so flowers, tufts, and pebbles do not leave a seam.
- Fence rails are column 2, row 0 of `fences.png` (the column that connects when repeated).
- Trees and bushes are regions of `objects/objects.png`, placed on the y-sorted actor layer with the trunk base on a tile corner.
- The player is `characters/player.png` at 1×. The drawn body is about 21px tall inside the 48px frame. Feet sit on frame row 42.

## Player sheet

From `sprites/characters/README.txt`. Rows are 0-based. Left-facing art is the right-facing row with `flip_h`.

| Rows | Use |
|---|---|
| 0–2 | Idle: down, side, up. This slice plays row 0 while standing, so idle always faces forward. |
| 3–5 | Walk: down, side, up. |
| 6–8 | Attack: down, side, up. |
| 9 | Death. Unused. |

Diagonals move in eight directions. Any horizontal input uses the side row (pack convention for this sheet). Pure up shows the back. Pure down shows the face.
