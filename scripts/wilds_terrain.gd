extends RefCounted

# Organic Painted Lands map. seed = map_id. Recipe A–E is a visible fork.
# Height and moisture are masks only. Tiles come from TILESET_brighter.png.

const MAP_ID := 44119
const WIDTH := 60
const HEIGHT := 42

const GRASS := 0
const DIRT := 1
const HIGH := 2
const WATER := 3

const T_HIGH := 0.70
const T_LOW := 0.40
const T_WET := 0.45

var _biome: PackedInt32Array
var _grass: PackedInt32Array
var _feat: PackedInt32Array
var _fax: PackedInt32Array
var _fay: PackedInt32Array
var _deco: PackedInt32Array
var _path: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var recipe := "A"
var spawn := Vector2i(4, 28)
var house := Vector2i(48, 20)
var door := Vector2i(46, 26)
var _plateau_ok := false
var _plat: Array = [0, 0, 0, 0]
var _keep_pond := false
var _use_fence := false
var _use_rise := false
var _second_trunk := false
var _gate := false
var _low_n := 0
var _rise := 0
var _knuckle := 0
var _east_x := 0
var report := ""


func generate() -> Dictionary:
	_rng.seed = MAP_ID
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
	recipe = _pick_recipe()
	_apply_recipe_flags()
	if recipe == "E":
		_mask_high()
		_cellular(HIGH)
		_erode(HIGH)
		_cull_high()
	_mask_pond()
	_cellular(WATER)
	_erode(WATER)
	_cull_pond()
	_open_pond()
	_place_anchors()
	_flatten(spawn.x, spawn.y, 5)
	_flatten(house.x, house.y, 4)
	if not _keep_pond:
		_delete_pond()
	var route := _astar(spawn, door)
	_lay_path(route)
	_autotile_path()
	_force_ends_and_knuckles()
	_flowers()
	if _keep_pond:
		_shore_pond()
		_reeds()
	if recipe == "E" and _plateau_ok:
		_cliff_autotile()
	elif recipe == "E":
		_use_fence = true
	var props := _trees()
	props.append(_house_prop())
	if _use_fence:
		props.append_array(_yard())
	var reached := _reaches(spawn, door)
	var rim_fill := _fill_on_rim()
	report = "wilds map=%d recipe=%s grass=%d dirt=%d high=%d water=%d path=%d props=%d reached=%s rim_fill=%d plateau=%s" % [
		MAP_ID, recipe, _count(GRASS), _count(DIRT), _count(HIGH), _count(WATER),
		_path.size(), props.size(), str(reached), rim_fill, str(_plateau_ok),
	]
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


func _pick_recipe() -> String:
	var n := (MAP_ID * 1103515245 + 12345) & 0x7fffffff
	match n % 5:
		0:
			return "A"
		1:
			return "B"
		2:
			return "C"
		3:
			return "D"
		_:
			return "E"


func _apply_recipe_flags() -> void:
	match recipe:
		"A":
			_keep_pond = true
			_use_fence = true
			_use_rise = true
		"B":
			_keep_pond = false
			_use_fence = false
			_use_rise = false
			_second_trunk = true
		"C":
			_keep_pond = true
			_use_fence = false
			_use_rise = true
		"D":
			_keep_pond = false
			_use_fence = true
			_use_rise = true
			_gate = true
		"E":
			_keep_pond = false
			_use_fence = false
			_use_rise = true
		_:
			_keep_pond = true
			_use_fence = true
			_use_rise = true


func _lawn() -> void:
	var fills := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	for y in HEIGHT:
		for x in WIDTH:
			var g: Vector2i = fills[int(_hash2(x, y) * fills.size()) % fills.size()]
			_biome[_i(x, y)] = GRASS
			_grass[_i(x, y)] = g.x


func _mask_high() -> void:
	for y in HEIGHT:
		for x in WIDTH:
			if _fbm(x * 0.05, y * 0.05) > T_HIGH:
				_biome[_i(x, y)] = HIGH


