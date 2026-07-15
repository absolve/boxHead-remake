extends Node2D

## 关卡基类脚本
# 所有关卡场景的基类，定义了关卡的基本结构和属性
# 包含出生点、地图大小等配置


## 玩家出生点列表
var playerSpawnPoint: Array = []

## 僵尸出生点列表
var zombieSpawnPoint: Array = []

## 恶魔出生点列表
var devilSpawnPoint: Array = []

## 物品刷新点列表
var itemSpawnPoint: Array = []

## 地图大小
@export var mapSize: Vector2 = Vector2(640, 480)

## 是否开启调试模式
@export var debug = false


## 初始化
func _ready() -> void:
	pass


## 绘制（预留）
# 绘制地图网格（调试用）
func _draw() -> void:
	var width = floori(MapData.mapSize.x / MapData.cellSize)
	var height = floori(MapData.mapSize.y / MapData.cellSize)
	for i in range(width + 1):
		draw_line(Vector2(i * MapData.cellSize, 0), Vector2(i * MapData.cellSize, MapData.cellSize * height), Color.WHITE, 1, true)
	for i in range(height + 1):
		draw_line(Vector2(0, i * MapData.cellSize), Vector2(MapData.cellSize * width, i * MapData.cellSize), Color.WHITE, 1, true)