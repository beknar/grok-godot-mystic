extends RefCounted

# Painted Lands wilds. seed = map_id. recipe = seed % 20.
# Paint is TILESET_brighter.png only. Thresholds are not the Mystic Woods ones.

const MAP_ID := 74015
const WIDTH := 60
const HEIGHT := 42

const GRASS := 0
const DIRT := 1
const HIGH := 2
const WATER := 3

const T_HIGH := 0.72
const T_LOW := 0.34
const T_WET := 0.38

var _biome: PackedInt32Array
var _grass: PackedInt32Array
var _feat: PackedInt32Array
var _fax: PackedInt32Array
var _fay: PackedInt32Array
var _deco: PackedInt32Array
var _path: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _rid := 0
var _has_house := true
var _pond_keep := 0
var _fence := false
var _gate_only := false
var _want_plateau := false
var _plateau_ok := false
var _plat: Array = [0, 0, 0, 0]
var _deco_p := 0.08
var _tree_min := 3
var _tree_max := 6
var _tree_gap := 6.0
var _near_fence := false
var spawn := Vector2i(4, 28)
var house := Vector2i(30, 16)
var door := Vector2i(30, 22)
var _low_n := 28
var _rise := 0
var _knuckle := 24
var _east_x := 46
var _west_x := 3
var report := ""


func generate() -> Dictionary:
	_rng.seed = MAP_ID
	_rid = posmod(MAP_ID, 20)
	_read_recipe()
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
	_mask_pond()
	_cellular(WATER)
	_erode(WATER)
	_cull_kind(WATER, 12, true)
	_open_pond()
	if _want_plateau:
		_mask_high()
		_cellular(HIGH)
		_erode(HIGH)
		_cull_kind(HIGH, 40, false)
		_keep_plateau_rect()
	else:
		_clear_kind(HIGH)
	_place_anchors()
	_flatten(spawn.x, spawn.y, 5)
	if _has_house:
		_flatten(house.x, house.y, 4)
	if _pond_keep == 0:
		_clear_kind(WATER)
	var route := _astar(spawn, door)
	_lay_path(route)
	_autotile_path()
	_force_geometry()
	if _pond_keep > 0:
		_shore_pond()
		_reeds()
	if _want_plateau and _plateau_ok:
		_cliff_autotile()
	_flowers()
	var props := _trees()
	if _has_house:
		props.append(_house_prop())
	if _fence or _gate_only:
		props.append_array(_yard())
	var goal := door if _has_house else Vector2i(_east_x, _low_n)
	var reached := _reaches(spawn, goal)
	report = "wilds map=%d recipe=%d %s water=%d high=%d path=%d props=%d reached=%s rim_fill=%d plateau=%s" % [
		MAP_ID, _rid, _recipe_name(), _count(WATER), _count(HIGH), _path.size(),
		props.size(), str(reached), _fill_on_rim(), str(_plateau_ok),
	]
	return {
		"width": WIDTH, "height": HEIGHT,
		"grass": _grass, "feat": _feat, "fax": _fax, "fay": _fay,
		"deco": _deco, "biome": _biome, "spawn": spawn,
		"props": props, "report": report,
	}


func _recipe_name() -> String:
	match _rid:
		0: return "Pastoral"
		1: return "Crossroads"
		2: return "PondWalk"
		3: return "Garden"
		4: return "Lookout"
		5: return "OpenMeadow"
		6: return "TwinWater"
		7: return "SouthRoad"
		8: return "ShoreSpur"
		9: return "ThreeWay"
		10: return "WestHamlet"
		11: return "EastHamlet"
		12: return "WildLane"
		13: return "Orchard"
		14: return "ShoreHamlet"
		15: return "DoubleLean"
		16: return "BelowRim"
		17: return "GateRoad"
		18: return "SparseWild"
		_: return "Switchback"


