extends Area2D

## 地图标志点脚本
# 用于标记地图上的特殊位置，如出生点、物品刷新点等
# 支持多种类型和方向，可检测是否被其他物体阻挡


## 标志类型（Game.mapSign枚举值）
@export var type: Game.mapSign = Game.mapSign.Zombie
## 标志方向（Game.mapSignDir枚举值，用于敌人出生方向）
@export var dir: Game.mapSignDir = Game.mapSignDir.Down
## 是否开启调试模式（显示标志点动画）
@export var debug: bool = false


## 动画节点
@onready var ani: AnimatedSprite2D = $ani


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
func hasBlock() -> bool:
	if has_overlapping_areas()  or  has_overlapping_bodies():
		return true
	# Spawn 阶段的僵尸受击盒是关的（原版 mFlag_Collidable），
	# 这里用距离兜底，避免同一出生点反复刷怪叠在一起。
	for z in get_tree().get_nodes_in_group("enemy"):
		if z == null or not is_instance_valid(z):
			continue
		if (z as Node2D).global_position.distance_to(global_position) < 24.0:
			return true
	return false
