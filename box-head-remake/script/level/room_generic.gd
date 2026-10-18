extends "res://script/level/level.gd"

## 通用房间脚本（所有从平面图批量生成的房间共用）
##
## 与 room_001 的区别：**障碍格不再手写**，而是从所有墙体的 CollisionShape2D
## 自动推导（见 registerWallObstacles）。以后挪墙、换墙块都不用改脚本，
## 也不会出现"美术挪了但寻路没跟着变"的问题。


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
			var c0 := Vector2i(floori((center.x - half.x) / cs), floori((center.y - half.y) / cs))
			var c1 := Vector2i(floori((center.x + half.x - 0.01) / cs),
					floori((center.y + half.y - 0.01) / cs))

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
