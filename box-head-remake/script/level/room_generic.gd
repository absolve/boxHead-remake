extends "res://script/level/level.gd"

## 通用房间脚本：所有房间共用
##
## 房间场景里只保留「数据 + 出生点标记」：
##   mapSize        地图尺寸（= 红框格数 × 32）
##   wallObstacles  静态障碍格（柱子、边界墙）
##   wallPoint      墙（wall_obj）格坐标
##   barrelPoint    油桶（barrel_obj）格坐标
##   mapSign*       出生点标记（僵尸/恶魔/玩家/箱子）
##
## 实体（墙、油桶、箱子）都在运行时按格坐标生成，位置天然对齐格心。


const WALL_OBJ: PackedScene = preload("res://scene/item/wall_obj.tscn")
const BARREL_OBJ: PackedScene = preload("res://scene/item/barrel_obj.tscn")


## 箱子：按 mapSign(Box) 的位置在初始化时生成
@export var boxScene: PackedScene = preload("res://scene/item/box.tscn")

## wallPoint / barrelPoint（墙和油桶的格坐标）定义在 level.gd 里，
## 这里只负责按坐标把对应的场景实例化。
## 这两个场景自带碰撞体，所以**不需要**再把它们的格子登记成静态障碍。


func _ready() -> void:
	# 只收集**本房间自己的**出生点标记。
	# 不能用 get_tree().get_nodes_in_group("sign")：切换房间时旧房间还要等
	# 一帧才真正释放，会把上一张地图的标记也算进来（表现为旧箱子留在新地图上）。
	zombieSpawnPoint.clear()
	devilSpawnPoint.clear()
	playerSpawnPoint.clear()
	itemSpawnPoint.clear()
	for n in find_children("*", "Node", true, false):
		if not n.is_in_group("sign"):
			continue
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

	# 按格坐标生成墙和油桶（它们自带碰撞，不算静态障碍格）
	spawnPointObjects()

	# 重建障碍
	MapData.clearObstacle()
	registerWallObstacles()
	registerItemObstacles()

	# mapSize 由场景显式配置（= 红框格数 × 32），不再按内容推导
	spawnBoxes()
	registerMapRect()


## 按 wallPoint / barrelPoint 生成墙和油桶实体（位置 = 格心）
##
## 显式命名（wall_r_c / barrel_r_c）：Godot 对同名节点会自动起 `@xxx@N` 这种名字，
## 按名字前缀做显示/隐藏时就会漏掉一部分，所以这里统一命名。
func spawnPointObjects() -> void:
	var cs: float = MapData.cellSize
	for cell in wallPoint:
		var w: Node2D = WALL_OBJ.instantiate()
		w.name = "wall_%d_%d" % [cell.x, cell.y]
		w.position = Vector2(cell.x * cs + cs * 0.5, cell.y * cs + cs * 0.5)
		add_child(w)
	for cell in barrelPoint:
		var b: Node2D = BARREL_OBJ.instantiate()
		b.name = "barrel_%d_%d" % [cell.x, cell.y]
		b.position = Vector2(cell.x * cs + cs * 0.5, cell.y * cs + cs * 0.5)
		add_child(b)


## 从所有墙体 StaticBody2D 的矩形碰撞盒推导障碍格
func registerWallObstacles() -> void:
	# 障碍格现在全部来自场景里配置的 wallObstacles（Vector2i 格坐标），
	# 不再从墙体碰撞盒反推：碰撞盒有缩放/偏移，容易算错。
	for cell in wallObstacles:
		var c: Vector2i = Vector2i(cell)
		if not MapData.isObstacle(c):
			MapData.addObstacleAt(c)
	if wallObstacles.is_empty():
		push_warning("%s: wallObstacles 为空，这个房间没有任何障碍物" % name)


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


## 记录房间的可玩区域
##
## 可玩区 = 地图矩形（0,0 ~ mapSize）四边各内缩 32px（一格）。
## 原版红框就是地图边界，最外一圈格子属于边界墙/装饰，相机和玩家都不该进去。
func registerMapRect() -> void:
	var inset: float = MapData.cellSize
	var rect := Rect2(Vector2.ZERO, MapData.mapSize).grow(-inset)
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		MapData.mapRect = rect
	else:
		MapData.mapRect = Rect2(Vector2.ZERO, MapData.mapSize)
	print("[%s] 地图边界 %s" % [name, str(MapData.mapRect)])


func spawnBoxes() -> void:
	if boxScene == null:
		return
	for sp in itemSpawnPoint:
		var b: Node2D = boxScene.instantiate()
		b.position = (sp as Node2D).position
		add_child(b)
	print("[%s] 生成箱子 %d 个" % [name, itemSpawnPoint.size()])
