extends "res://script/level.gd"

## 房间001关卡脚本
# 继承自level.gd，实现第一个关卡的具体配置
# 初始化地图标志点、障碍物等


## 初始化
func _ready() -> void:
	# 获取所有标志点节点
	var nodes = get_tree().get_nodes_in_group("sign")
	
	# 根据标志点类型分类
	for i in nodes:
		if i.type == Game.mapSign.Zombie:
			zombieSpawnPoint.append(i)
		elif i.type == Game.mapSign.Devil:
			devilSpawnPoint.append(i)
		elif i.type == Game.mapSign.Player:
			playerSpawnPoint.append(i)
		elif i.type == Game.mapSign.Box:
			itemSpawnPoint.append(i)
	
	# 设置地图大小到全局数据
	MapData.mapSize = mapSize
	
	# 清空之前的障碍物
	MapData.clearObstacle()
	
	# 添加顶部障碍物（边界墙）
	for i in range(9):
		for y in range(2):
			MapData.addObstacle(Vector2(i, y))
	
	for i in range(11, 20):
		for y in range(2):
			MapData.addObstacle(Vector2(i, y))
	
	# 请求重绘
	#queue_redraw()