func _read_recipe() -> void:
	_has_house = true
	_pond_keep = 0
	_fence = false
	_gate_only = false
	_want_plateau = false
	_deco_p = 0.08
	_tree_min = 3
	_tree_max = 6
	_tree_gap = 6.0
	_near_fence = false
	match _rid:
		0:
			_pond_keep = 1
			_fence = true
		1:
			pass
		2:
			_pond_keep = 1
		3:
			_fence = true
			_gate_only = false
			_near_fence = true
			_deco_p = 0.10
			_tree_max = 5
		4:
			_want_plateau = true
			_tree_max = 5
			_deco_p = 0.06
		5:
			_has_house = false
			_tree_min = 2
			_tree_max = 4
			_deco_p = 0.12
		6:
			_pond_keep = 2
		7:
			pass
		8:
			_pond_keep = 1
		9:
			_deco_p = 0.07
		10, 11:
			_pond_keep = 1
			_fence = true
		12:
			_has_house = false
			_pond_keep = 1
			_tree_min = 4
			_tree_max = 7
			_deco_p = 0.06
		13:
			_tree_min = 8
			_tree_max = 12
			_tree_gap = 4.0
			_deco_p = 0.05
		14:
			_pond_keep = 1
			_fence = true
			_tree_max = 5
			_deco_p = 0.09
		15:
			pass
		16:
			_want_plateau = true
			_tree_max = 5
			_deco_p = 0.06
		17:
			_gate_only = true
		18:
			_has_house = false
			_pond_keep = 1
			_tree_min = 2
			_tree_max = 3
			_tree_gap = 7.0
			_deco_p = 0.04
		_:
			pass


func _lawn() -> void:
	var fills := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	for y in HEIGHT:
		for x in WIDTH:
			var g: Vector2i = fills[int(_hash2(x, y) * fills.size()) % fills.size()]
			_biome[_i(x, y)] = GRASS
			_grass[_i(x, y)] = g.x


func _mask_pond() -> void:
	for y in range(2, HEIGHT - 2):
		for x in range(2, WIDTH - 2):
			var h := _fbm(x * 0.055, y * 0.055)
			var m := _fbm(x * 0.05 + 40.0, y * 0.05 + 20.0)
			if h < T_LOW and m < T_WET:
				_biome[_i(x, y)] = WATER


func _mask_high() -> void:
	for y in range(2, HEIGHT - 2):
		for x in range(2, WIDTH - 2):
			if _biome[_i(x, y)] == WATER:
				continue
			if _fbm(x * 0.055, y * 0.055) > T_HIGH:
				_biome[_i(x, y)] = HIGH


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
				if _biome[i] == kind and _neighbors4(x, y, kind) < 2:
					next[i] = GRASS
		_biome = next


func _cull_kind(kind: int, min_count: int, drop_thin: bool) -> void:
	var blobs := _blobs(kind, min_count, drop_thin)
	var keep: Dictionary = {}
	var limit := 1
	if kind == WATER and _pond_keep >= 2:
		limit = 2
	if kind == WATER and _pond_keep == 0:
		limit = 0
	var used := 0
	for blob in blobs:
		if used >= limit:
			break
		var piece: Dictionary = blob
		for key in piece.keys():
			keep[key] = true
		used += 1
	for i in _biome.size():
		if _biome[i] == kind and not keep.has(i):
			_biome[i] = GRASS


func _blobs(kind: int, min_count: int, drop_thin: bool) -> Array:
	var seen := {}
	var found: Array = []
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
			var thin := max_x - min_x < 2 or max_y - min_y < 2 or blob.size() == 4
			if blob.size() < min_count:
				continue
			if drop_thin and thin:
				continue
			found.append(blob)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.size() > b.size())
	return found


func _open_pond() -> void:
	if _count(WATER) == 0:
		return
	_fill_holes()
	var allowed := _biome.duplicate()
	var core := PackedInt32Array()
	core.resize(_biome.size())
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			if _biome[_i(x, y)] != WATER:
				continue
			if _water_run(x, y, 1, 0) >= 6 and _water_run(x, y, 0, 1) >= 6:
				core[_i(x, y)] = WATER
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
	_cull_kind(WATER, 12, true)


func _fill_holes() -> void:
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
		if not _inside(cur.x, cur.y):
			continue
		var k := _key(cur.x, cur.y)
		if seen.has(k) or _biome[_i(cur.x, cur.y)] == WATER:
			continue
		seen[k] = true
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var dir: Vector2i = step
			stack.append(cur + dir)
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			if _biome[_i(x, y)] != WATER and not seen.has(_key(x, y)):
				_biome[_i(x, y)] = WATER


