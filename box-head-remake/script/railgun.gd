extends "res://script/weapon.gd"

## 轨道炮脚本
# 继承自weapon.gd，实现轨道炮的射击逻辑
# 使用Area2D射线检测实现穿透射击，伤害较高


## 动画节点
@onready var ani = $ani

## 玩家精灵节点（用于播放射击动画）
@onready var player = $player

## 射线检测节点
@onready var ray = $ray

## 目标位置（射线终点）
var targetPos = Vector2.ZERO


## 初始化
func _ready():
	# 设置8个方向的武器偏移量
	offsetDir[0] = Vector2(45, -15)
	offsetDir[1] = Vector2(20, 0)
	offsetDir[2] = Vector2(-10, 10)
	offsetDir[3] = Vector2(-35, -5)
	offsetDir[4] = Vector2(-40, -35)
	offsetDir[5] = Vector2(-18, -45)
	offsetDir[6] = Vector2(15, -50)
	offsetDir[7] = Vector2(40, -35)


## 物理帧更新
# 在射击后的detecframes帧内持续检测碰撞
func _physics_process(_delta):
	if detecframes > 0:
		detecframes -= 1
		
		# 获取射线重叠的所有区域
		var r = ray.get_overlapping_areas()
		if r:
			for i in r:
				if i.get("type") && i.type in [Game.itemType.Barrel,
									Game.itemType.Wall]:
					if !excludeObj.has(i.get_rid()):
						i.hit(damage)
						excludeObj.append(i.get_rid())
				elif i.owner.type && i.owner.type in [Game.roleType.Player,
					Game.roleType.Zombie, Game.roleType.Devil]:
					if !excludeObj.has(i.get_rid()):
						i.owner.hit(damage, global_position, hitFeedback)
						excludeObj.append(i.get_rid())
		
		queue_redraw()


## 射击
# 开始射击流程，消耗弹药，设置射击方向和状态
# @param _v 射击方向（Vector2）
func fire(_v):
	if ammoNum <= 0:
		return
	if canShoot:
		detecframes = 2
		vector = _v
		ammoNum -= 1
		canShoot = false
		timer.start(delay)
		
		var offset = offsetDir[wrapi(int(vector.angle() / (PI / 4)), 0, 8)]
		ani.position = offset
		ani.rotation = vector.angle()
		player.play("fire")
		sound.play()
		
		# 设置射线角度和位置
		ray.rotation = vector.angle()
		ray.position = offset
		
		targetPos = global_position + vector * wRange + offset
		excludeObj.clear()


## 绘制
# 绘制射击射线（调试用）
func _draw() -> void:
	if detecframes > 0:
		var offset = offsetDir[wrapi(int(vector.angle() / (PI / 4)), 0, 8)]
		draw_line(offset, targetPos - global_position, Color.BLUE_VIOLET, 3)
