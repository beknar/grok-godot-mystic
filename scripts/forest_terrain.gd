extends RefCounted

# TILESET_brighter.png. Lawn is the flat grass already in use.
# Path uses the rounded sand set. Pond is the 5×3 shore strip.
# Yards use the fence kit. No cliff faces on this map.

const SEED := 91003
const WIDTH := 64
const HEIGHT := 42

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
var _rng := RandomNumberGenerator.new()
var _seed := SEED
var spawn := Vector2i(30, 24)
var house := Vector2i(42, 24)
var report := ""


func generate() -> Dictionary:
	_rng.seed = _seed
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
	spawn = Vector2i(28, 24)
	house = Vector2i(spawn.x + 10, spawn.y - 1)
	var path_len := _lay_path()
	var water_n := _lay_pond()
	_scatter_deco()
	var props := _trees()
	props.append(_house_prop())
	props.append_array(_fence())
	report = _verify(path_len, water_n, props.size())
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
			var i := _i(x, y)
			_biome[i] = GRASS
			_grass[i] = g.x


func _lay_path() -> int:
	# This sheet's rounded dirt pieces connect east-west. A vertical step opens a gap,
	# so the ribbon stays one tile tall and shifts only by swapping to the south edge
	# tile on a straight, which still reads as one path.
	var y := house.y + 5
	var pts: Array[Vector2i] = []
	for x in range(2, house.x + 1):
		pts.append(Vector2i(x, y))
	for p in pts:
		_path[_key(p.x, p.y)] = true
	_widen_straights(pts)
	_trim_to_centerline(pts)
	for key in _path.keys():
		var xy := _from_key(int(key))
		_biome[_i(xy.x, xy.y)] = DIRT
		var tile := _path_gid(xy.x, xy.y)
		var i := _i(xy.x, xy.y)
		_feat[i] = 2
		_fax[i] = tile.x
		_fay[i] = tile.y
	if pts.size() >= 4:
		# End columns are two cells tall, same x. No cap sitting beside the stack.
		_set_path_tile(pts[0], Vector2i(21, 0))
		_set_path_tile(Vector2i(pts[0].x, pts[0].y + 1), Vector2i(21, 2))
		_set_path_tile(pts[pts.size() - 1], Vector2i(23, 0))
		_set_path_tile(Vector2i(pts[pts.size() - 1].x, pts[pts.size() - 1].y + 1), Vector2i(23, 2))
	return _path.size()


func _trim_to_centerline(pts: Array[Vector2i]) -> void:
	if pts.is_empty():
		return
	var min_x := pts[0].x
	var max_x := pts[pts.size() - 1].x
	var y := pts[0].y
	var drop: Array[int] = []
	for key in _path.keys():
		var xy := _from_key(int(key))
		if xy.x < min_x or xy.x > max_x or xy.y < y or xy.y > y + 1:
			drop.append(int(key))
	for key in drop:
		_path.erase(key)


func _set_path_tile(p: Vector2i, tile: Vector2i) -> void:
	var i := _i(p.x, p.y)
	_feat[i] = 2
	_fax[i] = tile.x
	_fay[i] = tile.y


func _widen_straights(pts: Array[Vector2i]) -> void:
	var run: Array[Vector2i] = []
	for p in pts:
		if run.is_empty() or (p.y == run[-1].y and p.x == run[-1].x + 1):
			run.append(p)
			continue
		_widen_run(run)
		run = [p]
	_widen_run(run)


func _widen_run(run: Array[Vector2i]) -> void:
	if run.size() < 4:
		return
	# South row matches the north row, including the end columns.
	for i in range(0, run.size()):
		var p: Vector2i = run[i]
		if _path.has(_key(p.x, p.y - 1)) or _path.has(_key(p.x, p.y + 1)):
			continue
		var below := Vector2i(p.x, p.y + 1)
		if _inside(below.x, below.y):
			_path[_key(below.x, below.y)] = true


func _path_gid(x: int, y: int) -> Vector2i:
	# Quadrant reading of the sand set. Fill (22,1) is interior only.
	# Caps are the mostly-grass tiles with dirt in one quadrant.
	var n := _path.has(_key(x, y - 1))
	var e := _path.has(_key(x + 1, y))
	var s := _path.has(_key(x, y + 1))
	var w := _path.has(_key(x - 1, y))
	var mask := (1 if n else 0) | (2 if e else 0) | (4 if s else 0) | (8 if w else 0)
	match mask:
		15:
			return Vector2i(22, 1)
		14:
			return Vector2i(22, 0)
		11:
			return Vector2i(22, 2)
		7:
			return Vector2i(21, 1)
		13:
			return Vector2i(23, 1)
		10:
			return Vector2i(22, 0)
		5:
			return Vector2i(21, 1)
		6:
			return Vector2i(23, 5)
		12:
			return Vector2i(21, 5)
		3:
			return Vector2i(23, 3)
		9:
			return Vector2i(21, 3)
		2:
			return Vector2i(21, 0)
		8:
			return Vector2i(23, 0)
		4:
			return Vector2i(22, 5)
		1:
			return Vector2i(22, 2)
		_:
			return Vector2i(21, 0)