func _mask_pond() -> void:
	for y in range(2, HEIGHT - 2):
		for x in range(2, WIDTH - 2):
			if _biome[_i(x, y)] == HIGH:
				continue
			var h := _fbm(x * 0.06, y * 0.06)
			var m := _fbm(x * 0.05 + 40.0, y * 0.05 + 20.0)
			if h < T_LOW and m < T_WET:
				_biome[_i(x, y)] = WATER


func _cellular(kind: int) -> void:
	for _p in 3:
		var next := _biome.duplicate()
		for y in range(1, HEIGHT - 1):
			for x in range(1, WIDTH - 1):
				var same := _neighbors8(x, y, kind)
				var i := _i(x, y)
				if _biome[i] == kind and same < 4:
					next[i] = GRASS
				elif _biome[i] == GRASS and same >= 6:
					next[i] = kind
		_biome = next


func _erode(kind: int) -> void:
	for _p in 2:
		var next := _biome.duplicate()
		for y in range(1, HEIGHT - 1):
			for x in range(1, WIDTH - 1):
				var i := _i(x, y)
				if _biome[i] != kind:
					continue
				if _neighbors4(x, y, kind) < 2:
					next[i] = GRASS
		_biome = next


func _cull_pond() -> void:
	var keep := _largest_blob(WATER, 12, true)
	for i in _biome.size():
		if _biome[i] == WATER and not keep.has(i):
			_biome[i] = GRASS


func _cull_high() -> void:
	var rect := _largest_high_rect()
	for i in _biome.size():
		if _biome[i] == HIGH:
			_biome[i] = GRASS
	_plateau_ok = rect[2] >= 4 and rect[3] >= 4
	if not _plateau_ok:
		return
	for y in range(rect[1], rect[1] + rect[3]):
		for x in range(rect[0], rect[0] + rect[2]):
			if x <= 1 or y <= 1 or x >= WIDTH - 2 or y >= HEIGHT - 2:
				_plateau_ok = false
				return
	if not _plateau_ok:
		return
	for y in range(rect[1], rect[1] + rect[3]):
		for x in range(rect[0], rect[0] + rect[2]):
			_biome[_i(x, y)] = HIGH
	_plat = rect


func _largest_high_rect() -> Array:
	var best := [0, 0, 0, 0]
	var best_area := 0
	for y0 in range(1, HEIGHT - 1):
		var run := PackedInt32Array()
		run.resize(WIDTH)
		for x in WIDTH:
			var h := 0
			for y in range(y0, HEIGHT - 1):
				if _biome[_i(x, y)] != HIGH:
					break
				h += 1
			run[x] = h
		for h in range(4, 16):
			var x := 0
			while x < WIDTH:
				if run[x] < h:
					x += 1
					continue
				var x1 := x
				while x1 < WIDTH and run[x1] >= h:
					x1 += 1
				var w := x1 - x
				if w >= 4 and w * h > best_area:
					best_area = w * h
					best = [x, y0, w, h]
				x = x1
	return best


func _largest_blob(kind: int, min_count: int, drop_thin: bool) -> Dictionary:
	var seen := {}
	var best: Dictionary = {}
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			var start := _i(x, y)
			if _biome[start] != kind or seen.has(start):
				continue
			var blob: Dictionary = {}
			var stack: Array[int] = [start]
			seen[start] = true
			var min_x := x
			var max_x := x
			var min_y := y
			var max_y := y
			while stack.size() > 0:
				var i: int = stack.pop_back()
				blob[i] = true
				var cx := i % WIDTH
				var cy := int(i / WIDTH)
				min_x = mini(min_x, cx)
				max_x = maxi(max_x, cx)
				min_y = mini(min_y, cy)
				max_y = maxi(max_y, cy)
				for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var dir: Vector2i = step
					var nx := cx + dir.x
					var ny := cy + dir.y
					if not _inside(nx, ny):
						continue
					var ni := _i(nx, ny)
					if seen.has(ni) or _biome[ni] != kind:
						continue
					seen[ni] = true
					stack.append(ni)
			var thin := max_x - min_x < 2 or max_y - min_y < 2
			if blob.size() < min_count:
				continue
			if drop_thin and thin:
				continue
			if blob.size() == 4:
				continue
			if blob.size() > best.size():
				best = blob
	return best


