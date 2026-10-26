extends "res://script/weapon/weapon.gd"

## 霰弹枪脚本
# 继承自weapon.gd，实现霰弹枪的散射射击逻辑
# 一次发射多发子弹，呈扇形散射


## WideShot 升级等级
##
## 原版 `CThing_Weapon_Shotgun.as:71-80`：
##   中心 1 发 + 左右各 (wideShot+1) 对，角度步长 1.25° × (wideShot+1)
##   0 级：±1.25°            → 3 发
##   1 级：±2.5° / ±5°       → 5 发
##   2 级：±3.75° / ±7.5°    → 5 发
## 三发都能打中同一个目标（贴脸 51×3 = 153，一枪秒 100hp 僵尸）。
@export var wideShot: int = 0


## 每颗弹丸的角度（度，相对瞄准方向）
##
## 原版 `while(_loc3_ <= (!mWideShot ? 0 : 1))`：0 级循环 1 次（±1.25°），
## 1/2 级循环 2 次（±step、±2·step），step = 1.25 × (wideShot+1)。
## 所以弹丸总数是 3 / 5 / 5，不是 3 / 5 / 7。
func pelletAngles() -> Array:
	var out: Array = [0.0]
	var step: float = 1.25 * float(wideShot + 1)
	var pairs: int = 1 if wideShot == 0 else 2
	for k in range(pairs):
		var ang: float = step * float(k + 1)
		out.append(-ang)
		out.append(ang)
	return out


## 每颗子弹是否命中（false = 飞到最大射程）
var hitFlags: Array = []

## 每颗子弹唯一的命中点（世界坐标）
# 命中时是命中点，未命中时是该子弹的射线终点；绘制、烟雾全部用它
var targetPosList: Array = []

## 每颗弹丸的散射方向（绘制曳光用，和判定无关）
var spreadDirList: Array = []

## 本轮齐射是否已经结算过伤害（detecframes 有 2 帧，只结算第一帧）
var hitApplied: bool = false


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

	# 初始化射线终点列表（按最大弹丸数预留）
	for i in range(5):
		targetPosList.append(Vector2.ZERO)
		hitFlags.append(false)


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
		hitApplied = false


## 物理帧更新
# 在射击后的detecframes帧内持续检测所有子弹的碰撞
func _physics_process(_delta: float) -> void:
	if detecframes > 0:
		detecframes -= 1

		var spaceState = get_world_2d().direct_space_state
		# 所有弹丸共用同一个枪口 / 判定起点
		var muzzle: Vector2 = muzzleOffset(vector)
		var rayFrom: Vector2 = hitOrigin()
		var angles: Array = pelletAngles()
		var applyDamage: bool = not hitApplied
		hitApplied = true
		var reach: float = float(wRange) + muzzle.length()

		for i in range(angles.size()):
			# 每颗弹丸自己的方向（原版只有固定角度，没有随机散布）
			var spread: Vector2 = vector.rotated(deg_to_rad(float(angles[i])))
			var rayTo: Vector2 = rayFrom + spread * reach
			if i < spreadDirList.size():
				spreadDirList[i] = spread
			else:
				spreadDirList.append(spread)

			var query = PhysicsRayQueryParameters2D.create(rayFrom, rayTo, collisionMask)
			query.collide_with_areas = true
			query.exclude = [ownerId]
			var result = spaceState.intersect_ray(query)

			targetPosList[i] = rayTo
			hitFlags[i] = false
			if result:
				targetPosList[i] = result.position
				if result.collider is StaticBody2D:
					targetPosList[i] += Vector2(0, -resolveHitLift(result.collider))
					hitFlags[i] = true
					addSmoke(targetPosList[i])
				elif result.collider.get("type") and result.collider.type in [Game.itemType.Barrel,
								Game.itemType.Wall]:
					# 每颗弹丸独立结算（原版就是 3 个独立 bullet）
					if applyDamage:
						result.collider.hit(damage)
					targetPosList[i] += Vector2(0, -resolveHitLift(result.collider))
					hitFlags[i] = true
					addSmoke(targetPosList[i])
				elif result.collider is Area2D:
					if result.collider.owner.type and result.collider.owner.type in [Game.roleType.Player,
						Game.roleType.Zombie, Game.roleType.Devil]:
						var friendly: bool = result.collider.owner.type == Game.roleType.Player \
								and not MapData.friendlyFireOn()
						# 每颗弹丸独立判定：贴脸 3 发全中 = 153 伤害
						if applyDamage and not friendly:
							result.collider.owner.hit(damage, result.position, spread)
						targetPosList[i] += Vector2(0, -resolveHitLift(result.collider))
						hitFlags[i] = true
						addSmoke(targetPosList[i])

		# 没打中的弹丸：若飞出地图，在边界落点冒烟
		for i in range(angles.size()):
			if i < hitFlags.size() and not hitFlags[i] and outOfPlayArea(targetPosList[i]):
				addSmoke(noHitSmokePos(targetPosList[i]))

		queue_redraw()


## 绘制
# 绘制所有霰弹射线（调试用）
func _draw() -> void:
	if detecframes <= 0:
		return
	# 起点都是同一个枪口，终点是每颗子弹自己的 targetPos
	var muzzle: Vector2 = muzzleOffset(vector)
	for i in range(targetPosList.size()):
		var dir: Vector2 = spreadDirList[i] if i < spreadDirList.size() else vector
		draw_line(muzzle, tracerEnd(muzzle, dir, targetPosList[i]), Color.WHITE, 1)
