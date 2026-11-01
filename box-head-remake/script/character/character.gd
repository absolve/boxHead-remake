class_name Character
extends CharacterBody2D

## 角色基类
# 所有可移动角色（玩家和敌人）的基类
# 定义了角色的基本属性和状态管理


## 角色碰撞体大小
@export var bodySize: Vector2 = Vector2(20, 25)
## 当前血量
@export var hp: int = 10
## 移动速度
@export var speed: float = 120
## 转身动画速度（帧/秒；rotate 共 32 帧，4 帧 = 45°）
@export var turnFrameSpeed: float = 40.0
## 角色类型（Game.roleType枚举值）
@export var type: Game.roleType = Game.roleType.Player
## 最大血量
@export var maxHp: int = 10
## 命中特效要抬高多少像素
# 受击区（body Area2D）在脚下，但贴图是竖着画的，不补偿烟雾会落在脚底
@export var hitLift: float = 18.0
## 当前朝向角度（0-7，对应8个方向）
var angle: int = 0
## 上一次稳定下来的朝向（转身动画的起点）
var oldAngle: int = 0
## 当前动画名称
var currAni: String = ""
## 是否已死亡
var isDead: bool = false
## 致命伤后的“演出中”状态：血已扣光但还在播受击/击退，
## 演完才真正 die()（原版 State_BulletHit → CheckForDead → State_Dying）
var dying: bool = false

## 质量：击退距离 = 公式结果 / 质量（僵尸 1、玩家 2、恶魔按手感也用 1）
@export var mass: float = 1.0
## 是否处于无敌状态
var invincible: bool = false
## 当前状态（由子类定义具体状态枚举）
var state: int
## 上一帧状态
var lastState: int


## 碰撞形状节点（在_ready后获取）
@onready var shape: CollisionShape2D = $shape
## 动画节点（各角色场景都有同名子节点）
@onready var ani: AnimatedSprite2D = $ani


## 击退初速（px/s）
##
## 原版 `CThing_Creature.as:471-489`：
##   子弹/火球 max(dmg×2/5/32, 0.3) / mass
##   爆炸     min(dmg×2/5/32 / mass, 0.3)
func knockbackSpeed(dmg: int, fromExplosion: bool = false) -> float:
	var raw: float = float(dmg) * 2.0 / 5.0 / MapData.cellSize
	var cells: float
	if fromExplosion:
		cells = minf(raw / mass, 0.3)
	else:
		cells = maxf(raw, 0.3) / mass
	return cells * MapData.cellSize * MapData.TICKS_PER_SEC


## ---- 击退（连续衰减，视觉上是「快→慢」的滑行）----
##
## 原版：每 1/25 秒位移 mDelta，然后 mDelta *= 0.65（CThing_Creature.as:291-323）。
## 直接照搬 25Hz 在 60fps 下会变成"两三帧不动、然后跳一下"，看起来像瞬移固定距离。
## 这里用等价的连续指数衰减 v(t) = V0 · exp(-K t)，并让总位移与原版一致：
##   原版总位移 = step0 / (1 - 0.65) = 2.857 · step0（连续积分会略大，用 2.63 校正回等距）
##   连续积分   = V0 / K
##   → V0 = 2.857 · step0 · K
const KNOCKBACK_DECAY: float = 10.77          # 25 · ln(1/0.65)
const KNOCKBACK_TOTAL_FACTOR: float = 2.63
## 低于这个速度就认为击退结束（对应原版 mDelta 长度 < 0.01 格）
const KNOCKBACK_END_SPEED: float = 10.0

## 击退方向（单位向量）
var knockbackDir: Vector2 = Vector2.ZERO
## 当前击退速度（px/s）
var knockbackVel: float = 0.0
## 剩余时间 / 总时长（秒）
var knockbackTimeLeft: float = 0.0
var knockbackTotalTime: float = 0.0