func _open_pond() -> void:
	_fill_pond_holes()
	var allowed := _biome.duplicate()
	var core := PackedInt32Array()
	core.resize(_biome.size())
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			var i := _i(x, y)
			if _biome[i] != WATER:
				continue
			if _water_run(x, y, 1, 0) >= 6 and _water_run(x, y, 0, 1) >= 6:
				core[i] = WATER
	for _d in 2:
		var grown := core.duplicate()
		for y in range(1, HEIGHT - 1):
			for x in range(1, WIDTH - 1):
				var i := _i(x, y)
				if core[i] == WATER or allowed[i] != WATER:
					continue
				if _core_touch(core, x, y):
					grown[i] = WATER
		core = grown
	for i in _biome.size():
		if allowed[i] == WATER:
			_biome[i] = WATER if core[i] == WATER else GRASS
	_cull_pond()


func _water_run(x: int, y: int, dx: int, dy: int) -> int:
	var n := 1
	var s := 1
	while _water_at(x + dx * s, y + dy * s):
		n += 1
		s += 1
	s = 1
	while _water_at(x - dx * s, y - dy * s):
		n += 1
		s += 1
	return n


func _core_touch(core: PackedInt32Array, x: int, y: int) -> bool:
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var dir: Vector2i = step
		var nx := x + dir.x
		var ny := y + dir.y
		if _inside(nx, ny) and core[_i(nx, ny)] == WATER:
			return true
	return false


func _pond_bounds() -> Array:
	var min_x := WIDTH
	var max_x := 0
	var min_y := HEIGHT
	var max_y := 0
	var n := 0
	for y in HEIGHT:
		for x in WIDTH:
			if _biome[_i(x, y)] != WATER:
				continue
			n += 1
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)
	if n == 0:
		return []
	return [min_x, max_x, min_y, max_y]


func _fill_pond_holes() -> void:
	var seen := {}
	var stack: Array[Vector2i] = []
	for x in WIDTH:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, HEIGHT - 1))
	for y in HEIGHT:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(WIDTH - 1, y))
	while stack.size() > 0:
		var cur: Vector2i = stack.pop_back()
		var k := _key(cur.x, cur.y)
		if seen.has(k) or not _inside(cur.x, cur.y):
			continue
		if _biome[_i(cur.x, cur.y)] == WATER:
			continue
		seen[k] = true
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var dir: Vector2i = step
			stack.append(cur + dir)
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			if _biome[_i(x, y)] == WATER:
				continue
			if seen.has(_key(x, y)):
				continue
			_biome[_i(x, y)] = WATER


func _place_anchors() -> void:
	var rise := 0
	if _use_rise:
		rise = 2 + int(_hash2(7, 11) * 3.0)
	var hx := 44 + int(_hash2(9, 2) * 8.0)
	var hy := 10 + int(_hash2(3, 8) * 6.0)
	if _plateau_ok:
		hx = maxi(hx, int(_plat[0]) + int(_plat[2]) + 3)
		hy = maxi(hy, int(_plat[1]) + 2)
	house = Vector2i(clampi(hx, 36, WIDTH - 8), clampi(hy, 6, 22))
	var door_y := house.y + 4
	if recipe == "C":
		var bounds := _pond_bounds()
		if bounds.size() == 4:
			var north := int(bounds[2]) - 3
			if north >= 8:
				door_y = north
				house = Vector2i(clampi(int(bounds[1]) - 3, 36, WIDTH - 8), maxi(door_y - 4, 4))
			else:
				door_y = int(bounds[3]) + 3
				house = Vector2i(clampi(int(bounds[1]) - 3, 36, WIDTH - 8), door_y - 4)
	spawn = Vector2i(4, door_y + rise)
	if spawn.y > HEIGHT - 4:
		spawn.y = HEIGHT - 4
		door_y = spawn.y - rise
		house.y = maxi(door_y - 4, 6)
	door = Vector2i(house.x, door_y)


func _clearest_row(y0: int, y1: int) -> int:
	var best_y := y0
	var best := -1
	for y in range(y0, y1):
		var run := 0
		for x in range(2, WIDTH - 2):
			if _biome[_i(x, y)] == GRASS and _biome[_i(x, y + 1)] == GRASS:
				run += 1
		if run > best:
			best = run
			best_y = y
	return best_y