func _keep_plateau_rect() -> void:
	var best := [0, 0, 0, 0]
	var best_area := 0
	for y0 in range(2, HEIGHT - 2):
		var run := PackedInt32Array()
		run.resize(WIDTH)
		for x in WIDTH:
			var h := 0
			for y in range(y0, HEIGHT - 2):
				if _biome[_i(x, y)] != HIGH:
					break
				h += 1
			run[x] = h
		for h in range(4, 14):
			var x := 0
			while x < WIDTH:
				if run[x] < h:
					x += 1
					continue
				var x1 := x
				while x1 < WIDTH and run[x1] >= h:
					x1 += 1
				var w := x1 - x
				if w >= 4 and w * h > best_area and x > 1 and x + w < WIDTH - 1 and y0 + h < HEIGHT - 1:
					best_area = w * h
					best = [x, y0, w, h]
				x = x1
	for i in _biome.size():
		if _biome[i] == HIGH:
			_biome[i] = GRASS
	_plateau_ok = best[2] >= 4 and best[3] >= 4
	if not _plateau_ok:
		return
	_plat = best
	for y in range(best[1], best[1] + best[3]):
		for x in range(best[0], best[0] + best[2]):
			_biome[_i(x, y)] = HIGH


func _place_anchors() -> void:
	var from_east := _rid == 10
	var row := 26
	if _rid == 7:
		row = int(HEIGHT * 0.72)
	elif _rid == 5:
		row = 20
	if _pond_keep > 0:
		var alt := _row_off_water(row)
		if alt >= 0:
			row = alt
	spawn = Vector2i(WIDTH - 5 if from_east else 4, row)
	if _has_house:
		var hx := 14 if _rid == 10 else 46
		var hy := row - 6
		if _rid == 7:
			hy = 10
		if _plateau_ok:
			hy = int(_plat[1]) + int(_plat[3]) + 3
			hx = int(_plat[0]) + int(_plat[2] / 2)
		house = Vector2i(clampi(hx, 8, WIDTH - 8), clampi(hy, 6, HEIGHT - 10))
		door = Vector2i(house.x, house.y + 4)
	else:
		house = Vector2i(WIDTH / 2, HEIGHT / 2)
		door = Vector2i(WIDTH - 5 if not from_east else 4, row)
	if _rid == 19:
		spawn = Vector2i(4, 28)
		house = Vector2i(24, 14)
		door = Vector2i(24, 18)


func _row_off_water(prefer: int) -> int:
	if _span_clear(prefer, WIDTH - 6):
		return prefer
	for dist in range(1, HEIGHT):
		for y in [prefer - dist, prefer + dist]:
			if _span_clear(y, WIDTH - 6):
				return y
	return -1


func _lay_path(_route: Array) -> void:
	match _rid:
		1:
			_crossroads()
		5:
			_edge_trunk()
		9:
			_three_way()
		15:
			_double_lean()
		19:
			_switchback()
		_:
			_single_lean(_rid == 10)


func _edge_trunk() -> void:
	_low_n = spawn.y
	_west_x = 2
	_east_x = WIDTH - 3
	_rise = 0
	_ribbon_h(_west_x, _east_x, _low_n, true, true)


func _single_lean(from_east: bool) -> void:
	_low_n = spawn.y
	_rise = 3 if _rid != 2 and _rid != 7 and _rid != 12 and _rid != 18 else 0
	if _rid == 4 or _rid == 0 or _rid == 10 or _rid == 11 or _rid == 8:
		_rise = 3
	if _rid == 13 or _rid == 14 or _rid == 17 or _rid == 3:
		_rise = 2
	_west_x = 2
	_east_x = clampi(door.x, 16, WIDTH - 4)
	_knuckle = clampi(_west_x + 14, 12, _east_x - 6)
	if from_east:
		_west_x = 8
		_east_x = WIDTH - 3
		_knuckle = clampi(door.x + 8, _west_x + 6, _east_x - 8)
	if _rise <= 0:
		_ribbon_h(_west_x, _east_x, _low_n, true, true)
		return
	var high_n := _low_n - _rise
	if high_n < 4:
		_rise = 0
		_ribbon_h(_west_x, _east_x, _low_n, true, true)
		return
	_ribbon_h(_west_x, _knuckle, _low_n, true, false)
	_ribbon_v(_knuckle - 1, high_n, _low_n + 1)
	_ribbon_h(_knuckle - 1, _east_x, high_n, false, true)
	_stamp_step(_knuckle - 1, _knuckle, _low_n, high_n)
	door = Vector2i(_east_x, high_n)


