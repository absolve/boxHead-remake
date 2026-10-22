extends "res://script/level/level.gd"

## 通用房间脚本（所有从平面图批量生成的房间共用）
##
## 与 room_001 的区别：**障碍格不再手写**，而是从所有墙体的 CollisionShape2D
## 自动推导（见 registerWallObstacles）。以后挪墙、换墙块都不用改脚本，
## 也不会出现"美术挪了但寻路没跟着变"的问题。

## 箱子：按 mapSign(Box) 的位置在初始化时生成
##
## 之前的做法是在场景里手摆 box 节点，容易和 mapSign 的位置对不上；
## 现在场景只放标记，实体由代码生成，位置天然一致。
@export var boxScene: PackedScene = preload("res://scene/item/box.tscn")


func _ready() -> void:
	# 收集出生点标记（按 type 分类）
	for n in get_tree().get_nodes_in_group("sign"):
		if n.type == Game.mapSign.Zombie:
			zombieSpawnPoint.append(n)
		elif n.type == Game.mapSign.Devil:
			devilSpawnPoint.append(n)
		elif n.type == Game.mapSign.Player:
			playerSpawnPoint.append(n)
		elif n.type == Game.mapSign.Box:
			itemSpawnPoint.append(n)

	# 地图尺寸写到全局（寻路/流场按这个算）
	MapData.mapSize = mapSize

	# 重建障碍
	MapData.clearObstacle()
	registerWallObstacles()
	registerItemObstacles()

	# 按墙体和出生点把地图撑到真实范围（原版地图比相机视口大，
	# 出生点在相机视野外，相机靠 mapSize 夹取来限制移动范围）
	expandMapToContents()
	spawnBoxes()
	registerMapRect()


## 把整张房间平移到原点：最小 x/y 对齐到 (0,0)
##
## 原版地图的墙体/出生点会伸到负坐标（例如 x=-39），
## 直接把 mapSize 设成真实范围会留下负数格子。与其给流场加偏移支持，
## 不如把房间节点整体挪一下——所有子节点（墙、出生点、背景）一起移动，
## 相对关系不变，而全局坐标全部变成非负。
func normalizeMapOrigin() -> void:
	var minX: float = 0.0
	var minY: float = 0.0

	for body in get_children():
		if not (body is StaticBody2D):
			continue
		for c in body.get_children():
			if not (c is CollisionShape2D):
				continue
			if not (c.shape is RectangleShape2D):
				continue
			var rect: RectangleShape2D = c.shape
			var ctr: Vector2 = c.global_position
			minX = minf(minX, ctr.x - rect.size.x / 2.0)
			minY = minf(minY, ctr.y - rect.size.y / 2.0)

	for group in [zombieSpawnPoint, devilSpawnPoint, itemSpawnPoint, playerSpawnPoint]:
		for n in group:
			var p: Vector2 = (n as Node2D).global_position
			minX = minf(minX, p.x)
			minY = minf(minY, p.y)

	# 向下取整到整格
	if minX < 0.0 or minY < 0.0:
		var cs: float = MapData.cellSize
		var shift := Vector2(floorf(minX / cs) * cs, floorf(minY / cs) * cs)
		position -= shift
		print("[%s] 房间平移到原点，位移 %s" % [name, str(shift)])


## 把 MapData.mapSize 撑大到覆盖所有墙体矩形和出生点（只放大，不缩小）
func expandMapToContents() -> void:
	var cs: float = MapData.cellSize
	var maxX: float = MapData.mapSize.x
	var maxY: float = MapData.mapSize.y

	for body in get_children():
		if not (body is StaticBody2D):
			continue
		for c in body.get_children():
			if not (c is CollisionShape2D):
				continue
			if not (c.shape is RectangleShape2D):
				continue
			var rect: RectangleShape2D = c.shape
			var ctr: Vector2 = c.global_position
			maxX = maxf(maxX, ctr.x + rect.size.x / 2.0)
			maxY = maxf(maxY, ctr.y + rect.size.y / 2.0)

	for group in [zombieSpawnPoint, devilSpawnPoint, itemSpawnPoint, playerSpawnPoint]:
		for n in group:
			var p: Vector2 = (n as Node2D).global_position
			maxX = maxf(maxX, p.x)
			maxY = maxf(maxY, p.y)

	# 向上取整到整格
	var w: float = ceilf(maxX / cs) * cs
	var h: float = ceilf(maxY / cs) * cs
	if w > MapData.mapSize.x or h > MapData.mapSize.y:
		MapData.mapSize = Vector2(w, h)
		print("[%s] 地图扩展为 %dx%d（房间实际范围）" % [name, int(w), int(h)])