func _flatten(cx: int, cy: int, radius: int) -> void:
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if not _inside(x, y):
				continue
			if Vector2(x - cx, y - cy).length() > float(radius):
				continue
			_biome[_i(x, y)] = GRASS
			_feat[_i(x, y)] = 0


func _delete_pond() -> void:
	for i in _biome.size():
		if _biome[i] == WATER:
			_biome[i] = GRASS
			_feat[i] = 0


func _astar(start: Vector2i, goal: Vector2i) -> Array:
	var open: Array[Vector2i] = [start]
	var gscore := {_key(start.x, start.y): 0}
	var came := {}
	var guard := 0
	while open.size() > 0 and guard < WIDTH * HEIGHT:
		guard += 1
		var best_i := 0
		var best_f := 1 << 30
		for i in open.size():
			var p: Vector2i = open[i]
			var f := int(gscore[_key(p.x, p.y)]) + absi(p.x - goal.x) + absi(p.y - goal.y)
			if f < best_f:
				best_f = f
				best_i = i
		var cur: Vector2i = open[best_i]
		open.remove_at(best_i)
		if cur == goal:
			return _rebuild(came, cur)
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var dir: Vector2i = step
			var nxt := cur + dir
			if not _walkable(nxt.x, nxt.y):
				continue
			var nk := _key(nxt.x, nxt.y)
			var ng := int(gscore[_key(cur.x, cur.y)]) + 1
			if gscore.has(nk) and ng >= int(gscore[nk]):
				continue
			came[nk] = cur
			gscore[nk] = ng
			if not open.has(nxt):
				open.append(nxt)
	return []


func _rebuild(came: Dictionary, cur: Vector2i) -> Array:
	var out: Array = [cur]
	var guard := 0
	while came.has(_key(cur.x, cur.y)) and guard < WIDTH * HEIGHT:
		cur = came[_key(cur.x, cur.y)]
		out.append(cur)
		guard += 1
	out.reverse()
	return out


func _walkable(x: int, y: int) -> bool:
	if x < 1 or y < 1 or x >= WIDTH - 1 or y >= HEIGHT - 1:
		return false
	var b := _biome[_i(x, y)]
	return b == GRASS or b == DIRT


func _lay_path(route: Array) -> void:
	var low_n := spawn.y
	var rise := 0
	if _use_rise:
		rise = clampi(low_n - door.y, 2, 4)
	if rise == 1:
		rise = 2
	var knuckle := _knuckle_x(route, rise)
	var east_x := clampi(door.x, knuckle + 6, WIDTH - 4)
	var band_y := low_n if rise == 0 else low_n - rise
	while east_x > knuckle + 6 and not _band_clear(east_x, band_y):
		east_x -= 1
	_low_n = low_n
	_rise = rise
	_knuckle = knuckle
	_east_x = east_x
	if rise == 0:
		_ribbon_h(2, east_x, low_n, true, true)
	else:
		var high_n := low_n - rise
		_ribbon_h(2, knuckle, low_n, true, false)
		_ribbon_v(knuckle - 1, high_n, low_n + 1)
		_ribbon_h(knuckle - 1, east_x, high_n, false, true)
		_stamp_step(knuckle - 1, knuckle, low_n, high_n)
	if _second_trunk:
		_lay_cross_arm(knuckle)
	door = Vector2i(mini(east_x - 1, door.x), low_n if rise == 0 else low_n - rise)


func _band_clear(x: int, y: int) -> bool:
	if not _inside(x, y) or not _inside(x, y + 1):
		return false
	for yy in [y, y + 1]:
		var b := _biome[_i(x, yy)]
		if b == WATER or b == HIGH:
			return false
	return true


func _knuckle_x(route: Array, rise: int) -> int:
	var guess := 24
	for p in route:
		var cell: Vector2i = p
		if cell.y != spawn.y:
			guess = cell.x
			break
	if route.is_empty():
		guess = 18 + int(_hash2(4, 8) * 16.0)
	if rise == 0:
		return clampi(guess, 12, WIDTH - 16)
	return clampi(guess, 12, door.x - 6)


