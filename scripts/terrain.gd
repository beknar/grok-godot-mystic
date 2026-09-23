extends RefCounted

# Tile-id grid for the clearing. Every atlas coord is a cell in plains.png
# or the single grass.png tile. Nothing here is a painted bitmap.
#
# plains.png is 6 columns by 12 rows of 16px.
# Rows 0-3: dirt on meadow grass, rounded outer corners.
# Rows 4-7: cliff top and south-facing wall.
# Rows 8-11: water, same corner layout as the dirt block shifted down 8 rows.

const DEFAULT_SEED := 21021
var _seed := DEFAULT_SEED
var _with_water := true
const WIDTH := 70
const HEIGHT := 46

const GRASS := 0
const DIRT := 1
const HIGH := 2
const WATER := 3

const SRC_GRASS := 0
const SRC_PLAINS := 1

var _biome: PackedInt32Array
var _src: PackedInt32Array
var _ax: PackedInt32Array
var _ay: PackedInt32Array
var _rng := RandomNumberGenerator.new()
var spawn := Vector2i(WIDTH / 2, HEIGHT / 2)
var shrine := Vector2i(18, 12)
var report := ""


func generate(seed_value: int = -1, with_water: bool = true) -> Dictionary:
	_seed = DEFAULT_SEED if seed_value < 0 else seed_value
	_with_water = with_water
	_rng.seed = _seed
	var n := WIDTH * HEIGHT
	_biome = PackedInt32Array()
	_biome.resize(n)
	_src = PackedInt32Array()
	_src.resize(n)
	_ax = PackedInt32Array()
	_ax.resize(n)
	_ay = PackedInt32Array()
	_ay.resize(n)
	_sample_biomes()
	for _pass in 3:
		_smooth(HIGH, 4, 6)
		if _with_water:
			_smooth(WATER, 4, 6)
	_erode(HIGH, 2)
	_cull_small(HIGH, 40)
	if _with_water:
		_cull_small(WATER, 12)
	_place_arenas()
	_autotile()
	var river_len := _carve_river() if _with_water else 0
	var path := _carve_path()
	_autotile()
	_break_duplicate_fills(DIRT)
	_break_duplicate_fills(HIGH)
	var props := _scatter_props()
	var shrine_props := _shrine_prefab()
	props.append_array(shrine_props)
	report = _verify(path.size(), river_len, props.size())
	return {
		"width": WIDTH,
		"height": HEIGHT,
		"src": _src,
		"ax": _ax,
		"ay": _ay,
		"biome": _biome,
		"spawn": spawn,
		"shrine": shrine,
		"props": props,
		"report": report,
	}


func _sample_biomes() -> void:
	for y in HEIGHT:
		for x in WIDTH:
			var h := _fbm(x * 0.055, y * 0.055)
			var m := _fbm(x * 0.05 + 40.0, y * 0.05 + 20.0)
			var b := GRASS
			if h > 0.64:
				b = HIGH
			elif _with_water and h < 0.36 and m < 0.40:
				b = WATER
			_biome[_i(x, y)] = b


func _smooth(kind: int, die_below: int, born_at: int) -> void:
	var next := _biome.duplicate()
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			var around := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					if _biome[_i(x + dx, y + dy)] == kind:
						around += 1
			var here := _biome[_i(x, y)]
			if here == kind and around < die_below:
				next[_i(x, y)] = GRASS
			elif here == GRASS and around >= born_at:
				next[_i(x, y)] = kind
	_biome = next


func _erode(kind: int, passes: int) -> void:
	for _pass in passes:
		var next := _biome.duplicate()
		for y in range(1, HEIGHT - 1):
			for x in range(1, WIDTH - 1):
				if _biome[_i(x, y)] != kind:
					continue
				var friends := 0
				if _is(x, y - 1, kind):
					friends += 1
				if _is(x + 1, y, kind):
					friends += 1
				if _is(x, y + 1, kind):
					friends += 1
				if _is(x - 1, y, kind):
					friends += 1
				if friends < 2:
					next[_i(x, y)] = GRASS
		_biome = next


