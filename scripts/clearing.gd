@tool
extends Node2D

# Meadow is grass.png (flat 16px, color 80,155,102).
# decor_16x16.png uses that same green, so overlays do not seam.
# Fence column 2 row 0 is the rail that connects when repeated.
const TILE := 16
const MAP_SIZE := Vector2i(64, 40)
const SPAWN_TILE := Vector2i(32, 22)

const GRASS: Texture2D = preload("res://assets/pack/sprites/tilesets/grass.png")
const DECOR: Texture2D = preload("res://assets/pack/sprites/tilesets/decor_16x16.png")
const FENCE: Texture2D = preload("res://assets/pack/sprites/tilesets/fences.png")
const OBJECTS: Texture2D = preload("res://assets/pack/sprites/objects/objects.png")

# x, y, atlas_x, atlas_y on decor_16x16.png
const DECOR_PLACEMENTS: Array = [
	[18, 16, 0, 0],
	[22, 15, 1, 0],
	[27, 17, 2, 0],
	[36, 16, 3, 0],
	[41, 18, 0, 2],
	[44, 15, 1, 2],
	[24, 24, 2, 2],
	[28, 26, 3, 2],
	[38, 25, 0, 0],
	[43, 27, 1, 0],
	[19, 27, 2, 0],
	[48, 22, 3, 1],
	[15, 22, 0, 2],
	[34, 14, 1, 2],
	[30, 28, 3, 0],
	[46, 20, 2, 2],
]

const ROCKS: Array[Vector2i] = [
	Vector2i(12, 18),
	Vector2i(51, 19),
	Vector2i(34, 10),
	Vector2i(22, 34),
]

# tile x, tile y, region x, y, w, h in objects.png
const TREES: Array = [
	[6, 8, 1, 80, 45, 64],
	[14, 12, 49, 80, 45, 64],
	[18, 7, 3, 147, 43, 61],
	[50, 8, 51, 147, 43, 61],
	[57, 15, 1, 80, 45, 64],
	[55, 26, 49, 80, 45, 64],
	[46, 35, 3, 147, 43, 61],
	[16, 35, 51, 147, 43, 61],
	[8, 28, 1, 80, 45, 64],
	[26, 9, 49, 80, 45, 64],
]

const BUSHES: Array = [
	[21, 13, 96, 112, 32, 32],
	[42, 13, 96, 112, 32, 32],
	[37, 33, 132, 102, 23, 42],
]

const FENCE_Y := 31
const FENCE_X0 := 24
const FENCE_X1 := 40

var _built := false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built and not Engine.is_editor_hint():
		return
	_built = true
	_paint_ground()
	_paint_deco()
	_clear_props()
	_spawn_props()
	_build_bounds()
	$Actors/Player.position = Vector2(SPAWN_TILE.x * TILE, SPAWN_TILE.y * TILE)


func _paint_ground() -> void:
	var layer := $Ground as TileMapLayer
	layer.tile_set = _atlas_tileset(GRASS, Vector2i(16, 16))
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))


func _paint_deco() -> void:
	var layer := $Deco as TileMapLayer
	layer.tile_set = _atlas_tileset(DECOR, Vector2i(16, 16))
	layer.clear()
	for spot in DECOR_PLACEMENTS:
		layer.set_cell(Vector2i(int(spot[0]), int(spot[1])), 0, Vector2i(int(spot[2]), int(spot[3])))
	for rock in ROCKS:
		layer.set_cell(rock, 0, Vector2i(2, 1))


func _clear_props() -> void:
	var actors := $Actors
	for child in actors.get_children():
		if child.is_in_group("world_prop"):
			child.free()


func _spawn_props() -> void:
	var actors := $Actors
	for tree in TREES:
		_add_prop(actors, Vector2i(int(tree[0]), int(tree[1])), Rect2(tree[2], tree[3], tree[4], tree[5]), Vector2(12, 8))
	for bush in BUSHES:
		_add_prop(actors, Vector2i(int(bush[0]), int(bush[1])), Rect2(bush[2], bush[3], bush[4], bush[5]), Vector2(10, 6))
	var fence_atlas := AtlasTexture.new()
	fence_atlas.atlas = FENCE
	fence_atlas.region = Rect2(32, 0, 16, 16)
	for x in range(FENCE_X0, FENCE_X1 + 1):
		var post := StaticBody2D.new()
		post.position = Vector2(x * TILE + 8, FENCE_Y * TILE + TILE)
		post.collision_layer = 1
		post.collision_mask = 0
		post.add_to_group("world_prop")
		var spr := Sprite2D.new()
		spr.texture = fence_atlas
		spr.centered = true
		spr.offset = Vector2(0, -8)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		post.add_child(spr)
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(14, 8)
		col.shape = shape
		col.position = Vector2(0, -6)
		post.add_child(col)
		actors.add_child(post)


func _add_prop(actors: Node2D, tile: Vector2i, region: Rect2, body_size: Vector2) -> void:
	var prop := StaticBody2D.new()
	prop.position = Vector2(tile.x * TILE + 8, tile.y * TILE + TILE)
	prop.collision_layer = 1
	prop.collision_mask = 0
	prop.add_to_group("world_prop")
	var atlas := AtlasTexture.new()
	atlas.atlas = OBJECTS
	atlas.region = region
	var spr := Sprite2D.new()
	spr.texture = atlas
	spr.centered = true
	spr.offset = Vector2(0, -region.size.y * 0.5)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prop.add_child(spr)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = body_size
	col.shape = shape
	col.position = Vector2(0, -4)
	prop.add_child(col)
	actors.add_child(prop)


func _build_bounds() -> void:
	var body := $Bounds as StaticBody2D
	for child in body.get_children():
		child.free()
	var w := float(MAP_SIZE.x * TILE)
	var h := float(MAP_SIZE.y * TILE)
	var thick := 16.0
	_add_wall(body, Vector2(w * 0.5, -thick * 0.5), Vector2(w + thick * 2.0, thick))
	_add_wall(body, Vector2(w * 0.5, h + thick * 0.5), Vector2(w + thick * 2.0, thick))
	_add_wall(body, Vector2(-thick * 0.5, h * 0.5), Vector2(thick, h))
	_add_wall(body, Vector2(w + thick * 0.5, h * 0.5), Vector2(thick, h))


func _add_wall(body: StaticBody2D, at: Vector2, size: Vector2) -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	col.position = at
	body.add_child(col)


func _atlas_tileset(texture: Texture2D, cell: Vector2i) -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = cell
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = cell
	var grid := Vector2i(texture.get_width() / cell.x, texture.get_height() / cell.y)
	for y in grid.y:
		for x in grid.x:
			source.create_tile(Vector2i(x, y))
	tiles.add_source(source, 0)
	return tiles