func _ribbon_h(x0: int, x1: int, y: int, west_cap: bool, east_cap: bool) -> void:
	for x in range(x0, x1 + 1):
		_add_path(x, y)
		_add_path(x, y + 1)
	for x in range(x0, x1 + 1):
		if west_cap and x == x0:
			_set_path_tile(x, y, Vector2i(21, 0))
			_set_path_tile(x, y + 1, Vector2i(21, 2))
		elif east_cap and x == x1:
			_set_path_tile(x, y, Vector2i(23, 0))
			_set_path_tile(x, y + 1, Vector2i(23, 2))
		else:
			_set_path_tile(x, y, Vector2i(22, 0))
			_set_path_tile(x, y + 1, Vector2i(22, 2))


func _ribbon_v(x: int, y0: int, y1: int) -> void:
	for y in range(y0, y1):
		_add_path(x, y)
		_add_path(x + 1, y)


func _stamp_step(inner_x: int, outer_x: int, low_n: int, high_n: int) -> void:
	var low_s := low_n + 1
	var high_s := high_n + 1
	for y in range(high_s + 1, low_n):
		_set_path_tile(inner_x, y, Vector2i(21, 1))
		_set_path_tile(outer_x, y, Vector2i(23, 1))
	_set_path_tile(inner_x, low_s, Vector2i(22, 2))
	_set_path_tile(outer_x, low_s, Vector2i(23, 2))
	_set_path_tile(outer_x, low_n, Vector2i(23, 1))
	_set_path_tile(inner_x, low_n, Vector2i(23, 5))
	_set_path_tile(inner_x, high_n, Vector2i(21, 0))
	_set_path_tile(outer_x, high_n, Vector2i(22, 0))
	_set_path_tile(inner_x, high_s, Vector2i(21, 1))
	_set_path_tile(outer_x, high_s, Vector2i(21, 3))


func _lay_cross_arm(kx: int) -> void:
	var top := 4
	var hy := spawn.y
	for y in range(top, hy):
		_add_path(kx - 1, y)
		_add_path(kx, y)
	for y in range(top + 1, hy):
		_set_path_tile(kx - 1, y, Vector2i(21, 1))
		_set_path_tile(kx, y, Vector2i(23, 1))
	_set_path_tile(kx - 1, top, Vector2i(21, 0))
	_set_path_tile(kx, top, Vector2i(23, 0))
	_set_path_tile(kx - 1, hy, Vector2i(23, 5))
	_set_path_tile(kx, hy, Vector2i(21, 5))


func _add_path(x: int, y: int) -> void:
	if not _inside(x, y):
		return
	_path[_key(x, y)] = true
	var i := _i(x, y)
	_biome[i] = DIRT
	_feat[i] = 2


func _set_path_tile(x: int, y: int, tile: Vector2i) -> void:
	if not _inside(x, y):
		return
	_add_path(x, y)
	var i := _i(x, y)
	_fax[i] = tile.x
	_fay[i] = tile.y


func _autotile_path() -> void:
	for key in _path.keys():
		var x := int(key) % WIDTH
		var y := int(int(key) / WIDTH)
		var tile := _path_gid(x, y)
		var i := _i(x, y)
		_fax[i] = tile.x
		_fay[i] = tile.y


func _path_gid(x: int, y: int) -> Vector2i:
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
			return Vector2i(22, 2)
		1:
			return Vector2i(22, 0)
		_:
			return Vector2i(22, 0)


func _force_ends_and_knuckles() -> void:
	# Autotile paints the inner knuckle as fill. Stamp caps and bites again.
	if _rise == 0:
		_ribbon_h(2, _east_x, _low_n, true, true)
		if _second_trunk:
			_lay_cross_arm(_knuckle)
		return
	var high_n := _low_n - _rise
	_ribbon_h(2, _knuckle, _low_n, true, false)
	_ribbon_h(_knuckle - 1, _east_x, high_n, false, true)
	_stamp_step(_knuckle - 1, _knuckle, _low_n, high_n)
	if _second_trunk:
		_lay_cross_arm(_knuckle)