func _cull_small(kind: int, minimum: int) -> void:
	var seen := PackedByteArray()
	seen.resize(WIDTH * HEIGHT)
	for y in HEIGHT:
		for x in WIDTH:
			var start := _i(x, y)
			if seen[start] != 0 or _biome[start] != kind:
				continue
			var blob: Array[int] = [start]
			seen[start] = 1
			var head := 0
			while head < blob.size():
				var cur: int = blob[head]
				head += 1
				var xy := _xy(cur)
				for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = xy.x + step.x
					var ny: int = xy.y + step.y
					if not _inside(nx, ny):
						continue
					var ni := _i(nx, ny)
					if seen[ni] != 0 or _biome[ni] != kind:
						continue
					seen[ni] = 1
					blob.append(ni)
			if blob.size() < minimum:
				for idx in blob:
					_biome[idx] = GRASS


func _force_border(kind: int) -> void:
	for x in WIDTH:
		_biome[_i(x, 0)] = kind
		_biome[_i(x, HEIGHT - 1)] = kind
	for y in HEIGHT:
		_biome[_i(0, y)] = kind
		_biome[_i(WIDTH - 1, y)] = kind


func _place_arenas() -> void:
	spawn = Vector2i(WIDTH / 2, int(HEIGHT * 0.62))
	_flatten(spawn, 5)
	shrine = _pick_shrine()
	_flatten(shrine, 4)


func _pick_shrine() -> Vector2i:
	var best := Vector2i(12, 14)
	var best_d := -1.0
	for _try in 40:
		var p := Vector2i(_rng.randi_range(10, WIDTH - 11), _rng.randi_range(8, HEIGHT - 12))
		var d := Vector2(p).distance_to(Vector2(spawn))
		if d > best_d:
			best_d = d
			best = p
	return best


