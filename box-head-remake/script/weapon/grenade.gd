extends "res://script/weapon/weapon.gd"

## 手榴弹武器脚本
# 继承自weapon.gd，实现手榴弹的投掷逻辑
# 按住发射键蓄力，松开后扔出，手榴弹会弹跳并延迟爆炸


## 手榴弹物体场景预加载
var grenadeObj: PackedScene = preload("res://scene/projectile/grenade_obj.tscn")
## 蓄力速度增量
## 蓄力时长（秒），原版 CMath.Range(按住秒数, 0.25, 0.75)
var holdTime: float = 0.0
## 当前投掷速度
## 投掷速度（px/s），由蓄力时长换算
var speed: float = 0.0
## 最大投掷速度
## 原版最大距离系数 0.75 格/帧 → 0.75 * 32 * 25 = 600 px/s
var maxSpeed: float = 600.0
## 最小投掷速度
## 原版最小距离系数 0.25 格/帧 → 0.25 * 32 * 25 = 200 px/s
var minSpeed: float = 200.0
## 投掷高度偏移
var height: int = 25


## 初始化
func _ready() -> void:
	pass


## 投掷手榴弹
# 释放手榴弹实体，根据蓄力速度决定投掷距离
# @param direction 投掷方向（Vector2）
func fire(direction: Vector2) -> void:
	if ammoNum <= 0:
		return

	ammoNum -= 1
	vector = direction

	# 创建手榴弹实例
	var temp = grenadeObj.instantiate()
	temp.vector = vector.normalized()
	# 原版：距离系数 = clamp(按住秒数, 0.25, 0.75)（单位：格/帧）
	var factor: float = clampf(holdTime, 0.25, 0.75)
	temp.speed = factor * MapData.cellSize * MapData.TICKS_PER_SEC
	# 沿投掷方向前移一点，避免出生时和玩家受击框重叠（否则第一帧就判定碰撞）
	temp.global_position = global_position - Vector2(0, height) + vector.normalized() * 24.0
	temp.collision_mask = collisionMask
	temp.ownerId = ownerId
	#temp.excludeList = [ownerId]
	temp.damage = damage
	temp.biggerBang = biggerBang
	temp.clusterExplode = clusterExplode

	# 重置蓄力
	holdTime = 0.0
	speed = minSpeed

	get_tree().current_scene.add_child(temp)


## 蓄力增加速度
# 在按住发射键时调用，增加投掷速度直到达到最大值
func increase(delta: float = 1.0 / 60.0) -> void:
	holdTime = minf(holdTime + delta, 0.75)
	speed = clampf(holdTime, 0.25, 0.75) * MapData.cellSize * MapData.TICKS_PER_SEC
