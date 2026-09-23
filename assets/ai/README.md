# AI-generated art

Everything under `assets/ai/` was generated in Grok Build. It is not part of Mystic Woods and it is not hand-painted.

| File | What it is |
|---|---|
| `characters/wanderer.png` | A woman in the Mystic Woods pixel style, with long yellow hair and a brighter coral tunic. 6 columns by 10 rows of 48×48. Same row order as `player.png`: idle down/side/up, walk down/side/up, attack down/side/up, death. Attack rows use the first four columns. |
| `characters/scout.png` | A woman in the same pixel style, with a short blonde bob and a light cream tunic. Same 6-by-10 grid and the same clips as `player.png`. |
| `characters/warrior-16x16-sheet.png` | A warrior on the same ten-row layout, drawn in 16×16 cells (96×160). Attack rows use the first four columns. The ford scene sets `frame_size` to 16 so those cells are read correctly. |
| `characters/red-fighter-16x16.png` | A red fighter on that same 16×16, ten-row layout. The heath scene uses it with `frame_size` 16. |

Hand-painted pack art stays in `assets/pack/`. Do not move AI files into that folder.