## 从所有墙体 StaticBody2D 的矩形碰撞盒推导障碍格
func registerWallObstacles() -> void:
	var cs: float = MapData.cellSize
	var count := 0

	for body in get_children():
		if not (body is StaticBody2D):
			continue
		for c in body.get_children():
			if not (c is CollisionShape2D):
				continue
			var shp = c.shape
			if not (shp is RectangleShape2D):
				continue

			var rect: RectangleShape2D = shp
			var center: Vector2 = c.global_position
			var half: Vector2 = rect.size / 2.0

			# 矩形覆盖到的格子范围（右/下边界减一点，避免刚好卡在格线上时多算一行）
			# 边缘容差取 2px：墙体右/下边缘常常正好压在格线上
			# （例如 289 只比第 9 列起点 288 多 1px），
			# 用 0.01 会把整列误判成障碍，导致通道少一格。
			# 只缩小「右/下」边界：左/上边界用 0.01 保持覆盖，
			# 否则每面墙都会在左边缘让出一格（行14 第 0 列出现空洞）。
			const EDGE_EPS := 2.0
			var c0 := Vector2i(floori((center.x - half.x + 0.01) / cs),
					floori((center.y - half.y + 0.01) / cs))
			var c1 := Vector2i(floori((center.x + half.x - EDGE_EPS) / cs),
					floori((center.y + half.y - EDGE_EPS) / cs))

			for x in range(c0.x, c1.x + 1):
				for y in range(c0.y, c1.y + 1):
					MapData.addObstacleAt(Vector2i(x, y))
					count += 1

	print("[%s] 登记障碍格 %d 个，出生点 僵%d/恶%d/箱%d/玩%d"
			% [name, count, zombieSpawnPoint.size(), devilSpawnPoint.size(),
			itemSpawnPoint.size(), playerSpawnPoint.size()])


## 把场景里**预先摆好**的油桶 / 假墙也登记成障碍
##
## 之前只有玩家用油桶武器放置时才会 addObstacleAt，
## 房间场景里直接摆的 barrelObj / wallObj 从来不算障碍 ——
## 流场会指进去，僵尸撞上又过不去，于是原地无限打转。
func registerItemObstacles() -> void:
	var count := 0
	for n in get_children():
		if not (n is Area2D):
			continue

		# 判断是不是"挡路的放置物"：优先看 type，
		# 场景里预摆的实例可能没覆盖 type（默认 Box），所以再看场景文件路径兜底
		var blocking := false
		var t = n.get("type")
		if t != null and t is int and (t in [Game.itemType.Barrel, Game.itemType.Wall]):
			blocking = true
		if not blocking:
			var sp: String = n.scene_file_path
			if sp.contains("barrel_obj") or sp.contains("wall_obj"):
				blocking = true
		if not blocking:
			continue

		var cell: Vector2i = MapData.worldToCell(n.global_position)
		MapData.addObstacleAt(cell)
		count += 1

		# 让 item._exit_tree 在被打碎时自动把这格摘掉
		if n.get("blocksPath") != null:
			n.blocksPath = true
		if n.get("cell") != null:
			n.cell = cell

	if count > 0:
		print("[%s] 预摆物体登记为障碍 %d 个" % [name, count])


## 记录房间的真实世界边界（相机靠它夹取，不做任何坐标平移）
func registerMapRect() -> void:
	var minP := Vector2(INF, INF)
	var maxP := Vector2(-INF, -INF)

	for body in get_children():
		if not (body is StaticBody2D):
			continue
		for c in body.get_children():
			if not (c is CollisionShape2D):
				continue
			if not (c.shape is RectangleShape2D):
				continue
			var rect: RectangleShape2D = c.shape
			var ctr: Vector2 = c.global_position
			minP = Vector2(minf(minP.x, ctr.x - rect.size.x / 2.0), minf(minP.y, ctr.y - rect.size.y / 2.0))
			maxP = Vector2(maxf(maxP.x, ctr.x + rect.size.x / 2.0), maxf(maxP.y, ctr.y + rect.size.y / 2.0))

	for group in [zombieSpawnPoint, devilSpawnPoint, itemSpawnPoint, playerSpawnPoint]:
		for n in group:
			var p: Vector2 = (n as Node2D).global_position
			minP = Vector2(minf(minP.x, p.x), minf(minP.y, p.y))
			maxP = Vector2(maxf(maxP.x, p.x), maxf(maxP.y, p.y))

	if minP.x > maxP.x:
		return
	MapData.mapRect = Rect2(minP, maxP - minP)
	print("[%s] 地图边界 %s" % [name, str(MapData.mapRect)])




func spawnBoxes() -> void:
	if boxScene == null:
		return
	for sp in itemSpawnPoint:
		var b: Node2D = boxScene.instantiate()
		b.position = (sp as Node2D).position
		add_child(b)
	print("[%s] 生成箱子 %d 个" % [name, itemSpawnPoint.size()])
