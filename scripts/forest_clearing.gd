@tool
extends Node2D

const TILE := 16
const TILESET: Texture2D = preload("res://assets/pack/TILESET_brighter.png")
const TerrainScript := preload("res://scripts/forest_terrain.gd")

var generation_report := ""
var _built := false


func _ready() -> void:
	_build()


func _generate() -> Dictionary:
	return TerrainScript.new().generate()


func _build() -> void:
	if _built and not Engine.is_editor_hint():
		return
	_built = true
	var data: Dictionary = _generate()
	generation_report = str(data["report"])
	print(generation_report)
	_paint(data)
	_clear_props()
	_spawn_props(data["props"])
	_build_bounds(int(data["width"]), int(data["height"]), data["biome"])
	var spawn: Vector2i = data["spawn"]
	var player := $Actors/Walker
	player.position = Vector2(spawn.x * TILE + 8, spawn.y * TILE + TILE)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(data["width"]) * TILE
	camera.limit_bottom = int(data["height"]) * TILE


func _paint(data: Dictionary) -> void:
	var tiles := _make_tileset()
	var ground := $Ground as TileMapLayer
	var cliff := $Cliff as TileMapLayer
	var path := $Path as TileMapLayer
	var water := $Water as TileMapLayer
	var deco := $Deco as TileMapLayer
	for layer in [ground, cliff, path, water, deco]:
		layer.tile_set = tiles
		layer.clear()
	var w: int = data["width"]
	var h: int = data["height"]
	var grass: PackedInt32Array = data["grass"]
	var feat: PackedInt32Array = data["feat"]
	var fax: PackedInt32Array = data["fax"]
	var fay: PackedInt32Array = data["fay"]
	var deco_ids: PackedInt32Array = data["deco"]
	for y in h:
		for x in w:
			var n := y * w + x
			var cell := Vector2i(x, y)
			ground.set_cell(cell, 0, Vector2i(grass[n], 0))
			if feat[n] == 1:
				cliff.set_cell(cell, 0, Vector2i(fax[n], fay[n]))
			elif feat[n] == 2:
				path.set_cell(cell, 0, Vector2i(fax[n], fay[n]))
			elif feat[n] == 3:
				water.set_cell(cell, 0, Vector2i(fax[n], fay[n]))
			if deco_ids[n] >= 0:
				deco.set_cell(cell, 0, Vector2i(deco_ids[n] % 51, int(deco_ids[n] / 51)))


func _make_tileset() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	var source := TileSetAtlasSource.new()
	source.texture = TILESET
	source.texture_region_size = Vector2i(TILE, TILE)
	tiles.add_source(source, 0)
	for y in 30:
		for x in 51:
			source.create_tile(Vector2i(x, y))
	return tiles


func _clear_props() -> void:
	for child in $Actors.get_children():
		if child.is_in_group("world_prop"):
			child.free()


func _spawn_props(props: Array) -> void:
	for item in props:
		if item.get("house", false):
			_spawn_house(item)
		else:
			_spawn_prop(item)


func _spawn_prop(item: Dictionary) -> void:
	var tile: Vector2i = item["tile"]
	var region: Rect2 = item["region"]
	var prop := StaticBody2D.new()
	prop.position = Vector2(tile.x * TILE + 8, tile.y * TILE + TILE)
	prop.collision_layer = 1
	prop.collision_mask = 0
	prop.add_to_group("world_prop")
	var atlas := AtlasTexture.new()
	atlas.atlas = TILESET
	atlas.region = region
	var spr := Sprite2D.new()
	spr.texture = atlas
	spr.centered = true
	spr.offset = Vector2(0, -region.size.y * 0.5)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prop.add_child(spr)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = item["body"]
	col.shape = shape
	col.position = Vector2(0, -4)
	prop.add_child(col)
	$Actors.add_child(prop)


func _spawn_house(item: Dictionary) -> void:
	var region: Rect2 = item["region"]
	var src := TILESET.get_image()
	var crop := src.get_region(Rect2i(int(region.position.x), int(region.position.y), int(region.size.x), int(region.size.y)))
	var w := crop.get_width()
	var h := crop.get_height()
	var body_img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var roof_img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var deck_y := 0
	var eave_y := 0
	for y in h:
		for x in w:
			var color := crop.get_pixel(x, y)
			if color.a < 0.05:
				continue
			if _is_roof_pixel(color):
				roof_img.set_pixel(x, y, color)
				eave_y = maxi(eave_y, y)
			else:
				body_img.set_pixel(x, y, color)
				deck_y = maxi(deck_y, y)
	var tile: Vector2i = item["tile"]
	var feet := Vector2(tile.x * TILE + 8, tile.y * TILE + TILE)
	var body := StaticBody2D.new()
	body.position = feet
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("world_prop")
	body.add_child(_house_sprite(body_img, deck_y))
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = item["body"]
	col.shape = shape
	col.position = Vector2(0, -8)
	body.add_child(col)
	$Actors.add_child(body)
	var roof := Node2D.new()
	roof.position = Vector2(feet.x, feet.y - float(deck_y - (eave_y - 6)))
	roof.add_to_group("world_prop")
	roof.add_child(_house_sprite(roof_img, eave_y - 6))
	$Actors.add_child(roof)


func _house_sprite(image: Image, anchor_y: int) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(image)
	spr.centered = true
	spr.offset = Vector2(0, image.get_height() * 0.5 - float(anchor_y))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return spr


func _is_roof_pixel(color: Color) -> bool:
	var r := color.r8
	var g := color.g8
	var b := color.b8
	return g < 52 and b > g + 5 and r > 40 and r < 120


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