func _lay_pond() -> int:
	var origin := Vector2i(spawn.x - 14, spawn.y - 8)
	var cols := [44, 45, 45, 45, 46]
	var rows := [0, 1, 2]
	var n := 0
	for dy in rows.size():
		for dx in cols.size():
			var x := origin.x + dx
			var y := origin.y + dy
			if not _inside(x, y):
				continue
			if _biome[_i(x, y)] == DIRT:
				continue
			_biome[_i(x, y)] = WATER
			var i := _i(x, y)
			_feat[i] = 3
			_fax[i] = cols[dx]
			_fay[i] = rows[dy]
			n += 1
	return n


func _scatter_deco() -> void:
	var flowers := [Vector2i(1, 1), Vector2i(7, 1), Vector2i(8, 3), Vector2i(9, 3), Vector2i(10, 3)]
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			if _biome[_i(x, y)] != GRASS:
				continue
			if _hash2(x + 3, y + 11) > 0.08:
				continue
			if (x * 3 + y) % 5 == 0:
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
	var spots := _poisson(6.0, 40, 5)
	for i in spots.size():
		props.append({"tile": spots[i], "region": regions[i % regions.size()], "body": Vector2(14, 8)})
	return props


func _house_prop() -> Dictionary:
	return {"tile": house, "region": Rect2(630, 241, 92, 76), "body": Vector2(60, 14), "house": true}


func _fence() -> Array:
	var props: Array = []
	var rails := [Vector2i(30, 25), Vector2i(32, 25), Vector2i(30, 27)]
	var top_y := house.y - 6
	var left_x := house.x - 4
	var right_x := house.x + 4
	props.append(_fence_piece(left_x, top_y, Vector2i(40, 18)))
	props.append(_fence_piece(right_x, top_y, Vector2i(41, 18)))
	for x in range(left_x + 1, right_x):
		props.append(_fence_piece(x, top_y, rails[(x - left_x) % rails.size()]))
	for y in range(top_y + 1, top_y + 4):
		props.append(_fence_piece(left_x, y, Vector2i(30, 26)))
		props.append(_fence_piece(right_x, y, Vector2i(31, 26)))
	return props


func _fence_piece(x: int, y: int, gid: Vector2i) -> Dictionary:
	return {
		"tile": Vector2i(x, y),
		"region": Rect2(gid.x * 16, gid.y * 16, 16, 16),
		"body": Vector2(14, 8),
	}


func _poisson(min_dist: float, budget: int, limit: int) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	for _n in budget:
		if pts.size() >= limit:
			break
		var x := _rng.randi_range(3, WIDTH - 4)
		var y := _rng.randi_range(3, HEIGHT - 4)
		if _biome[_i(x, y)] != GRASS:
			continue
		if absi(x - spawn.x) <= 4 and absi(y - spawn.y) <= 3:
			continue
		if absi(x - house.x) <= 3 and absi(y - house.y) <= 3:
			continue
		var ok := true
		for p in pts:
			if Vector2(p).distance_to(Vector2(x, y)) < min_dist:
				ok = false
				break
		if ok:
			pts.append(Vector2i(x, y))
	return pts


func _verify(path_len: int, water_n: int, prop_count: int) -> String:
	var grass := 0
	var dirt := 0
	var water := 0
	var bad := 0
	for i in _biome.size():
		if _biome[i] == GRASS:
			grass += 1
		elif _biome[i] == DIRT:
			dirt += 1
		elif _biome[i] == WATER:
			water += 1
		if _feat[i] != 0 and (_fax[i] < 0 or _fay[i] < 0 or _fax[i] > 50 or _fay[i] > 29):
			bad += 1
	return "forest seed=%d grass=%d dirt=%d water=%d path=%d pond=%d props=%d bad_gids=%d cliffs=0" % [
		_seed, grass, dirt, water, path_len, water_n, prop_count, bad,
	]


func _key(x: int, y: int) -> int:
	return y * WIDTH + x


func _from_key(key: int) -> Vector2i:
	return Vector2i(key % WIDTH, int(key / WIDTH))


func _inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < WIDTH and y < HEIGHT


func _i(x: int, y: int) -> int:
	return y * WIDTH + x


func _hash2(x: int, y: int) -> float:
	var n := (x * 374761393) ^ (y * 668265263) ^ _seed
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0