func _flatten(center: Vector2i, radius: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not _inside(x, y):
				continue
			if Vector2(x - center.x, y - center.y).length() <= float(radius):
				_biome[_i(x, y)] = GRASS


func _autotile() -> void:
	for y in HEIGHT:
		for x in WIDTH:
			var b := _biome[_i(x, y)]
			var mask := _mask(x, y, b)
			var atlas := Vector2i.ZERO
			var source := SRC_PLAINS
			match b:
				DIRT:
					atlas = _dirt_atlas(mask, x, y)
				HIGH:
					atlas = _cliff_atlas(mask, x, y)
				WATER:
					atlas = _water_atlas(mask, x, y)
				_:
					source = SRC_GRASS
					atlas = Vector2i.ZERO
			var n := _i(x, y)
			_src[n] = source
			_ax[n] = atlas.x
			_ay[n] = atlas.y


func _mask(x: int, y: int, kind: int) -> int:
	var mask := 0
	if _is(x, y - 1, kind):
		mask |= 1
	if _is(x + 1, y, kind):
		mask |= 2
	if _is(x, y + 1, kind):
		mask |= 4
	if _is(x - 1, y, kind):
		mask |= 8
	# Diagonals decide inner vs outer corners. The sheet paints the round
	# corner into the two-neighbor tile, so a missing diagonal keeps that tile.
	return mask


func _dirt_atlas(mask: int, x: int, y: int) -> Vector2i:
	# Bits: N=1 E=2 S=4 W=8. Corner tiles are the rounded caps.
	match mask:
		6:
			return Vector2i(0, 0) # E+S, top-left round
		12:
			return Vector2i(3, 0) # S+W, top-right round
		3:
			return Vector2i(0, 2) # N+E, bottom-left round
		9:
			return Vector2i(3, 2) # N+W, bottom-right round
		14:
			return Vector2i(2, 0) # north rim
		11:
			return Vector2i(2, 2) # south rim
		7:
			return Vector2i(1, 1) # west rim
		13:
			return Vector2i(3, 1) # east rim
		10:
			return Vector2i(2, 3) # east-west trail
		2:
			return Vector2i(0, 3) # west cap
		8:
			return Vector2i(3, 3) # east cap
		4:
			return Vector2i(2, 0)
		1:
			return Vector2i(2, 2)
		15:
			return _pick(x, y, [Vector2i(2, 1), Vector2i(4, 0), Vector2i(5, 0), Vector2i(4, 1), Vector2i(5, 1)])
		_:
			return Vector2i(2, 1)


func _water_atlas(mask: int, x: int, y: int) -> Vector2i:
	var dirt := _dirt_atlas(mask, x, y)
	# Rows 8-11 repeat the dirt corner set. Fill variants stay on the water block.
	if mask == 15:
		return _pick(x, y, [Vector2i(2, 9), Vector2i(4, 8), Vector2i(5, 8), Vector2i(4, 9)])
	if dirt.y <= 3:
		return Vector2i(dirt.x, dirt.y + 8)
	return Vector2i(2, 9)


func _cliff_atlas(mask: int, x: int, y: int) -> Vector2i:
	var n := (mask & 1) != 0
	var e := (mask & 2) != 0
	var s := (mask & 4) != 0
	var w := (mask & 8) != 0
	# South edge carries the wall, so the plateau reads as higher ground.
	if not s and not w:
		return Vector2i(1, 6)
	if not s and not e:
		return Vector2i(3, 6)
	if not s:
		return Vector2i(2, 6)
	if not n and not w:
		return Vector2i(0, 4)
	if not n and not e:
		return Vector2i(3, 4)
	if not n:
		return Vector2i(2, 4)
	if not w:
		return Vector2i(1, 5)
	if not e:
		return Vector2i(3, 5)
	return _pick(x, y, [Vector2i(2, 5), Vector2i(4, 5), Vector2i(5, 5)])


func _carve_path() -> PackedVector2Array:
	var route := _astar(spawn, shrine)
	var carved: PackedInt32Array = PackedInt32Array()
	for p in route:
		var x := int(p.x)
		var y := int(p.y)
		_stamp_dirt(x, y, carved)
		_stamp_dirt(x + 1, y, carved)
	return route


func _stamp_dirt(x: int, y: int, carved: PackedInt32Array) -> void:
	if not _inside(x, y):
		return
	if _in_arena(x, y, spawn, 3) or _in_arena(x, y, shrine, 2):
		return
	if x == 0 or y == 0 or x == WIDTH - 1 or y == HEIGHT - 1:
		return
	var n := _i(x, y)
	if carved.has(n):
		return
	_biome[n] = DIRT
	carved.append(n)


func _carve_river() -> int:
	var origin := _nearest_water(Vector2i(8, 8))
	if origin.x < 0:
		return 0
	var goal := Vector2i(4, HEIGHT / 2)
	var best := 9999
	for y in range(4, HEIGHT - 4):
		if _biome[_i(4, y)] != HIGH:
			var d := absi(y - origin.y)
			if d < best:
				best = d
				goal = Vector2i(4, y)
	var route := _astar(origin, goal)
	var n := 0
	for p in route:
		var x := int(p.x)
		var y := int(p.y)
		if _in_arena(x, y, spawn, 5) or _in_arena(x, y, shrine, 4):
			continue
		if x <= 1 or y <= 1 or x >= WIDTH - 2 or y >= HEIGHT - 2:
			continue
		_biome[_i(x, y)] = WATER
		n += 1
	return n


func _nearest_water(around: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 999999.0
	for y in HEIGHT:
		for x in WIDTH:
			if _biome[_i(x, y)] != WATER:
				continue
			var d := Vector2(x - around.x, y - around.y).length_squared()
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	return best


func _astar(start: Vector2i, goal: Vector2i) -> PackedVector2Array:
	var start_i := _i(start.x, start.y)
	var goal_i := _i(goal.x, goal.y)
	var open: Array[int] = [start_i]
	var came: PackedInt32Array = PackedInt32Array()
	came.resize(WIDTH * HEIGHT)
	came.fill(-1)
	var gscore: PackedFloat32Array = PackedFloat32Array()
	gscore.resize(WIDTH * HEIGHT)
	gscore.fill(1.0e9)
	gscore[start_i] = 0.0
	var closed: PackedByteArray = PackedByteArray()
	closed.resize(WIDTH * HEIGHT)
	while open.size() > 0:
		var best_n := 0
		var best_f := 1.0e9
		for k in open.size():
			var idx: int = open[k]
			var xy := _xy(idx)
			var f := gscore[idx] + Vector2(xy).distance_to(Vector2(goal))
			if f < best_f:
				best_f = f
				best_n = k
		var cur: int = open[best_n]
		open.remove_at(best_n)
		if cur == goal_i:
			return _rebuild(came, cur)
		if closed[cur] != 0:
			continue
		closed[cur] = 1
		var cxy := _xy(cur)
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cxy.x + step.x
			var ny: int = cxy.y + step.y
			if not _inside(nx, ny):
				continue
			var ni := _i(nx, ny)
			if closed[ni] != 0:
				continue
			var step_cost := 1.0
			var b := _biome[ni]
			if b == HIGH:
				step_cost = 12.0
			elif b == WATER:
				step_cost = 8.0
			var g2 := gscore[cur] + step_cost
			if g2 < gscore[ni]:
				came[ni] = cur
				gscore[ni] = g2
				if not open.has(ni):
					open.append(ni)
	return PackedVector2Array()


func _rebuild(came: PackedInt32Array, cur: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var guard := 0
	while cur != -1 and guard < WIDTH * HEIGHT:
		out.append(Vector2(_xy(cur)))
		cur = came[cur]
		guard += 1
	out.reverse()
	return out


func _scatter_props() -> Array:
	var props: Array = []
	var trees := [
		Rect2(1, 80, 45, 64),
		Rect2(49, 80, 45, 64),
		Rect2(3, 147, 43, 61),
		Rect2(51, 147, 43, 61),
	]
	var spots := _poisson(6.5, 80, func(x: int, y: int) -> bool:
		return _biome[_i(x, y)] == GRASS and not _in_arena(x, y, spawn, 4) and not _in_arena(x, y, shrine, 3)
	)
	for i in spots.size():
		var p: Vector2i = spots[i]
		props.append({
			"tile": p,
			"region": trees[i % trees.size()],
			"body": Vector2(12, 8),
			"blocking": true,
		})
	var tufts := _poisson(3.2, 160, func(x: int, y: int) -> bool:
		return _biome[_i(x, y)] == GRASS and not _in_arena(x, y, spawn, 3) and not _in_arena(x, y, shrine, 2)
	)
	var flowers := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]
	for p2 in tufts:
		var cell: Vector2i = p2
		props.append({
			"tile": cell,
			"deco": _pick(cell.x, cell.y, flowers),
			"blocking": false,
		})
	var rocks := _poisson(8.0, 30, func(x: int, y: int) -> bool:
		return _biome[_i(x, y)] == GRASS and not _in_arena(x, y, spawn, 5) and not _in_arena(x, y, shrine, 3)
	)
	for r in rocks:
		var rock: Vector2i = r
		props.append({
			"tile": rock,
			"deco": Vector2i(2, 1),
			"blocking": true,
		})
	return props


func _shrine_prefab() -> Array:
	return [{
		"tile": shrine + Vector2i(0, -1),
		"region": Rect2(132, 102, 23, 42),
		"body": Vector2(12, 8),
		"blocking": true,
	}, {
		"tile": shrine + Vector2i(-1, -1),
		"deco": Vector2i(1, 1),
		"blocking": false,
	}, {
		"tile": shrine + Vector2i(1, -1),
		"deco": Vector2i(2, 1),
		"blocking": true,
	}, {
		"tile": shrine,
		"deco": Vector2i(0, 2),
		"blocking": false,
	}]


func _poisson(min_dist: float, budget: int, allow: Callable) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	for _n in budget:
		var x := _rng.randi_range(2, WIDTH - 3)
		var y := _rng.randi_range(2, HEIGHT - 3)
		if not allow.call(x, y):
			continue
		var ok := true
		for p in pts:
			if Vector2(p).distance_to(Vector2(x, y)) < min_dist:
				ok = false
				break
		if ok:
			pts.append(Vector2i(x, y))
	return pts


func _verify(path_len: int, river_len: int, prop_count: int) -> String:
	var bad := 0
	var counts := [0, 0, 0, 0]
	for i in _biome.size():
		counts[_biome[i]] += 1
		if not _gid_ok(_src[i], _ax[i], _ay[i]):
			bad += 1
	var reached := _flood_reaches_shrine()
	var dirt_dupes := _duplicate_windows(DIRT)
	var high_dupes := _duplicate_windows(HIGH)
	return "seed=%d %dx%d grass=%d dirt=%d high=%d water=%d path=%d river=%d props=%d bad_gids=%d shrine_reached=%s dirt_3x3_dupes=%d plateau_3x3_dupes=%d" % [
		_seed, WIDTH, HEIGHT, counts[GRASS], counts[DIRT], counts[HIGH], counts[WATER],
		path_len, river_len, prop_count, bad, str(reached), dirt_dupes, high_dupes,
	]


func _gid_ok(source: int, ax: int, ay: int) -> bool:
	if source == SRC_GRASS:
		return ax == 0 and ay == 0
	if source != SRC_PLAINS:
		return false
	if ax < 0 or ay < 0 or ax > 5 or ay > 11:
		return false
	# Red separator cells in the sheet.
	if (ax >= 4 and ay == 3) or (ax >= 4 and ay == 11) or (ax >= 4 and ay == 7 and false):
		return false
	if ax >= 4 and ay == 3:
		return false
	return true


func _flood_reaches_shrine() -> bool:
	var seen := PackedByteArray()
	seen.resize(WIDTH * HEIGHT)
	var q: Array[int] = [_i(spawn.x, spawn.y)]
	seen[q[0]] = 1
	var head := 0
	while head < q.size():
		var cur: int = q[head]
		head += 1
		var xy := _xy(cur)
		if xy == shrine:
			return true
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = xy.x + step.x
			var ny: int = xy.y + step.y
			if not _inside(nx, ny):
				continue
			var ni := _i(nx, ny)
			if seen[ni] != 0:
				continue
			var b := _biome[ni]
			if b != GRASS and b != DIRT:
				continue
			seen[ni] = 1
			q.append(ni)
	return false


func _break_duplicate_fills(kind: int) -> void:
	var seen := {}
	var options := [Vector2i(2, 1), Vector2i(4, 0), Vector2i(5, 1)]
	if kind == HIGH:
		options = [Vector2i(2, 5), Vector2i(4, 5), Vector2i(5, 5)]
	for y in range(1, HEIGHT - 3):
		for x in range(1, WIDTH - 3):
			if not _full_fill_window(x, y, kind):
				continue
			var key := _window_key(x, y)
			if seen.has(key):
				var n := _i(x + 1, y + 1)
				var cur := Vector2i(_ax[n], _ay[n])
				for option in options:
					if option != cur:
						_ax[n] = option.x
						_ay[n] = option.y
						break
				key = _window_key(x, y)
			seen[key] = true


func _full_fill_window(x: int, y: int, kind: int) -> bool:
	for dy in 3:
		for dx in 3:
			var n := _i(x + dx, y + dy)
			if _biome[n] != kind or _mask(x + dx, y + dy, kind) != 15:
				return false
	return true


func _window_key(x: int, y: int) -> String:
	var key := ""
	for dy in 3:
		for dx in 3:
			var n := _i(x + dx, y + dy)
			key += "%d,%d;" % [_ax[n], _ay[n]]
	return key


func _duplicate_windows(kind: int) -> int:
	var seen := {}
	var dupes := 0
	for y in range(1, HEIGHT - 3):
		for x in range(1, WIDTH - 3):
			var all := true
			var key := ""
			for dy in 3:
				for dx in 3:
					var n := _i(x + dx, y + dy)
					if _biome[n] != kind or _mask(x + dx, y + dy, kind) != 15:
						all = false
						break
					key += "%d,%d;" % [_ax[n], _ay[n]]
				if not all:
					break
			if not all:
				continue
			if seen.has(key):
				dupes += 1
			else:
				seen[key] = true
	return dupes


func _pick(x: int, y: int, options: Array) -> Vector2i:
	var i := int(_hash2(x * 3 + 1, y * 5 + 7) * options.size()) % options.size()
	return options[i]


func _in_arena(x: int, y: int, center: Vector2i, radius: int) -> bool:
	return absi(x - center.x) <= radius and absi(y - center.y) <= radius


func _is(x: int, y: int, kind: int) -> bool:
	if not _inside(x, y):
		return false
	return _biome[_i(x, y)] == kind


func _inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < WIDTH and y < HEIGHT


func _i(x: int, y: int) -> int:
	return y * WIDTH + x


func _xy(i: int) -> Vector2i:
	return Vector2i(i % WIDTH, int(i / WIDTH))


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
	var a := lerpf(v00, v10, sx)
	var b := lerpf(v01, v11, sx)
	return lerpf(a, b, sy)


func _hash2(x: int, y: int) -> float:
	var n := (x * 374761393) ^ (y * 668265263) ^ _seed
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0