func _shore_pond() -> void:
	for y in HEIGHT:
		for x in WIDTH:
			if _biome[_i(x, y)] != WATER:
				continue
			var n := _water_at(x, y - 1)
			var e := _water_at(x + 1, y)
			var s := _water_at(x, y + 1)
			var w := _water_at(x - 1, y)
			var tile := Vector2i(45, 1)
			if not n and not w:
				tile = Vector2i(44, 0)
			elif not n and not e:
				tile = Vector2i(46, 0)
			elif not s and not w:
				tile = Vector2i(44, 2)
			elif not s and not e:
				tile = Vector2i(46, 2)
			elif not n:
				tile = Vector2i(45, 0)
			elif not s:
				tile = Vector2i(45, 2)
			elif not w:
				tile = Vector2i(44, 1)
			elif not e:
				tile = Vector2i(46, 1)
			var i := _i(x, y)
			_feat[i] = 3
			_fax[i] = tile.x
			_fay[i] = tile.y


func _water_at(x: int, y: int) -> bool:
	return _inside(x, y) and _biome[_i(x, y)] == WATER


func _reeds() -> void:
	var placed := 0
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			if placed >= 3:
				return
			if _biome[_i(x, y)] != WATER:
				continue
			if _water_at(x, y + 1):
				continue
			if _hash2(x, y + 6) > 0.35:
				continue
			_deco[_i(x, y)] = 47 + 5 * 51
			placed += 1


func _cliff_autotile() -> void:
	for y in HEIGHT:
		for x in WIDTH:
			if _biome[_i(x, y)] != HIGH:
				continue
			var s := _inside(x, y + 1) and _biome[_i(x, y + 1)] == HIGH
			var w := _inside(x - 1, y) and _biome[_i(x - 1, y)] == HIGH
			var e := _inside(x + 1, y) and _biome[_i(x + 1, y)] == HIGH
			var tile := Vector2i(5, 13)
			if not s and not w:
				tile = Vector2i(4, 15)
			elif not s and not e:
				tile = Vector2i(6, 15)
			elif not s:
				tile = Vector2i(5, 15)
			var i := _i(x, y)
			_feat[i] = 1
			_fax[i] = tile.x
			_fay[i] = tile.y


func _house_prop() -> Dictionary:
	return {"tile": house, "region": Rect2(630, 241, 92, 76), "body": Vector2(60, 14), "house": true}


func _yard() -> Array:
	var props: Array = []
	var left_x := house.x - 5
	var right_x := house.x + 5
	var top_y := house.y - 4
	var bottom_y := house.y + 4
	var rails := [Vector2i(30, 24), Vector2i(30, 25), Vector2i(30, 27)]
	props.append(_fence_piece(left_x, top_y, Vector2i(29, 24)))
	props.append(_fence_piece(right_x, top_y, Vector2i(31, 25)))
	props.append(_fence_piece(left_x, bottom_y, Vector2i(29, 27)))
	props.append(_fence_piece(right_x, bottom_y, Vector2i(31, 27)))
	for x in range(left_x + 1, right_x):
		props.append(_fence_piece(x, top_y, rails[posmod(x, rails.size())]))
		if _gate and (x == door.x or x == door.x + 1):
			continue
		props.append(_fence_piece(x, bottom_y, rails[posmod(x + 1, rails.size())]))
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


func _trees() -> Array:
	var regions := [
		Rect2(464, 180, 64, 75),
		Rect2(530, 181, 77, 87),
		Rect2(464, 292, 64, 75),
		Rect2(530, 293, 77, 87),
	]
	var props: Array = []
	var spots := _poisson(6.0, 36, 5)
	for i in spots.size():
		props.append({"tile": spots[i], "region": regions[i % regions.size()], "body": Vector2(14, 8)})
	return props


