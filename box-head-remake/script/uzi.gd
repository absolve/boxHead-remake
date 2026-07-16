extends "res://script/weapon.gd"

## UZI冲锋枪脚本
# 继承自weapon.gd，实现UZI的连发射击逻辑
# 与手枪类似，但支持自动连射，射速更快


## 动画节点
@onready var ani = $ani

## 玩家精灵节点（用于播放射击动画）
@onready var player = $player

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
func _physics_process(_delta: float) -> void:
	if detecframes > 0:
		detecframes -= 1
		
		var space_state = get_world_2d().direct_space_state
		var offset = offsetDir[wrapi(int(vector.angle() / (PI / 4)), 0, 8)]
		targetPos = global_position + vector * wRange + offset
		
		# 创建射线查询
		var query = PhysicsRayQueryParameters2D.create(global_position + offset, 
			targetPos, collisionMask)
		query.collide_with_areas = true
		query.exclude = [ownerId]
		var result = space_state.intersect_ray(query)
		
		if result:
			if result.collider is StaticBody2D:
				targetPos = result.position
				addSmoke(targetPos)
			elif result.collider.get("type") && result.collider.type in [Game.itemType.Barrel,
								Game.itemType.Wall]:
				if !excludeObj.has(result.collider_id):
					result.collider.hit(damage)
					excludeObj.append(result.collider_id)
				targetPos = result.position
				addSmoke(targetPos)
			elif result.collider is Area2D:
				if result.collider.owner.type && result.collider.owner.type in [Game.roleType.Player,
					Game.roleType.Zombie, Game.roleType.Devil]:
					if !excludeObj.has(result.collider_id):
						result.collider.owner.hit(damage, result.position, hitFeedback)
						excludeObj.append(result.collider_id)
					targetPos = result.position
					addSmoke(targetPos)
		
		queue_redraw()


## 射击
# 开始射击流程，消耗弹药，设置射击方向和状态
# @param v 射击方向（Vector2）
func fire(v):
	if ammoNum <= 0:
		return
	if canShoot:
		ammoNum -= 1
		detecframes = 2
		vector = v
		canShoot = false
		timer.start(delay)
		
		ani.position = offsetDir[wrapi(int(vector.angle() / (PI / 4)), 0, 8)]
		ani.rotation = vector.angle()
		player.play("fire")
		sound.play()
		excludeObj.clear()


## 绘制
# 绘制射击射线（调试用）
func _draw() -> void:
	if detecframes > 0:
		var offset = offsetDir[wrapi(int(vector.angle() / (PI / 4)), 0, 8)]
		draw_line(offset, targetPos - global_position, Color.WHITE, 1.5)