## 开始一次击退（speed 是原版"每 tick 位移"换算出的 px/s）
func beginKnockback(dir: Vector2, speed: float) -> void:
	if dir == Vector2.ZERO or speed <= 0.0:
		clearKnockback()
		return
	knockbackDir = dir.normalized()
	var step0: float = speed / MapData.TICKS_PER_SEC
	knockbackVel = KNOCKBACK_TOTAL_FACTOR * step0 * KNOCKBACK_DECAY
	if knockbackVel <= KNOCKBACK_END_SPEED:
		clearKnockback()
		return
	knockbackTotalTime = log(knockbackVel / KNOCKBACK_END_SPEED) / KNOCKBACK_DECAY
	knockbackTimeLeft = knockbackTotalTime


## 每帧推进：返回这一帧要走的世界位移
func advanceKnockback(delta: float) -> Vector2:
	if knockbackVel <= KNOCKBACK_END_SPEED or knockbackDir == Vector2.ZERO:
		clearKnockback()
		return Vector2.ZERO
	var step: Vector2 = knockbackDir * knockbackVel * delta
	knockbackVel *= exp(-KNOCKBACK_DECAY * delta)
	knockbackTimeLeft = maxf(knockbackTimeLeft - delta, 0.0)
	if knockbackVel <= KNOCKBACK_END_SPEED:
		clearKnockback()
	return step


## 击退是否结束
func knockbackDone() -> bool:
	return knockbackVel <= KNOCKBACK_END_SPEED or knockbackTimeLeft <= 0.0


## 清空击退
func clearKnockback() -> void:
	knockbackDir = Vector2.ZERO
	knockbackVel = 0.0
	knockbackTimeLeft = 0.0
	knockbackTotalTime = 0.0


## 受击硬直时长（秒）
##
## 原版 State_BulletHit_Init 用击退衰减帧数当硬直，之后 State_Sleep 再 3 tick。
func hurtTimeFrom(knockFrames: int) -> float:
	return float(knockFrames) / MapData.TICKS_PER_SEC + 3.0 / MapData.TICKS_PER_SEC


## 把角色限制在地图内（击退/爆炸位移会瞬移出界，必须每一步都夹一次）
func clampInsideMap(margin: float = 8.0) -> void:
	var size: Vector2 = MapData.mapSize
	global_position = Vector2(
		clampf(global_position.x, margin, size.x - margin),
		clampf(global_position.y, margin, size.y - margin))


## 击退能不能走到 next：可玩区域边界 / 静态障碍 / 其他角色 都算挡住。
##
## 挡住时调用方应**停止击退**（不是贴着墙滑），这样不会把敌人挤进墙里、
## 也不会把敌人推出可玩区域。
func knockbackBlocked(next: Vector2, radius: float = -1.0) -> bool:
	if radius < 0.0:
		radius = bodyRadius()
	# 1) 可玩区域边界：出界就停（敌人在最边缘那一格就进不去了）
	if not MapData.getPlayRect().has_point(next):
		return true
	# 2) 静态障碍（墙 / 油桶 / 假墙都记在障碍格里）
	for dx in [-radius, 0.0, radius]:
		for dy in [-radius, 0.0, radius]:
			if MapData.isObstacle(MapData.worldToCell(next + Vector2(dx, dy))):
				return true
	# 3) 其他角色（敌人 / 玩家）
	for group in ["enemy", "player"]:
		for n in get_tree().get_nodes_in_group(group):
			if n == self or not is_instance_valid(n):
				continue
			if n.get("isDead") == true:
				continue
			var otherR: float = 14.0
			if n is Character:
				otherR = (n as Character).bodyRadius()
			if next.distance_to(n.global_position) < radius + otherR:
				return true
	return false


## 碰撞半径（子类覆盖：僵尸 14.4 / 恶魔 14 / 玩家按碰撞体）
func bodyRadius() -> float:
	return 14.0


## 是否已经进入地图范围。
##
## 敌人是在地图外面生成的（出生点在地图边界外，走进来），原版这段是
## State_EnterMap：清掉 mFlag_Collidable，**打不到**。
##
## 注意：这里必须用「地图实际范围」，不能用 getPlayRect()（那是相机边界，
## 比地图四周各内缩 32px）。出生点常在地图边缘 32px 以内，用相机矩形判断
## 会让贴边出生的敌人在整个 Spawn 阶段都处于"不可打"状态。
func isInsidePlay() -> bool:
	return Rect2(Vector2.ZERO, MapData.mapSize).has_point(global_position)