func _poisson(min_dist: float, budget: int, limit: int) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	for _n in budget:
		if pts.size() >= limit:
			break
		var x := _rng.randi_range(3, WIDTH - 4)
		var y := _rng.randi_range(3, HEIGHT - 4)
		if _biome[_i(x, y)] != GRASS:
			continue
		if absi(x - house.x) <= 7 and absi(y - house.y) <= 7:
			continue
		if absi(x - spawn.x) <= 4 and absi(y - spawn.y) <= 3:
			continue
		var ok := true
		for p in pts:
			if Vector2(p).distance_to(Vector2(x, y)) < min_dist:
				ok = false
				break
		if ok:
			pts.append(Vector2i(x, y))
	return pts


func _scatter_later() -> void:
	pass


func _flowers() -> void:
	var flowers := [Vector2i(8, 2), Vector2i(9, 2), Vector2i(8, 3), Vector2i(9, 3), Vector2i(10, 3), Vector2i(9, 5)]
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			if _biome[_i(x, y)] != GRASS:
				continue
			if _hash2(x + 5, y + 9) > 0.08:
				continue
			var flower: Vector2i = flowers[int(_hash2(x, y + 4) * flowers.size()) % flowers.size()]
			_deco[_i(x, y)] = flower.x + flower.y * 51


func _reaches(start: Vector2i, goal: Vector2i) -> bool:
	var seen := {_key(start.x, start.y): true}
	var stack: Array[Vector2i] = [start]
	while stack.size() > 0:
		var cur: Vector2i = stack.pop_back()
		if absi(cur.x - goal.x) <= 1 and absi(cur.y - goal.y) <= 1:
			return true
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var dir: Vector2i = step
			var nxt := cur + dir
			if not _inside(nxt.x, nxt.y):
				continue
			var k := _key(nxt.x, nxt.y)
			if seen.has(k):
				continue
			var b := _biome[_i(nxt.x, nxt.y)]
			if b != GRASS and b != DIRT:
				continue
			seen[k] = true
			stack.append(nxt)
	return false


func _fill_on_rim() -> int:
	var n := 0
	for key in _path.keys():
		var x := int(key) % WIDTH
		var y := int(int(key) / WIDTH)
		var i := _i(x, y)
		if _fax[i] != 22 or _fay[i] != 1:
			continue
		var neighbors := 0
		if _path.has(_key(x, y - 1)):
			neighbors += 1
		if _path.has(_key(x + 1, y)):
			neighbors += 1
		if _path.has(_key(x, y + 1)):
			neighbors += 1
		if _path.has(_key(x - 1, y)):
			neighbors += 1
		if neighbors < 4:
			n += 1
	return n


func _count(kind: int) -> int:
	var n := 0
	for b in _biome:
		if b == kind:
			n += 1
	return n


func _neighbors8(x: int, y: int, kind: int) -> int:
	var n := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if _inside(x + dx, y + dy) and _biome[_i(x + dx, y + dy)] == kind:
				n += 1
	return n


func _neighbors4(x: int, y: int, kind: int) -> int:
	var n := 0
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var dir: Vector2i = step
		if _inside(x + dir.x, y + dir.y) and _biome[_i(x + dir.x, y + dir.y)] == kind:
			n += 1
	return n


func _fbm(x: float, y: float) -> float:
	var sum := 0.0
	var amp := 0.5
	var freq := 1.0
	for _o in 4:
		sum += amp * _value_noise(x * freq, y * freq)
		freq *= 2.0
		amp *= 0.5
	return sum


func _value_noise(x: float, y: float) -> float:
	var x0 := int(floor(x))
	var y0 := int(floor(y))
	var tx := x - float(x0)
	var ty := y - float(y0)
	var sx := tx * tx * (3.0 - 2.0 * tx)
	var sy := ty * ty * (3.0 - 2.0 * ty)
	var v00 := _hash2(x0, y0)
	var v10 := _hash2(x0 + 1, y0)
	var v01 := _hash2(x0, y0 + 1)
	var v11 := _hash2(x0 + 1, y0 + 1)
	return lerpf(lerpf(v00, v10, sx), lerpf(v01, v11, sx), sy)


func _hash2(x: int, y: int) -> float:
	var n := (x * 374761393) ^ (y * 668265263) ^ MAP_ID
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0


func _key(x: int, y: int) -> int:
	return y * WIDTH + x


func _i(x: int, y: int) -> int:
	return y * WIDTH + x


func _inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < WIDTH and y < HEIGHT
