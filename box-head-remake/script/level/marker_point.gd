extends Area2D

## 标记点脚本
# 用于标记地图上的特殊位置点
# 目前支持僵尸和恶魔的出生点标记


## 标记点类型（Game.markerPointType枚举值）
@export var type: Game.markerPointType = Game.markerPointType.ZombieSpawnPoint


## 初始化
func _ready():
	pass