func _crossroads() -> void:
	_low_n = spawn.y
	_west_x = 3
	_east_x = clampi(door.x, 36, WIDTH - 4)
	_knuckle = 28
	_rise = 0
	_ribbon_h(_west_x, _east_x, _low_n, true, true)
	var top := 4
	for y in range(top, _low_n):
		_add_path(_knuckle - 1, y)
		_add_path(_knuckle, y)
	for y in range(top + 1, _low_n):
		_set_path_tile(_knuckle - 1, y, Vector2i(21, 1))
		_set_path_tile(_knuckle, y, Vector2i(23, 1))
	_set_path_tile(_knuckle - 1, top, Vector2i(21, 0))
	_set_path_tile(_knuckle, top, Vector2i(23, 0))
	_set_path_tile(_knuckle - 1, _low_n, Vector2i(23, 5))
	_set_path_tile(_knuckle, _low_n, Vector2i(21, 5))


func _three_way() -> void:
	_crossroads()
	var arm_x := 44
	var top := _low_n - 8
	for y in range(top, _low_n):
		_add_path(arm_x, y)
		_add_path(arm_x + 1, y)
	for y in range(top + 1, _low_n):
		_set_path_tile(arm_x, y, Vector2i(21, 1))
		_set_path_tile(arm_x + 1, y, Vector2i(23, 1))
	_set_path_tile(arm_x, top, Vector2i(21, 0))
	_set_path_tile(arm_x + 1, top, Vector2i(23, 0))
	_set_path_tile(arm_x, _low_n, Vector2i(23, 5))
	_set_path_tile(arm_x + 1, _low_n, Vector2i(21, 5))


func _double_lean() -> void:
	_low_n = spawn.y
	_west_x = 2
	_east_x = clampi(door.x, 48, WIDTH - 4)
	var k1 := 18
	var k2 := 36
	var rise := 3
	var mid_n := _low_n - rise
	var high_n := mid_n - rise
	_rise = rise
	_knuckle = k2
	_ribbon_h(_west_x, k1, _low_n, true, false)
	_ribbon_v(k1 - 1, mid_n, _low_n + 1)
	_ribbon_h(k1 - 1, k2, mid_n, false, false)
	_ribbon_v(k2 - 1, high_n, mid_n + 1)
	_ribbon_h(k2 - 1, _east_x, high_n, false, true)
	_stamp_step(k1 - 1, k1, _low_n, mid_n)
	_stamp_step(k2 - 1, k2, mid_n, high_n)
	door = Vector2i(_east_x, high_n)


func _switchback() -> void:
	# U back to the west edge. Two 90° knuckles, no 1-tile stair.
	_west_x = 3
	_east_x = 40
	_knuckle = 40
	var top_n := 18
	var bot_n := 28
	_low_n = bot_n
	_rise = 0
	_ribbon_h(_west_x, _east_x, bot_n, true, false)
	_ribbon_v(_east_x - 1, top_n, bot_n + 1)
	_ribbon_h(_west_x, _east_x, top_n, true, false)
	for y in range(top_n + 2, bot_n):
		_set_path_tile(_east_x - 1, y, Vector2i(21, 1))
		_set_path_tile(_east_x, y, Vector2i(23, 1))
	# Lower knuckle: east then north.
	_set_path_tile(_east_x - 1, bot_n + 1, Vector2i(22, 2))
	_set_path_tile(_east_x, bot_n + 1, Vector2i(23, 2))
	_set_path_tile(_east_x, bot_n, Vector2i(23, 1))
	_set_path_tile(_east_x - 1, bot_n, Vector2i(23, 5))
	# Upper knuckle: north then west. Outside is north and east.
	_set_path_tile(_east_x - 1, top_n, Vector2i(22, 0))
	_set_path_tile(_east_x, top_n, Vector2i(23, 0))
	_set_path_tile(_east_x - 1, top_n + 1, Vector2i(23, 3))
	_set_path_tile(_east_x, top_n + 1, Vector2i(23, 1))
	spawn = Vector2i(6, bot_n)
	door = Vector2i(22, top_n)
	house = Vector2i(22, top_n - 4)


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


