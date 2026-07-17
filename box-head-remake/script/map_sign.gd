extends Area2D

## 地图标志点脚本
# 用于标记地图上的特殊位置，如出生点、物品刷新点等
# 支持多种类型和方向，可检测是否被其他物体阻挡


## 标志类型（Game.mapSign枚举值）
@export var type: Game.mapSign = Game.mapSign.Zombie
## 标志方向（Game.mapSignDir枚举值，用于敌人出生方向）
@export var dir: Game.mapSignDir = Game.mapSignDir.Down
## 是否开启调试模式（显示标志点动画）
@export var debug = false
## 动画节点
@onready var ani = $ani


## 初始化
func _ready() -> void:
	# 调试模式下显示标志点动画
	if debug:
		ani.visible = true
		if type == Game.mapSign.Zombie:
			ani.play("0")
		elif type == Game.mapSign.Devil:
			ani.play("1")
		elif type == Game.mapSign.Player:
			ani.play("3")
		elif type == Game.mapSign.Box:
			ani.play("2")
	
	# 根据类型设置碰撞掩码
	if type == Game.mapSign.Box:
		collision_mask = 64
	elif type in [Game.mapSign.Zombie, Game.mapSign.Devil]:
		collision_mask = 2


## 检测是否被阻挡
# 检查标志点位置是否有其他物体占用
# @return 是否被阻挡（bool）
func hasBlock():
	return has_overlapping_areas() || has_overlapping_bodies()
