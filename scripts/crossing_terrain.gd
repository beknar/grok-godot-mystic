extends RefCounted

# Painted Lands crossing. One 2-wide cross, two northeast steps,
# two fenced houses, two rounded dirt patches, and one shore-edged pond.

const SEED := 33017
const WIDTH := 64
const HEIGHT := 48

const GRASS := 0
const DIRT := 1
const WATER := 3

var _biome: PackedInt32Array
var _grass: PackedInt32Array
var _feat: PackedInt32Array
var _fax: PackedInt32Array
var _fay: PackedInt32Array
var _deco: PackedInt32Array
var _path: Dictionary = {}
var _water: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var spawn := Vector2i(12, 22)
var houses := [Vector2i(16, 10), Vector2i(52, 32)]
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
	_water.clear()
	_lawn()
	_lay_cross()
	_lay_step(4, 24, 15, 18, 16)
	_lay_step(36, 56, 47, 40, 38)
	_lay_patch(6, 30, 5, 3)
	_lay_patch(50, 16, 4, 3)
	var water_n := _lay_pond(40, 8, 9, 6)
	_scatter_deco()
	_reeds()
	var props := _trees()
	for h in houses:
		props.append(_house_prop(h))
	props.append_array(_yard(11, 22, 6, 14))
	props.append_array(_yard(46, 58, 26, 36))
	props.append_array(_rocks())
	report = _verify(water_n, props.size())
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


func _lay_cross() -> void:
	var hy := 22
	var hx0 := 4
	var hx1 := 58
	var vx := 28
	var vy0 := 4
	var vy1 := 42
	for x in range(hx0, hx1 + 1):
		_add_path(x, hy)
		_add_path(x, hy + 1)
	for y in range(vy0, vy1 + 1):
		_add_path(vx, y)
		_add_path(vx + 1, y)
	for x in range(hx0 + 1, hx1):
		if x == vx or x == vx + 1:
			continue
		_set_tile(x, hy, Vector2i(22, 0))
		_set_tile(x, hy + 1, Vector2i(22, 2))
	for y in range(vy0 + 1, vy1):
		if y == hy or y == hy + 1:
			continue
		_set_tile(vx, y, Vector2i(21, 1))
		_set_tile(vx + 1, y, Vector2i(23, 1))
	_set_tile(hx0, hy, Vector2i(21, 0))
	_set_tile(hx0, hy + 1, Vector2i(21, 2))
	_set_tile(hx1, hy, Vector2i(23, 0))
	_set_tile(hx1, hy + 1, Vector2i(23, 2))
	_set_tile(vx, vy0, Vector2i(21, 0))
	_set_tile(vx + 1, vy0, Vector2i(23, 0))
	_set_tile(vx, vy1, Vector2i(21, 2))
	_set_tile(vx + 1, vy1, Vector2i(23, 2))
	# Center of the cross: one grass bite per quadrant, not fill.
	_set_tile(vx, hy, Vector2i(23, 5))
	_set_tile(vx + 1, hy, Vector2i(21, 5))
	_set_tile(vx, hy + 1, Vector2i(23, 3))
	_set_tile(vx + 1, hy + 1, Vector2i(21, 3))


func _lay_step(west_x: int, east_x: int, inner_x: int, low_n: int, high_n: int) -> void:
	var low_s := low_n + 1
	var high_s := high_n + 1
	var outer_x := inner_x + 1
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
		_set_tile(x, low_n, Vector2i(22, 0))
		_set_tile(x, low_s, Vector2i(22, 2))
	for y in range(high_s + 1, low_n):
		_set_tile(inner_x, y, Vector2i(21, 1))
		_set_tile(outer_x, y, Vector2i(23, 1))
	for x in range(outer_x + 1, east_x):
		_set_tile(x, high_n, Vector2i(22, 0))
		_set_tile(x, high_s, Vector2i(22, 2))
	_set_tile(west_x, low_n, Vector2i(21, 0))
	_set_tile(west_x, low_s, Vector2i(21, 2))
	_set_tile(east_x, high_n, Vector2i(23, 0))
	_set_tile(east_x, high_s, Vector2i(23, 2))
	_set_tile(inner_x, low_s, Vector2i(22, 2))
	_set_tile(outer_x, low_s, Vector2i(23, 2))
	_set_tile(outer_x, low_n, Vector2i(23, 1))
	_set_tile(inner_x, low_n, Vector2i(23, 5))
	_set_tile(inner_x, high_n, Vector2i(21, 0))
	_set_tile(outer_x, high_n, Vector2i(22, 0))
	_set_tile(inner_x, high_s, Vector2i(21, 1))
	_set_tile(outer_x, high_s, Vector2i(21, 3))


func _lay_patch(x0: int, y0: int, w: int, h: int) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_biome[_i(x, y)] = DIRT
			var n := y > y0
			var s := y < y0 + h - 1
			var e := x < x0 + w - 1
			var west := x > x0
			var tile := Vector2i(22, 1)
			if not n and not west:
				tile = Vector2i(21, 0)
			elif not n and not e:
				tile = Vector2i(23, 0)
			elif not s and not west:
				tile = Vector2i(21, 2)
			elif not s and not e:
				tile = Vector2i(23, 2)
			elif not n:
				tile = Vector2i(22, 0)
			elif not s:
				tile = Vector2i(22, 2)
			elif not west:
				tile = Vector2i(21, 1)
			elif not e:
				tile = Vector2i(23, 1)
			_set_tile(x, y, tile)


