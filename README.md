# Mystic Clearing

A top-down real-time action RPG in Godot 4.6. You run through a meadow and swing in the direction you are facing. The feel to aim for is [Zoe and the Cursed Dreamer](https://game-endeavor.itch.io/zatcd): pixel art, direct movement, melee that follows facing. Zoe's property, crafting, and story stay out of this project.

The art is [Mystic Woods 2.2](https://game-endeavor.itch.io/mystic-woods) by [Game Endeavor](https://game-endeavor.itch.io/).

## Goal

A small action RPG you can walk and fight through: a few linked places, one weapon, enemies that occupy a hurtbox, and a camp where you can stop. Combat stays keyboard-facing. The swing goes where the character is facing, including after you let go of the movement keys.

The build order is:

1. This clearing, the player, and one swing. This is what runs today. The dirt path, the cliff shelf, and the lake are already in the generated grid.
2. One enemy, contact damage, and a player health pip. Still this clearing.
3. A second screen, generated with the same pipeline and a different seed.
4. A dropped pickup and a short swing combo.
5. A camp interaction (talk, rest). Inventory waits until a pickup exists.
6. A corrupted patch of woods as the first set piece.

Collision comes from bodies and tile polygons. Characters and UI stay off the tile layers. New world art snaps to the 16×16 pack grid. `docs/scene-assembly.md` and `docs/art-pack.md` are the rules for that.

## Capabilities

Playable scene: `scenes/clearing/clearing.tscn`. Godot 4.6, GL Compatibility. The window is 3440×1440 and the camera zoom is 5, so each 16px tile is 80 screen pixels. Textures use nearest filtering.

Movement and combat:

- Eight-direction walk at 80 pixels per second. Diagonals are normalized, so they are not faster than the cardinals.
- Any left or right input, including a diagonal, uses the side-facing walk. Pure up shows the back. Pure down shows the face. Left is the side row flipped.
- Standing still plays the forward idle. The facing stored for the next swing stays where it was.
- Space plays the attack row for that facing and holds the character still until the swing ends. Each attack row only has art in the first four columns, and those are the frames that play. The hitbox is live on frames 2 and 3 and looks for the `hurtbox` layer. Nothing is on that layer yet.

World:

- A 70×46 map from seed `21021`. The same layout is built on every launch.
- Meadow grass, a cliff plateau you walk around, a lake, and a two-tile dirt path with the pack's rounded corners from the spawn clearing to a shrine.
- Cliff cells and water cells are solid. Grass and the dirt path are open. A flood fill on that open ground reaches the shrine.
- Trees, flowers, and rocks from the pack sit on open grass, clear of both arenas.

A second scene, `scenes/grove/grove.tscn`, uses the same pack tiles and the same generator with seed `90511`. The character there is `assets/ai/characters/wanderer.png`. A third scene, `scenes/hollow/hollow.tscn`, uses seed `44107` and `assets/ai/characters/scout.png`. A fourth scene, `scenes/ford/ford.tscn`, uses seed `12809` and `assets/ai/characters/warrior-16x16-sheet.png`, a 16×16 cell sheet with the same ten rows. A fifth scene, `scenes/heath/heath.tscn`, uses seed `91003` with water turned off, so there is no lake. All five characters stand in a row there, 72 pixels apart, with their feet on one line and no movement scripts: the Mystic Woods warrior, the wanderer, the scout, the 16×16 warrior, and the red fighter. Open any of those scenes and press F6. A sixth scene, `scenes/forest/forest.tscn`, is built the same way from The Painted Lands forest tileset (antarcticbees), seed `91003`. The walker there is `character_sprite_sheet.png`: a forward-facing idle and walk, no attack, moving on the same eight-direction input. F5 still opens the meadow. The Painted Lands files are not redistributed; they stay in `assets/painted-lands/` and out of git.

There is no health, no enemy, and no save.

## Which art is generated

Hand-painted Mystic Woods files live in `assets/pack/`. Those are Game Endeavor's and are not in git.

AI-generated files live in `assets/ai/`. Those are `characters/wanderer.png`, `characters/scout.png`, `characters/warrior-16x16-sheet.png`, and `characters/red-fighter-16x16.png`. See `assets/ai/README.md`. Do not mix those files into `assets/pack/`.

## Terrain generation

`scripts/terrain.gd` builds a grid of pack tile ids. `scripts/clearing.gd` paints that grid. The output is atlas coordinates from `grass.png` and `plains.png`, not a rendered image.

`plains.png` is 6 columns by 12 rows of 16px:

| Rows | Terrain |
|---|---|
| 0–3 | Dirt on meadow grass, including the rounded corners and the east-west trail caps |
| 4–6 | Cliff top and the south-facing wall. This sheet has no north-facing wall, so the plateau reads as raised ground along its south rim |
| 8–11 | Water, the same corner set as the dirt block shifted down eight rows |

Meadow fill is the one cell in `grass.png`, `(80, 155, 102)`. Cliff-top green `(83, 160, 59)` stays on the plateau.

The generator runs these steps:

1. **Noise.** Height and moisture are value-noise fBm with 4 octaves. Each octave doubles the frequency and halves the amplitude. Height is sampled at `0.055` cycles per tile. Moisture is sampled at `0.05`, shifted by `(40, 20)` so it is not a copy of the height field.
2. **Thresholds.** Height above `0.64` is cliff. Height below `0.36` and moisture below `0.40` is water. The rest is grass.
3. **Smooth.** Three passes. A cliff or water cell with fewer than 4 of its 8 neighbors of the same kind becomes grass. A grass cell with 6 or more neighbors of that kind joins it.
4. **Erode and cull.** Two passes delete cliff cells that have fewer than 2 cliff neighbors on the cardinals, which cuts one-tile tendrils. Cliff blobs smaller than 40 cells, and water blobs smaller than 12, become grass.
5. **Arenas.** The spawn disk, radius 5, is forced to grass at `(35, 28)`. The shrine is the farthest of 40 seeded points from that spawn, then forced to grass in a disk of radius 4.
6. **Autotile.** Each feature cell looks at the four cardinal neighbors. The bit mask is N=1, E=2, S=4, W=8. Two adjacent bits select the rounded corner cell from the pack. A cell surrounded on all four sides picks a fill variant from a hash of its coordinates, so interior 3×3 patches are not copies of each other. Water uses the dirt mask table plus eight rows. Cliff rims prefer the south wall tiles, then the north lip, then the side edges.
7. **Carve, then autotile again.** A* from the spawn to the shrine costs 1 on grass, 12 on cliff, and 8 on water. The route and the cell east of it are stamped dirt, so the path is two tiles wide. Arena interiors and the map border stay grass. A short river stamp connects the nearest water to the west side of the map, skipping both arenas.
8. **De-dupe.** If two fully interior 3×3 dirt windows, or two plateau windows, share the same nine ids, the center of the later window swaps to another fill variant.
9. **Props.** Poisson sampling places trees at least 6.5 tiles apart, flowers and tufts 3.2 apart, and blocking rocks 8 apart, on grass outside the arenas. The shrine prefab adds a small tree, two rocks, and a flower on the shrine tile.
10. **Checks.** Every id is inside the pack sheets. A flood fill across grass and dirt from the spawn reaches the shrine. Interior dirt 3×3s and plateau 3×3s are unique. `clearing.gd` prints the report when the scene loads.

The scene paints grass under every cell, feature tiles above that, flowers on the deco layer, and trees with the player on a y-sorted layer. Collision is one static body covering cliff cells, water cells, and a ring just outside the map.

## Controls

| Input | Action |
|---|---|
| W A S D, or arrow keys | Move |
| Space | Swing |

## Run

Open the project in Godot 4.6 (GL Compatibility) and press F5. The main scene is the clearing.

From the editor path used on this machine:

```
Godot_v4.6.1-stable_win64.exe --path E:\code\grok-godot-mystic
```

## How it is put together

```
scenes/clearing/clearing.tscn   meadow root
scripts/terrain.gd              noise, biomes, autotile ids, path, props
scripts/clearing.gd             paints those ids and spawns props
scenes/player/player.tscn       CharacterBody2D, sprite, camera, hitbox
scripts/player.gd               movement, facing, swing
assets/pack/sprites/            Mystic Woods files used by this slice
```

`terrain.gd` writes a tile-id grid. Meadow fill is `grass.png`. Dirt, cliffs, and water are atlas cells in `plains.png` (rows 0–3, 4–6, and 8–11). Flowers and rocks come from `decor_16x16.png`. Trees are regions of `objects/objects.png`, y-sorted with the player. A static body covers cliff cells, water cells, and the map edge.

`player.gd` reads `player.png` at runtime. The sheet is 6 columns by 10 rows of 48×48. Rows are 0-based, from the pack's character readme:

| Rows | Clip |
|---|---|
| 0 | Idle, facing the camera. Rows 1 and 2 are the side and back idles. This slice does not play them. |
| 3–5 | Walk down, side, up |
| 6–8 | Attack down, side, up |
| 9 | Death. Unused. |

Feet are on frame row 42. The sprite offset puts that row on the body origin so y-sort and the collision box share the feet. `motion_mode` is floating.

Physics layers, in order: `world`, `player`, `enemy`, `hurtbox`, `hitbox`. The player is on `player` and collides with `world`. The swing's `Area2D` is on `hitbox` and masks `hurtbox`.

## How to add the next piece

An enemy belongs in its own scene, instanced under `Actors` in the clearing so it y-sorts with the player and the trees. Give it a hurtbox on layer `hurtbox` and a body on `enemy`. The player's hitbox already enables monitoring on swing frames 2 and 3. Connect `area_entered` or `body_entered` there, and keep the reaction in the enemy (flash, health, death row) so the player script stays about movement and the swing.

A second place is another scene with the same layer stack: ground, deco, y-sorted actors, collision. Use pack tiles only. Dirt and cliff edges come from `plains.png`. The cliff-top green `(83, 160, 59)` is a different family from the meadow green `(80, 155, 102)`. Keep them apart, or use the pack's transition cells between them. Door or path travel can wait until that second scene exists.

Keep new sprites at 1×. The drawn player is about 21 pixels tall inside the 48 pixel frame. Match that density.

## License

Code and this documentation are under the MIT license. See `LICENSE`. Copyright 2026 Keith C. Estanol.

Art under `assets/pack/` is Mystic Woods 2.2 by Game Endeavor. That pack is separate from the MIT license. Game Endeavor's terms allow the art in a project, including a commercial one, and allow modifying it. They do not allow redistributing or reselling the assets, even after modification. Buy the pack from [game-endeavor.itch.io/mystic-woods](https://game-endeavor.itch.io/mystic-woods). Updates are posted at [twitter.com/GameEndeavor](https://twitter.com/GameEndeavor).

Those sprites are not in this git repository. Copy your purchased pack into `assets/pack/sprites/` (characters, tilesets, and `objects/objects.png`) before opening the project.
