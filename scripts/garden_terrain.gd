extends RefCounted

# Recipe D on TILESET_brighter.png. Flat lawn, one house, a 2-wide
# path with a 4-tile riser, and a closed fence with a 2-tile gate.
# No pond and no cliffs.

const SEED := 77241
const WIDTH := 56
const HEIGHT := 40

const GRASS := 0
const DIRT := 1

var _biome: PackedInt32Array
var _grass: PackedInt32Array
var _feat: PackedInt32Array
var _fax: PackedInt32Array
var _fay: PackedInt32Array
var _deco: PackedInt32Array
var _path: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var spawn := Vector2i(8, 26)
var house := Vector2i(44, 18)
var report := ""


func generate() -> Dictionary:
	_rng.seed = SEED
	var n := WIDTH * HEIGHT
	_biome = PackedInt32Array()
	_biome.resize(n)
	_grass = PackedInt32Array()
	_grass.resize(n)
	_feat = PackedInt32Array()
	_feat.resize(n)
	_fax = PackedInt32Array()
	_fax.resize(n)
	_fay = PackedInt32Array()
	_fay.resize(n)
	_deco = PackedInt32Array()
	_deco.resize(n)
	_deco.fill(-1)
	_path.clear()
	_lawn()
	var path_len := _lay_path()
	_scatter_deco()
	var props := _trees()
	props.append(_house_prop())
	props.append_array(_fence())
	report = _verify(path_len, props.size())
	return {
		"width": WIDTH,
		"height": HEIGHT,
		"grass": _grass,
		"feat": _feat,
		"fax": _fax,
		"fay": _fay,
		"deco": _deco,
		"biome": _biome,
		"spawn": spawn,
		"props": props,
		"report": report,
	}


func _lawn() -> void:
	var fills := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	for y in HEIGHT:
		for x in WIDTH:
			var g: Vector2i = fills[int(_hash2(x, y) * fills.size()) % fills.size()]
			_biome[_i(x, y)] = GRASS
			_grass[_i(x, y)] = g.x


func _lay_path() -> int:
	# Long east, four tiles north through the gate, then east to the yard.
	var low_n := 26
	var low_s := 27
	var high_n := 22
	var high_s := 23
	var west_x := 4
	var east_x := 40
	var inner_x := 34
	var outer_x := 35
	for x in range(west_x, outer_x + 1):
		_add_path(x, low_n)
		_add_path(x, low_s)
	for y in range(high_n, low_n):
		_add_path(inner_x, y)
		_add_path(outer_x, y)
	for x in range(outer_x, east_x + 1):
		_add_path(x, high_n)
		_add_path(x, high_s)
	for x in range(west_x + 1, outer_x):
		_set_path_tile(Vector2i(x, low_n), Vector2i(22, 0))
		_set_path_tile(Vector2i(x, low_s), Vector2i(22, 2))
	for y in [24, 25]:
		_set_path_tile(Vector2i(inner_x, y), Vector2i(21, 1))
		_set_path_tile(Vector2i(outer_x, y), Vector2i(23, 1))
	for x in range(outer_x + 1, east_x):
		_set_path_tile(Vector2i(x, high_n), Vector2i(22, 0))
		_set_path_tile(Vector2i(x, high_s), Vector2i(22, 2))
	_set_path_tile(Vector2i(west_x, low_n), Vector2i(21, 0))
	_set_path_tile(Vector2i(west_x, low_s), Vector2i(21, 2))
	_set_path_tile(Vector2i(east_x, high_n), Vector2i(23, 0))
	_set_path_tile(Vector2i(east_x, high_s), Vector2i(23, 2))
	# Lower knuckle: east then north.
	_set_path_tile(Vector2i(inner_x, low_s), Vector2i(22, 2))
	_set_path_tile(Vector2i(outer_x, low_s), Vector2i(23, 2))
	_set_path_tile(Vector2i(outer_x, low_n), Vector2i(23, 1))
	_set_path_tile(Vector2i(inner_x, low_n), Vector2i(23, 5))
	# Upper knuckle: north then east.
	_set_path_tile(Vector2i(inner_x, high_n), Vector2i(21, 0))
	_set_path_tile(Vector2i(outer_x, high_n), Vector2i(22, 0))
	_set_path_tile(Vector2i(inner_x, high_s), Vector2i(21, 1))
	_set_path_tile(Vector2i(outer_x, high_s), Vector2i(21, 3))
	return _path.size()


func _add_path(x: int, y: int) -> void:
	_path[_key(x, y)] = true
	_biome[_i(x, y)] = DIRT


func _set_path_tile(p: Vector2i, tile: Vector2i) -> void:
	var i := _i(p.x, p.y)
	_feat[i] = 2
	_fax[i] = tile.x
	_fay[i] = tile.y