func _lay_pond(x0: int, y0: int, w: int, h: int) -> int:
	var n := 0
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_water[_key(x, y)] = true
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			if _biome[_i(x, y)] == DIRT:
				continue
			_biome[_i(x, y)] = WATER
			var north := _water.has(_key(x, y - 1))
			var south := _water.has(_key(x, y + 1))
			var east := _water.has(_key(x + 1, y))
			var west := _water.has(_key(x - 1, y))
			var tile := Vector2i(45, 1)
			if not north and not west:
				tile = Vector2i(44, 0)
			elif not north and not east:
				tile = Vector2i(46, 0)
			elif not south and not west:
				tile = Vector2i(44, 2)
			elif not south and not east:
				tile = Vector2i(46, 2)
			elif not north:
				tile = Vector2i(45, 0)
			elif not south:
				tile = Vector2i(45, 2)
			elif not west:
				tile = Vector2i(44, 1)
			elif not east:
				tile = Vector2i(46, 1)
			var i := _i(x, y)
			_feat[i] = 3
			_fax[i] = tile.x
			_fay[i] = tile.y
			n += 1
	return n


func _add_path(x: int, y: int) -> void:
	_path[_key(x, y)] = true
	_biome[_i(x, y)] = DIRT


func _set_tile(x: int, y: int, tile: Vector2i) -> void:
	var i := _i(x, y)
	_feat[i] = 2
	_fax[i] = tile.x
	_fay[i] = tile.y


func _scatter_deco() -> void:
	var flowers := [
		Vector2i(8, 2),
		Vector2i(9, 2),
		Vector2i(8, 3),
		Vector2i(9, 3),
		Vector2i(10, 3),
		Vector2i(9, 5),
	]
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			if _biome[_i(x, y)] != GRASS:
				continue
			if _hash2(x + 5, y + 9) > 0.08:
				continue
			var flower: Vector2i = flowers[int(_hash2(x, y + 4) * flowers.size()) % flowers.size()]
			_deco[_i(x, y)] = flower.x + flower.y * 51


func _reeds() -> void:
	# South shore of the pond. Cattails sit on the foam, not in the fill.
	for x in [42, 45, 47]:
		_deco[_i(x, 13)] = 47 + 5 * 51


func _trees() -> Array:
	var regions := [
		Rect2(464, 180, 64, 75),
		Rect2(530, 181, 77, 87),
		Rect2(464, 292, 64, 75),
		Rect2(530, 293, 77, 87),
	]
	var props: Array = []
	var spots := _poisson(6.0, 40, 4)
	for i in spots.size():
		props.append({"tile": spots[i], "region": regions[i % regions.size()], "body": Vector2(14, 8)})
	return props


func _house_prop(tile: Vector2i) -> Dictionary:
	return {"tile": tile, "region": Rect2(630, 241, 92, 76), "body": Vector2(60, 14), "house": true}


func _yard(left_x: int, right_x: int, top_y: int, bottom_y: int) -> Array:
	var props: Array = []
	var rails := [Vector2i(30, 24), Vector2i(30, 25), Vector2i(30, 27)]
	props.append(_fence_piece(left_x, top_y, Vector2i(29, 24)))
	props.append(_fence_piece(right_x, top_y, Vector2i(31, 25)))
	props.append(_fence_piece(left_x, bottom_y, Vector2i(29, 27)))
	props.append(_fence_piece(right_x, bottom_y, Vector2i(31, 27)))
	for x in range(left_x + 1, right_x):
		props.append(_fence_piece(x, top_y, rails[x % rails.size()]))
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


func _rocks() -> Array:
	return [
		{"tile": Vector2i(43, 10), "region": Rect2(768, 96, 32, 16), "body": Vector2(20, 8)},
		{"tile": Vector2i(45, 11), "region": Rect2(784, 112, 16, 16), "body": Vector2(10, 6)},
		{"tile": Vector2i(42, 12), "region": Rect2(784, 128, 16, 16), "body": Vector2(10, 6)},
	]


func _poisson(min_dist: float, budget: int, limit: int) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	for _n in budget:
		if pts.size() >= limit:
			break
		var x := _rng.randi_range(3, WIDTH - 4)
		var y := _rng.randi_range(3, HEIGHT - 4)
		if _biome[_i(x, y)] != GRASS:
			continue
		if _blocked_prop(x, y):
			continue
		var ok := true
		for p in pts:
			if Vector2(p).distance_to(Vector2(x, y)) < min_dist:
				ok = false
				break
		if ok:
			pts.append(Vector2i(x, y))
	return pts


func _blocked_prop(x: int, y: int) -> bool:
	if x >= 8 and x <= 26 and y >= 4 and y <= 20:
		return true
	if x >= 42 and x <= 60 and y >= 24 and y <= 42:
		return true
	if x >= 36 and x <= 52 and y >= 4 and y <= 18:
		return true
	return false


func _verify(water_n: int, prop_count: int) -> String:
	var grass := 0
	var dirt := 0
	var water := 0
	var bad := 0
	var fill_on_end := 0
	for i in _biome.size():
		if _biome[i] == GRASS:
			grass += 1
		elif _biome[i] == DIRT:
			dirt += 1
		elif _biome[i] == WATER:
			water += 1
		if _feat[i] != 0 and (_fax[i] < 0 or _fay[i] < 0 or _fax[i] > 50 or _fay[i] > 29):
			bad += 1
	return "crossing seed=%d grass=%d dirt=%d water=%d pond=%d props=%d bad_gids=%d fill_flag=%d" % [
		SEED, grass, dirt, water, water_n, prop_count, bad, fill_on_end,
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
