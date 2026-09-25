@tool
extends "res://scripts/forest_clearing.gd"

const WildsTerrain := preload("res://scripts/wilds_terrain.gd")


func _generate() -> Dictionary:
	return WildsTerrain.new().generate()


func _ready() -> void:
	super._ready()
	_paint_patch_grass()


func _paint_patch_grass() -> void:
	var path := $Path as TileMapLayer
	var sheet := TILESET.get_image()
	if sheet == null:
		return
	var cells: Array[Vector2i] = []
	for c in path.get_used_cells():
		if _is_patch_atlas(path.get_cell_atlas_coords(c)):
			cells.append(c)
	var blobs := _patch_blobs(cells)
	var holder := Node2D.new()
	holder.name = "Patches"
	add_child(holder)
	move_child(holder, $Ground.get_index() + 1)
	for i in blobs.size():
		var blob: Array = blobs[i]
		var mode_b := (75107 + i) % 2 == 1
		for c in blob:
			var cell: Vector2i = c
			var atlas := path.get_cell_atlas_coords(cell)
			var img := _patch_image(sheet, atlas, mode_b)
			var spr := Sprite2D.new()
			spr.texture = ImageTexture.create_from_image(img)
			spr.centered = false
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.position = Vector2(cell.x * TILE, cell.y * TILE)
			holder.add_child(spr)
			path.erase_cell(cell)


func _is_patch_atlas(atlas: Vector2i) -> bool:
	if atlas.y >= 0 and atlas.y <= 2 and (atlas.x >= 18 and atlas.x <= 20 or atlas.x >= 24 and atlas.x <= 26):
		return true
	if atlas.y == 3 and atlas.x >= 24 and atlas.x <= 27:
		return true
	return false


func _patch_blobs(cells: Array[Vector2i]) -> Array:
	var left := {}
	for c in cells:
		left[_key(c)] = c
	var blobs: Array = []
	for c in cells:
		if not left.has(_key(c)):
			continue
		var blob: Array[Vector2i] = []
		var stack: Array[Vector2i] = [c]
		left.erase(_key(c))
		while stack.size() > 0:
			var cur: Vector2i = stack.pop_back()
			blob.append(cur)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nxt: Vector2i = cur + d
				if left.has(_key(nxt)):
					left.erase(_key(nxt))
					stack.append(nxt)
		blobs.append(blob)
	return blobs


func _patch_image(sheet: Image, atlas: Vector2i, mode_b: bool) -> Image:
	var src := sheet.get_region(Rect2i(atlas.x * TILE, atlas.y * TILE, TILE, TILE))
	var img := src.duplicate()
	var dirt: Array[Vector2i] = []
	for y in TILE:
		for x in TILE:
			if not _is_baked_grass(img.get_pixel(x, y)):
				dirt.append(Vector2i(x, y))
	for y in TILE:
		for x in TILE:
			var px: Color = img.get_pixel(x, y)
			if not _is_baked_grass(px):
				continue
			if not mode_b:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var near := false
			for d in dirt:
				if absi(d.x - x) + absi(d.y - y) <= 3:
					near = true
					break
			var wobble := sin(float(x) * 1.7 + float(y) * 0.9 + float(atlas.x))
			if near and wobble > -0.2:
				continue
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	return img


func _is_baked_grass(px: Color) -> bool:
	if px.a < 0.2:
		return true
	var r := px.r * 255.0
	var g := px.g * 255.0
	var b := px.b * 255.0
	return g > r + 8.0 and g > b + 4.0 and r < 170.0


func _key(c: Vector2i) -> int:
	return c.y * 1000 + c.x