func _force_geometry() -> void:
	_lay_path([])


func _add_path(x: int, y: int) -> void:
	if not _inside(x, y):
		return
	if _biome[_i(x, y)] == WATER or _biome[_i(x, y)] == HIGH:
		return
	_path[_key(x, y)] = true
	var i := _i(x, y)
	_biome[i] = DIRT
	_feat[i] = 2


func _set_path_tile(x: int, y: int, tile: Vector2i) -> void:
	if not _path.has(_key(x, y)):
		_add_path(x, y)
	if not _path.has(_key(x, y)):
		return
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
		15: return Vector2i(22, 1)
		14: return Vector2i(22, 0)
		11: return Vector2i(22, 2)
		7: return Vector2i(21, 1)
		13: return Vector2i(23, 1)
		6: return Vector2i(23, 5)
		12: return Vector2i(21, 5)
		3: return Vector2i(23, 3)
		9: return Vector2i(21, 3)
		2: return Vector2i(21, 0)
		8: return Vector2i(23, 0)
		4: return Vector2i(22, 2)
		1: return Vector2i(22, 0)
		_: return Vector2i(22, 0)


func _shore_pond() -> void:
	for y in HEIGHT:
		for x in WIDTH:
			if _biome[_i(x, y)] != WATER:
				continue
			var n := _is(WATER, x, y - 1)
			var e := _is(WATER, x + 1, y)
			var s := _is(WATER, x, y + 1)
			var w := _is(WATER, x - 1, y)
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


func _reeds() -> void:
	var placed := 0
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			if placed >= 3 or _biome[_i(x, y)] != WATER:
				continue
			if _is(WATER, x, y + 1):
				continue
			if _hash2(x, y + 3) > 0.4:
				continue
			_deco[_i(x, y)] = 47 + 5 * 51
			placed += 1


func _cliff_autotile() -> void:
	for y in HEIGHT:
		for x in WIDTH:
			if _biome[_i(x, y)] != HIGH:
				continue
			var s := _is(HIGH, x, y + 1)
			var w := _is(HIGH, x - 1, y)
			var e := _is(HIGH, x + 1, y)
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
	var top_y := house.y - 3
	var bottom_y := house.y + 3
	if _gate_only:
		left_x = door.x - 2
		right_x = door.x + 3
		top_y = door.y
		bottom_y = door.y
	var rails := [Vector2i(30, 24), Vector2i(30, 25), Vector2i(30, 27)]
	if not _gate_only:
		props.append(_fence_piece(left_x, top_y, Vector2i(29, 24)))
		props.append(_fence_piece(right_x, top_y, Vector2i(31, 25)))
		props.append(_fence_piece(left_x, bottom_y, Vector2i(29, 27)))
		props.append(_fence_piece(right_x, bottom_y, Vector2i(31, 27)))
	var gate_a := door.x
	var gate_b := door.x + 1
	for x in range(left_x + 1, right_x):
		if not _gate_only:
			props.append(_fence_piece(x, top_y, rails[posmod(x, 3)]))
		if x == gate_a or x == gate_b:
			continue
		props.append(_fence_piece(x, bottom_y, rails[posmod(x + 1, 3)]))
	if not _gate_only:
		for y in range(top_y + 1, bottom_y):
			props.append(_fence_piece(left_x, y, Vector2i(29, 26)))
			props.append(_fence_piece(right_x, y, Vector2i(31, 26)))
	return props


func _fence_piece(x: int, y: int, gid: Vector2i) -> Dictionary:
	return {"tile": Vector2i(x, y), "region": Rect2(gid.x * 16, gid.y * 16, 16, 16), "body": Vector2(14, 8)}


