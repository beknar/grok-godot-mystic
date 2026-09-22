# Mystic Clearing

A top-down real-time action RPG in the feel of [Zoe and the Cursed Dreamer](https://game-endeavor.itch.io/zatcd): pixel art, a character who runs through a place, and melee that follows facing. The art is the Mystic Woods pack, assembled as tile layers. Zoe's property, crafting, and god-lore stay out of this project. The combat model is the keyboard one: the swing follows the direction you are facing.

Godot 4.6, GL Compatibility. The window stays 3440×1440. The camera zoom is 5, so each 16px tile lands on 80 screen pixels (43×18 tiles in view) with nearest filtering.

## Playable now

One meadow, `scenes/clearing/clearing.tscn`.

- WASD or arrows move in eight directions. Speed is 80 px/s and diagonals are normalized.
- Side-facing walk and attack when there is any left/right input. Pure up plays the back. Pure down plays the face. Left is the side row flipped.
- Standing still plays the forward idle, on row 0. The stored facing used for the next swing does not change while idle.
- Space plays the matching attack row and locks movement until the swing ends. The hitbox is on physics layer `hitbox` and looks for `hurtbox`. Nothing occupies `hurtbox` yet.

## Later, in order

1. One enemy with a hurtbox, contact damage, and a player health pip. Still this meadow.
2. A second screen through a path, using `plains.png` dirt and cliff transitions instead of a flat edge.
3. A dropped pickup and a short swing combo.
4. A camp interaction (talk, rest). No inventory UI until a pickup exists.
5. A corrupted patch of the woods as the first set piece. Still no second weapon until the swing feels right.

Collision stays on bodies and tile polygons. Characters and UI stay off the tile layers.
