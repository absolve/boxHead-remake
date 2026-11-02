extends "res://script/weapon/weapon.gd"

## UZI冲锋枪脚本
# 继承自weapon.gd，实现UZI的连发射击逻辑
# 与手枪类似，但支持自动连射，射速更快


## 唯一的命中点（世界坐标）
# 命中时是命中点，未命中时是射线终点；绘制、烟雾全部用它
var targetPos: Vector2 = Vector2.ZERO


## 动画节点
@onready var ani: AnimatedSprite2D = $ani
## 玩家精灵节点（用于播放射击动画）
@onready var player: AnimationPlayer = $player


## 初始化
func _ready() -> void:
	# 8 方向枪口 = 原版 XSI 枪口锚点（uzistand，16 方向取 dir = angle×2）+ 脚底锚点偏移 (0,3)
	# 重生成：doc/tools/gen_offset_dir.py；推导记于 doc/xsi-sprite-skins.md §8
	offsetDir[0] = Vector2(27, -12)
	offsetDir[1] = Vector2(11, -1)
	offsetDir[2] = Vector2(-11, 0)
	offsetDir[3] = Vector2(-26, -11)
	offsetDir[4] = Vector2(-27, -27)
	offsetDir[5] = Vector2(-11, -38)
	offsetDir[6] = Vector2(11, -38)
	offsetDir[7] = Vector2(26, -27)


## 射击
# 开始射击流程，消耗弹药，设置射击方向和状态
# @param v 射击方向（Vector2）
func fire(v: Vector2) -> void:
	if ammoNum <= 0:
		return
	if canShoot:
		ammoNum -= 1
		detecframes = 2
		vector = v
		canShoot = false
		timer.start(delay)

		ani.position = offsetDir[dirIdx(vector)]
		ani.rotation = vector.angle()
		player.play("fire")
		sound.play()
		excludeObj.clear()


## 物理帧更新
# 在射击后的detecframes帧内持续检测碰撞
func _physics_process(_delta: float) -> void:
	if detecframes > 0:
		detecframes -= 1

		var spaceState = get_world_2d().direct_space_state
		# 枪口（局部坐标）→ 射线起点（世界坐标）→ 射线终点：方向严格等于 vector
		var rayFrom: Vector2 = hitOrigin()
		var rayTo: Vector2 = hitEnd(vector)

		# 创建射线查询
		var query = PhysicsRayQueryParameters2D.create(rayFrom, rayTo, collisionMask)
		query.collide_with_areas = true
		query.exclude = [ownerId]
		var result = spaceState.intersect_ray(query)

		targetPos = rayTo
		if result:
			targetPos = result.position
			if result.collider is StaticBody2D:
				targetPos += Vector2(0, -resolveHitLift(result.collider))
				addSmoke(targetPos)
			elif result.collider.get("type")  and  result.collider.type in [Game.itemType.Barrel,
								Game.itemType.Wall]:
				if not excludeObj.has(result.collider_id):
					result.collider.hit(damage)
					excludeObj.append(result.collider_id)
				targetPos += Vector2(0, -resolveHitLift(result.collider))
				addSmoke(targetPos)
			elif result.collider is Area2D:
				if result.collider.owner.type  and  result.collider.owner.type in [Game.roleType.Player,
					Game.roleType.Zombie, Game.roleType.Devil]:
					# friendlyFire 关闭时玩家之间互不伤害
					var friendly: bool = result.collider.owner.type == Game.roleType.Player \
							and not MapData.friendlyFireOn()
					if not friendly and not excludeObj.has(result.collider_id):
						result.collider.owner.hit(damage, result.position, vector)
						excludeObj.append(result.collider_id)
					targetPos += Vector2(0, -resolveHitLift(result.collider))
					addSmoke(targetPos)

		queue_redraw()


## 绘制
# 绘制射击射线（调试用）
func _draw() -> void:
	if detecframes <= 0:
		return
	# 起点是枪口（局部坐标），终点是唯一的 targetPos 换算回局部坐标
	var muzzle: Vector2 = muzzleOffset(vector)
	draw_line(muzzle, tracerEnd(muzzle, vector, targetPos), Color.WHITE, 1.5)
