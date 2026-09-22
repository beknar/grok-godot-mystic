# Mystic Clearing

A top-down real-time action RPG in Godot 4.6. You run through a meadow and swing in the direction you are facing. The feel to aim for is [Zoe and the Cursed Dreamer](https://game-endeavor.itch.io/zatcd): pixel art, direct movement, melee that follows facing. Zoe's property, crafting, and story stay out of this project.

The art is [Mystic Woods 2.2](https://game-endeavor.itch.io/mystic-woods) by [Game Endeavor](https://game-endeavor.itch.io/).

## Goal

A small action RPG you can walk and fight through: a few linked places, one weapon, enemies that occupy a hurtbox, and a camp where you can stop. Combat stays keyboard-facing. The swing goes where the character is facing, including after you let go of the movement keys.

The build order is:

1. This meadow, the player, and one swing. This is what runs today.
2. One enemy, contact damage, and a player health pip. Still this meadow.
3. A second screen, using the dirt and cliff transitions in `plains.png`.
4. A dropped pickup and a short swing combo.
5. A camp interaction (talk, rest). Inventory waits until a pickup exists.
6. A corrupted patch of woods as the first set piece.

Collision comes from bodies and tile polygons. Characters and UI stay off the tile layers. New world art snaps to the 16×16 pack grid. `docs/scene-assembly.md` and `docs/art-pack.md` are the rules for that.

## Current state

Playable scene: `scenes/clearing/clearing.tscn`.

- A 64×40 meadow of the pack grass tile, with flowers, rocks, trees, and a rail fence.
- The player walks in eight directions at 80 pixels per second. Diagonals are normalized so they are not faster.
- Any left or right input, including a diagonal, uses the side-facing walk. Pure up shows the back. Pure down shows the face. Left is the side row flipped.
- Standing still plays the forward idle. The facing stored for the next swing does not change while you stand still.
- Space plays the attack row that matches that facing and locks movement until the swing ends. The hitbox is live on frames 2 and 3. It looks for the `hurtbox` physics layer. Nothing is on that layer yet.
- The window is 3440×1440. The camera zoom is 5, so each 16px tile is 80 screen pixels. Textures use nearest filtering.

There is no health, no enemy, no second room, and no save.

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
scripts/clearing.gd             paints ground and deco, spawns trees, fence, bounds
scenes/player/player.tscn       CharacterBody2D, sprite, camera, hitbox
scripts/player.gd               movement, facing, swing
assets/pack/sprites/            Mystic Woods files used by this slice
```

`clearing.gd` builds the map when the scene enters the tree. Ground is one cell of `grass.png`. Flowers and the large rock come from `decor_16x16.png`, which uses the same meadow green, so they sit on the fill without a seam. Trees and bushes are regions of `objects/objects.png`, y-sorted with the player, origin at the trunk base. Fence posts are column 2, row 0 of `fences.png`. A static body around the map edge keeps the player inside.

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
