extends "res://script/weapon/weapon.gd"

## 轨道炮脚本
# 继承自weapon.gd，实现轨道炮的射击逻辑
# 使用Area2D射线检测实现穿透射击，伤害较高


## 唯一的命中点（世界坐标）
# 命中时是命中点，未命中时是射线终点；绘制全部用它
var targetPos: Vector2 = Vector2.ZERO


## 动画节点
@onready var ani: AnimatedSprite2D = $ani

## 玩家精灵节点（用于播放射击动画）
@onready var player: AnimationPlayer = $player

## 射线检测节点
@onready var ray: Area2D = $ray


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


## 射击
# 开始射击流程，消耗弹药，设置射击方向和状态
# @param direction 射击方向（Vector2）
func fire(direction: Vector2) -> void:
	if ammoNum <= 0:
		return
	if canShoot:
		detecframes = 2
		vector = direction
		ammoNum -= 1
		canShoot = false
		timer.start(delay)

		# 武器贴图摆位仍用 offsetDir
		ani.position = offsetDir[wrapi(int(vector.angle() / (PI / 4)), 0, 8)]
		ani.rotation = vector.angle()
		player.play("fire")
		sound.play()

		# 枪口 = 贴图偏移（8 方向各自的 offsetDir）；Area2D 射线、绘制、终点都从它出发
		var idx: int = wrapi(int(vector.angle() / (PI / 4)), 0, 8)
		var muzzle: Vector2 = offsetDir[idx]
		ray.rotation = vector.angle()
		ray.position = muzzle

		# 终点 = 枪口 + 同方向延长（方向严格等于 vector）
		targetPos = global_position + muzzle + vector * wRange
		excludeObj.clear()


## 物理帧更新
# 在射击后的detecframes帧内持续检测碰撞
func _physics_process(_delta: float) -> void:
	if detecframes > 0:
		detecframes -= 1

		# 获取射线重叠的所有区域（ray 的位置/朝向已在 fire() 里对齐枪口）
		var r = ray.get_overlapping_areas()
		if r:
			for i in r:
				if i.get("type")  and  i.type in [Game.itemType.Barrel,
									Game.itemType.Wall]:
					if not excludeObj.has(i.get_rid()):
						i.hit(damage)
						excludeObj.append(i.get_rid())
				elif i.owner.type  and  i.owner.type in [Game.roleType.Player,
					Game.roleType.Zombie, Game.roleType.Devil]:
					if not excludeObj.has(i.get_rid()):
						i.owner.hit(damage, global_position, hitFeedback)
						excludeObj.append(i.get_rid())

		queue_redraw()


## 绘制
# 绘制射击射线（调试用）
func _draw() -> void:
	if detecframes <= 0:
		return
	# 起点是枪口（局部坐标），终点是唯一的 targetPos 换算回局部坐标
	var idx: int = wrapi(int(vector.angle() / (PI / 4)), 0, 8)
	var muzzle: Vector2 = offsetDir[idx]
	draw_line(muzzle, targetPos - global_position, Color.BLUE_VIOLET, 3)
