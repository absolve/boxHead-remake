extends "res://script/weapon/weapon.gd"

## 霰弹枪脚本
# 继承自weapon.gd，实现霰弹枪的散射射击逻辑
# 一次发射多发子弹，呈扇形散射


## 霰弹数量
var bulletNum: int = 4

## 霰弹散射最大角度（度）
var splitAngle: float = 30.0

## 每颗子弹是否命中（false = 飞到最大射程）
var hitFlags: Array = []

## 每颗子弹唯一的命中点（世界坐标）
# 命中时是命中点，未命中时是该子弹的射线终点；绘制、烟雾全部用它
var targetPosList: Array = []


## 动画节点
@onready var ani: AnimatedSprite2D = $ani

## 玩家精灵节点（用于播放射击动画）
@onready var player: AnimationPlayer = $player


## 初始化
func _ready() -> void:
	# 设置8个方向的武器偏移量（同时作为枪口位置）
	offsetDir[0] = Vector2(45, -15)
	offsetDir[1] = Vector2(20, 0)
	offsetDir[2] = Vector2(-10, 10)
	offsetDir[3] = Vector2(-35, -5)
	offsetDir[4] = Vector2(-40, -35)
	offsetDir[5] = Vector2(-18, -45)
	offsetDir[6] = Vector2(15, -50)
	offsetDir[7] = Vector2(40, -35)

	# 初始化射线终点列表
	for i in range(bulletNum):
		targetPosList.append(Vector2.ZERO)


## 射击
# 开始射击流程，消耗弹药，设置射击方向和状态
# @param direction 射击方向（Vector2）
func fire(direction: Vector2) -> void:
	if ammoNum <= 0:
		return
	if canShoot:
		ammoNum -= 1
		detecframes = 2
		vector = direction
		canShoot = false
		timer.start(delay)

		ani.position = offsetDir[wrapi(int(vector.angle() / (PI / 4)), 0, 8)]
		ani.rotation = vector.angle()
		player.play("fire")
		sound.play()
		excludeObj.clear()


## 物理帧更新
# 在射击后的detecframes帧内持续检测所有子弹的碰撞
func _physics_process(_delta: float) -> void:
	if detecframes > 0:
		detecframes -= 1

		var spaceState = get_world_2d().direct_space_state
		var idx: int = wrapi(int(vector.angle() / (PI / 4)), 0, 8)
		# 所有子弹共用同一个枪口 / 射线起点
		var muzzle: Vector2 = offsetDir[idx]
		var rayFrom: Vector2 = global_position + muzzle

		for i in range(bulletNum):
			# 每颗子弹自己的散射方向（带随机偏移），射线方向严格按它延长
			var spread: Vector2 = vector.rotated(deg_to_rad(
					-splitAngle / 2 + i * splitAngle / bulletNum + randi_range(-2, 2)))
			var rayTo: Vector2 = rayFrom + spread * wRange

			# 创建射线查询
			var query = PhysicsRayQueryParameters2D.create(rayFrom, rayTo, collisionMask)
			query.collide_with_areas = true
			query.exclude = [ownerId]
			var result = spaceState.intersect_ray(query)

			targetPosList[i] = rayTo
			if result:
				targetPosList[i] = result.position
				if result.collider is StaticBody2D:
					targetPosList[i] += Vector2(0, -resolveHitLift(result.collider))
					hitFlags[i] = true
					addSmoke(targetPosList[i])
				elif result.collider.get("type")  and  result.collider.type in [Game.itemType.Barrel,
								Game.itemType.Wall]:
					if not excludeObj.has(result.collider_id):
						result.collider.hit(damage)
						excludeObj.append(result.collider_id)
					targetPosList[i] += Vector2(0, -resolveHitLift(result.collider))
					hitFlags[i] = true
					addSmoke(targetPosList[i])
				elif result.collider is Area2D:
					if result.collider.owner.type  and  result.collider.owner.type in [Game.roleType.Player,
						Game.roleType.Zombie, Game.roleType.Devil]:
						if not excludeObj.has(result.collider_id):
							result.collider.owner.hit(damage, result.position, hitFeedback)
							excludeObj.append(result.collider_id)
						targetPosList[i] += Vector2(0, -resolveHitLift(result.collider))
						hitFlags[i] = true
						addSmoke(targetPosList[i])

		# 没打中的子弹：若飞出地图，在边界落点冒烟
		for i in range(bulletNum):
			if i < hitFlags.size() and not hitFlags[i] and outOfPlayArea(targetPosList[i]):
				addSmoke(noHitSmokePos(targetPosList[i]))

		queue_redraw()


## 绘制
# 绘制所有霰弹射线（调试用）
func _draw() -> void:
	if detecframes <= 0:
		return
	# 起点都是同一个枪口，终点是每颗子弹自己的 targetPos
	var idx: int = wrapi(int(vector.angle() / (PI / 4)), 0, 8)
	var muzzle: Vector2 = offsetDir[idx]
	for i in range(targetPosList.size()):
		draw_line(muzzle, targetPosList[i] - global_position, Color.WHITE, 1)