func _scatter_deco() -> void:
	var flowers := [Vector2i(1, 1), Vector2i(7, 1), Vector2i(8, 3), Vector2i(9, 3), Vector2i(10, 3)]
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			if _biome[_i(x, y)] != GRASS:
				continue
			if _on_fence_line(x, y):
				continue
			if _hash2(x + 5, y + 9) > 0.08:
				continue
			var flower: Vector2i = flowers[int(_hash2(x, y + 4) * flowers.size()) % flowers.size()]
			_deco[_i(x, y)] = flower.x + flower.y * 51


func _trees() -> Array:
	var regions := [
		Rect2(464, 180, 64, 75),
		Rect2(530, 181, 77, 87),
		Rect2(464, 292, 64, 75),
		Rect2(530, 293, 77, 87),
	]
	var props: Array = []
	var spots := _poisson(6.0, 48, 5)
	for i in spots.size():
		props.append({"tile": spots[i], "region": regions[i % regions.size()], "body": Vector2(14, 8)})
	return props


func _house_prop() -> Dictionary:
	return {"tile": house, "region": Rect2(630, 241, 92, 76), "body": Vector2(60, 14), "house": true}


func _fence() -> Array:
	var props: Array = []
	var left_x := 30
	var right_x := 48
	var top_y := 14
	var bottom_y := 24
	var rails := [Vector2i(30, 24), Vector2i(30, 25), Vector2i(30, 27)]
	props.append(_fence_piece(left_x, top_y, Vector2i(29, 24)))
	props.append(_fence_piece(right_x, top_y, Vector2i(31, 25)))
	props.append(_fence_piece(left_x, bottom_y, Vector2i(29, 27)))
	props.append(_fence_piece(right_x, bottom_y, Vector2i(31, 27)))
	for x in range(left_x + 1, right_x):
		props.append(_fence_piece(x, top_y, rails[x % rails.size()]))
		if x == 34 or x == 35:
			continue
		props.append(_fence_piece(x, bottom_y, rails[(x + 1) % rails.size()]))
	for y in range(top_y + 1, bottom_y):
		props.append(_fence_piece(left_x, y, Vector2i(29, 26)))
		props.append(_fence_piece(right_x, y, Vector2i(31, 26)))
	return props


func _fence_piece(x: int, y: int, gid: Vector2i) -> Dictionary:
	return {
		"tile": Vector2i(x, y),
		"region": Rect2(gid.x * 16, gid.y * 16, 16, 16),
		"body": Vector2(14, 8),
	}


func _on_fence_line(x: int, y: int) -> bool:
	var left_x := 30
	var right_x := 48
	var top_y := 14
	var bottom_y := 24
	if y == top_y and x >= left_x and x <= right_x:
		return true
	if y == bottom_y and x >= left_x and x <= right_x and x != 34 and x != 35:
		return true
	if (x == left_x or x == right_x) and y >= top_y and y <= bottom_y:
		return true
	return false


func _poisson(min_dist: float, budget: int, limit: int) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	for _n in budget:
		if pts.size() >= limit:
			break
		var x := _rng.randi_range(3, WIDTH - 4)
		var y := _rng.randi_range(3, HEIGHT - 4)
		if _biome[_i(x, y)] != GRASS:
			continue
		# Tree sprites stand above their feet, so keep them clear of the yard.
		if x >= 26 and x <= 52 and y >= 8 and y <= 32:
			continue
		if absi(x - spawn.x) <= 4 and absi(y - spawn.y) <= 3:
			continue
		if absi(x - house.x) <= 4 and absi(y - house.y) <= 4:
			continue
		var ok := true
		for p in pts:
			if Vector2(p).distance_to(Vector2(x, y)) < min_dist:
				ok = false
				break
		if ok:
			pts.append(Vector2i(x, y))
	return pts


func _verify(path_len: int, prop_count: int) -> String:
	var grass := 0
	var dirt := 0
	var bad := 0
	var fill := 0
	for i in _biome.size():
		if _biome[i] == GRASS:
			grass += 1
		elif _biome[i] == DIRT:
			dirt += 1
		if _feat[i] == 2 and _fax[i] == 22 and _fay[i] == 1:
			fill += 1
		if _feat[i] != 0 and (_fax[i] < 0 or _fay[i] < 0 or _fax[i] > 50 or _fay[i] > 29):
			bad += 1
	return "garden seed=%d grass=%d dirt=%d path=%d props=%d fill=%d bad_gids=%d cliffs=0 pond=0" % [
		SEED, grass, dirt, path_len, prop_count, fill, bad,
	]


func _key(x: int, y: int) -> int:
	return y * WIDTH + x


func _i(x: int, y: int) -> int:
	return y * WIDTH + x


func _hash2(x: int, y: int) -> float:
	var n := (x * 374761393) ^ (y * 668265263) ^ SEED
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0