func _trees() -> Array:
	var regions := [
		Rect2(464, 180, 64, 75), Rect2(530, 181, 77, 87),
		Rect2(464, 292, 64, 75), Rect2(530, 293, 77, 87),
	]
	var props: Array = []
	var want := _tree_min + int(_hash2(2, 9) * float(_tree_max - _tree_min + 1))
	var spots := _poisson(_tree_gap, 48, want)
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
		if _has_house and absi(x - house.x) <= 6 and absi(y - house.y) <= 6:
			continue
		if absi(x - spawn.x) <= 3 and absi(y - spawn.y) <= 3:
			continue
		var ok := true
		for p in pts:
			if Vector2(p).distance_to(Vector2(x, y)) < min_dist:
				ok = false
				break
		if ok:
			pts.append(Vector2i(x, y))
	return pts


func _flowers() -> void:
	var flowers := [Vector2i(8, 2), Vector2i(9, 2), Vector2i(8, 3), Vector2i(9, 3), Vector2i(10, 3), Vector2i(9, 5)]
	for y in range(1, HEIGHT - 1):
		for x in range(1, WIDTH - 1):
			if _biome[_i(x, y)] != GRASS:
				continue
			if _near_fence and (absi(x - house.x) > 8 or absi(y - house.y) > 8):
				continue
			if _hash2(x + 5, y + 9) > _deco_p:
				continue
			var flower: Vector2i = flowers[int(_hash2(x, y + 4) * flowers.size()) % flowers.size()]
			_deco[_i(x, y)] = flower.x + flower.y * 51


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
			var f: int = int(gscore[_key(p.x, p.y)]) + absi(p.x - goal.x) + absi(p.y - goal.y)
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
	if not _inside(x, y) or x < 1 or y < 1 or x >= WIDTH - 1 or y >= HEIGHT - 1:
		return false
	var b := _biome[_i(x, y)]
	return b == GRASS or b == DIRT


func _reaches(start: Vector2i, goal: Vector2i) -> bool:
	var seen := {_key(start.x, start.y): true}
	var stack: Array[Vector2i] = [start]
	while stack.size() > 0:
		var cur: Vector2i = stack.pop_back()
		if absi(cur.x - goal.x) + absi(cur.y - goal.y) <= 2:
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


func _span_clear(y: int, x1: int) -> bool:
	if y < 2 or y >= HEIGHT - 3:
		return false
	for x in range(2, x1 + 1):
		if not _inside(x, y) or not _inside(x, y + 1):
			return false
		if _biome[_i(x, y)] == WATER or _biome[_i(x, y + 1)] == WATER:
			return false
		if _biome[_i(x, y)] == HIGH or _biome[_i(x, y + 1)] == HIGH:
			return false
	return true


func _flatten(cx: int, cy: int, radius: int) -> void:
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if not _inside(x, y):
				continue
			if Vector2(x - cx, y - cy).length() > float(radius):
				continue
			_biome[_i(x, y)] = GRASS
			_feat[_i(x, y)] = 0


func _clear_kind(kind: int) -> void:
	for i in _biome.size():
		if _biome[i] == kind:
			_biome[i] = GRASS
			_feat[i] = 0


func _water_run(x: int, y: int, dx: int, dy: int) -> int:
	var n := 1
	var s := 1
	while _is(WATER, x + dx * s, y + dy * s):
		n += 1
		s += 1
	s = 1
	while _is(WATER, x - dx * s, y - dy * s):
		n += 1
		s += 1
	return n


func _core_touch(core: PackedInt32Array, x: int, y: int) -> bool:
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var dir: Vector2i = step
		if _inside(x + dir.x, y + dir.y) and core[_i(x + dir.x, y + dir.y)] == WATER:
			return true
	return false


func _is(kind: int, x: int, y: int) -> bool:
	return _inside(x, y) and _biome[_i(x, y)] == kind


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
			if _is(kind, x + dx, y + dy):
				n += 1
	return n


func _neighbors4(x: int, y: int, kind: int) -> int:
	var n := 0
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var dir: Vector2i = step
		if _is(kind, x + dir.x, y + dir.y):
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
