@tool
extends Node2D

const TILE := 16
const GRASS: Texture2D = preload("res://assets/pack/sprites/tilesets/grass.png")
const PLAINS: Texture2D = preload("res://assets/pack/sprites/tilesets/plains.png")
const DECOR: Texture2D = preload("res://assets/pack/sprites/tilesets/decor_16x16.png")
const OBJECTS: Texture2D = preload("res://assets/pack/sprites/objects/objects.png")
const TerrainScript := preload("res://scripts/terrain.gd")

var generation_report := ""
var _built := false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built and not Engine.is_editor_hint():
		return
	_built = true
	var data: Dictionary = TerrainScript.new().generate()
	generation_report = str(data["report"])
	print(generation_report)
	_paint(data)
	_clear_props()
	_spawn_props(data["props"])
	_build_bounds(int(data["width"]), int(data["height"]), data["biome"])
	var spawn: Vector2i = data["spawn"]
	var player := $Actors/Player
	player.position = Vector2(spawn.x * TILE + 8, spawn.y * TILE + TILE)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(data["width"]) * TILE
	camera.limit_bottom = int(data["height"]) * TILE


func _paint(data: Dictionary) -> void:
	# Features are pack atlas ids. Meadow grass is the layer underneath.
	var ground := $Ground as TileMapLayer
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	var grass_src := TileSetAtlasSource.new()
	grass_src.texture = GRASS
	grass_src.texture_region_size = Vector2i(TILE, TILE)
	grass_src.create_tile(Vector2i.ZERO)
	tiles.add_source(grass_src, 0)
	var plains_src := TileSetAtlasSource.new()
	plains_src.texture = PLAINS
	plains_src.texture_region_size = Vector2i(TILE, TILE)
	tiles.add_source(plains_src, 1)
	for y in 12:
		for x in 6:
			plains_src.create_tile(Vector2i(x, y))
	ground.tile_set = _grass_only_tileset()
	ground.clear()
	var features := $Features as TileMapLayer
	features.tile_set = tiles
	features.clear()
	var w: int = data["width"]
	var h: int = data["height"]
	var biome: PackedInt32Array = data["biome"]
	var src: PackedInt32Array = data["src"]
	var ax: PackedInt32Array = data["ax"]
	var ay: PackedInt32Array = data["ay"]
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			ground.set_cell(cell, 0, Vector2i.ZERO)
			var n := y * w + x
			if biome[n] == 0:
				continue
			features.set_cell(cell, src[n], Vector2i(ax[n], ay[n]))
	var deco := $Deco as TileMapLayer
	deco.tile_set = _decor_tileset()
	deco.clear()


func _grass_only_tileset() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	var source := TileSetAtlasSource.new()
	source.texture = GRASS
	source.texture_region_size = Vector2i(TILE, TILE)
	source.create_tile(Vector2i.ZERO)
	tiles.add_source(source, 0)
	return tiles


func _decor_tileset() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	var source := TileSetAtlasSource.new()
	source.texture = DECOR
	source.texture_region_size = Vector2i(TILE, TILE)
	for y in 5:
		for x in 4:
			source.create_tile(Vector2i(x, y))
	tiles.add_source(source, 0)
	return tiles


func _clear_props() -> void:
	for child in $Actors.get_children():
		if child.is_in_group("world_prop"):
			child.free()


func _spawn_props(props: Array) -> void:
	var actors := $Actors
	for item in props:
		var tile: Vector2i = item["tile"]
		if item.has("deco"):
			var atlas: Vector2i = item["deco"]
			if item.get("blocking", false):
				_add_deco_body(actors, tile, atlas)
			else:
				($Deco as TileMapLayer).set_cell(tile, 0, atlas)
			continue
		_add_sprite_prop(actors, tile, item["region"], item["body"])


func _add_deco_body(actors: Node, tile: Vector2i, atlas_coords: Vector2i) -> void:
	var prop := StaticBody2D.new()
	prop.position = Vector2(tile.x * TILE + 8, tile.y * TILE + TILE)
	prop.collision_layer = 1
	prop.collision_mask = 0
	prop.add_to_group("world_prop")
	var atlas := AtlasTexture.new()
	atlas.atlas = DECOR
	atlas.region = Rect2(atlas_coords.x * TILE, atlas_coords.y * TILE, TILE, TILE)
	var spr := Sprite2D.new()
	spr.texture = atlas
	spr.centered = true
	spr.offset = Vector2(0, -8)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prop.add_child(spr)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 8)
	col.shape = shape
	col.position = Vector2(0, -4)
	prop.add_child(col)
	actors.add_child(prop)


func _add_sprite_prop(actors: Node, tile: Vector2i, region: Rect2, body_size: Vector2) -> void:
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


func _build_bounds(w: int, h: int, biome: PackedInt32Array) -> void:
	var body := $Bounds as StaticBody2D
	for child in body.get_children():
		child.free()
	for y in h:
		for x in w:
			var kind := biome[y * w + x]
			if kind != 2 and kind != 3:
				continue
			_add_wall(body, Vector2(x * TILE + 8, y * TILE + 8), Vector2(TILE, TILE))
	var px := float(w * TILE)
	var py := float(h * TILE)
	var thick := 16.0
	_add_wall(body, Vector2(px * 0.5, -thick * 0.5), Vector2(px + thick * 2.0, thick))
	_add_wall(body, Vector2(px * 0.5, py + thick * 0.5), Vector2(px + thick * 2.0, thick))
	_add_wall(body, Vector2(-thick * 0.5, py * 0.5), Vector2(thick, py))
	_add_wall(body, Vector2(px + thick * 0.5, py * 0.5), Vector2(thick, py))


func _add_wall(body: StaticBody2D, at: Vector2, size: Vector2) -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	col.position = at
	body.add_child(col)
