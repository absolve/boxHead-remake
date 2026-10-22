class_name Zombie
extends "res://script/character/character.gd"

## 僵尸敌人脚本（状态机版本）
##
## 本脚本只保留"宿主能力"：数值、取目标、流场取方向、碰撞探测、转向、命中判定、
## 受伤与死亡。**具体行为已拆到 StateMachine 下的 6 个状态节点**：
## [code]Spawn / Chase / Turn / Attack / Hurt / Dead[/code]，
## 状态实现见 [code]script/zombie/states/*.gd[/code]。
##
## 方向约定（与原版 Boxhead 一致）：
## [code]angle[/code] 0..7 = 东、东南、南、西南、西、西北、北、东北，
## 即 [code]angle = round(向量角度 / 45°)[/code] 再绕回 [0, 8)。

## 8 个方向向量，顺序与 angle 一致：E, SE, S, SW, W, NW, N, NE
const DIRS: Array[Vector2] = [
	Vector2(1, 0),
	Vector2(1, 1),
	Vector2(0, 1),
	Vector2(-1, 1),
	Vector2(-1, 0),
	Vector2(-1, -1),
	Vector2(0, -1),
	Vector2(1, -1),
]

## 攻击伤害（原版 CThing_Creature_Zombie.mDamage = 50）
@export var damage: int = 50
## 攻击范围（像素）
# 原版是"正前方相邻格"直接扣血，1 格 = 32px，这里取略大于 1 格
@export var attackRange: float = 35.0
## 攻击判定帧（攻击动画的第几帧结算伤害）
@export var attackHitFrame: int = 2
## 两次挥击之间的间隔（秒）
# 原版没有独立冷却：攻击动画播到命中帧 + State_Sleep 的 10 tick(0.4s)
@export var attackDelay: float = 0.4
## 重新搜索目标的间隔（秒）
@export var targetRefreshInterval: float = 0.5
## 受击后减速恢复时间（秒）
@export var hurtDelay: float = 0.5
## 探测下一步是否可走的距离（像素）
@export var probeSize: Vector2 = Vector2(32, 32)
## 转身后至少要走这么久才允许再次转身（秒）
## 用来消除"站在两格交界、相邻两格方向不同"时原地反复 45° 打转
## 两次转身之间的最小间隔（秒）
##
## 0.08 太小，僵尸会在同一次走近障碍的过程中连转好几次；
## 0.3 跟原版 State_Turn（转一个 45° 约 0.2 秒）+ 目标保持一致。
@export var turnCooldown: float = 0.3

## 一个方向最少连续走几格才允许重新取流场方向（原版 minMoveGrid = 2）
## 没有它的话，站在两格交界处时相邻两格的流场方向不同，
## 每帧都会判成"朝向不对"→ 转身 → 再判 → 又转身，表现就是原地摇摆。
@export var minMoveGrid: int = 2

## 被挡住时先原地等待多久再换方向（秒）
##
## 对应原版 `State_Wait`：Nav_Direction() 返回 -1（完全无路）时
## `mStateCount = CMain.mFPS` = 25 帧 = **1 秒**，动画 stand，结束后回 GotoPlayer。
## 原版另有一个 1/3 秒的防抖停留（`State_Sleep`），用于"刚转完向又不对"。
const BLOCKED_WAIT: float = 1.0

## 前方被同伴挡住后，等多久才侧移绕行（秒）
##
## 同伴每帧都在动，"前方有人"会逐帧翻转；立刻反应就会来回摇摆。
const SIDESTEP_WAIT: float = 0.2

## 刚转完身、方向又不对时的防抖停留（秒）—— 原版 `CMain.mFPS / 3`
const TURN_RETRY_WAIT: float = 1.0 / 3.0

## 是否刚转完身（供 Chase 判断要不要防抖）
var justTurned: bool = false

## 防抖停留的剩余时间
var turnRetryTimer: float = 0.0

## 被挡住已经等了多久
var blockedTimer: float = 0.0

## 和别的僵尸挤在一起时的分离速度（px/s）
const SEPARATE_SPEED: float = 120.0

## 判定「还没贴上」的距离（px）：比这更近就允许挤过去，靠分离推力散开
const MIN_APPROACH_DISTANCE: float = 14.0

## 超过这个距离就不再主动分离（px）
## 只在「深度重叠」时才调整位置（像素）——碰撞已阻止新的穿透，
## 这个只负责把已经叠在一起的分开
const SEPARATE_DISTANCE: float = 12.0

## 自己当前登记的占用格（哨兵值表示还没登记）
var occCell: Vector2i = Vector2i(-9999, -9999)


## 当前追踪目标（玩家；保持无类型以便动态调用 hit()）
var target = null
## 上一次受击是否来自正面（决定播 hitFront 还是 hitRear）
var hitFromFront: bool = false
## 出生点（Spawn 状态要走到这里）
var initPos: Vector2 = Vector2.ZERO
## 击退衰减系数：每逻辑帧速度乘以它（原版 mDelta *= 0.65）
const KNOCKBACK_DECAY: float = 0.65

## 击退状态的最长时间（秒），防止低伤害时拖太久
const KNOCKBACK_MAX_TIME: float = 0.6

## 质量：影响被击退的距离（原版僵尸 mMass = 1）
@export var mass: float = 1.0

## 击退剩余时间（秒）；Hurt 状态在这段时间内持续后退
var knockbackTime: float = 0.0

## 目标刷新计时
var targetTimer: float = 0.0
## 当前承诺的移动方向（ZERO = 没有承诺）
var committedDir: Vector2 = Vector2.ZERO
## 做出承诺时所在的格子
var commitGrid: Vector2i = Vector2i.ZERO

## 状态机（zombie.tscn 里的 StateMachine 子节点）
@onready var fsm: StateMachine = $StateMachine
## 邻近检测区域（圆形，用于生物/物件的碰撞解算）
@onready var detect: Area2D = $detect
## 身体受击区域
@onready var body: Area2D = $body
## 身体受击形状
@onready var bodyShape: CollisionShape2D = $body/bodyShape
## 前进方向碰撞探测（判断下一步能不能走）
@onready var shapeCast: ShapeCast2D = $ShapeCast2D
@onready var attackSound: AudioStreamPlayer2D = $attackSound


func _ready() -> void:
	# 由 map.gd 在 add_child 前写入的出生方向速度，换算成初始朝向
	if velocity.length() != 0:
		angle = angleFromVector(velocity)
		oldAngle = angle
	targetTimer = 0.0
	target = findTarget()

	# 选初始状态：出生时（map.gd 写了 init）先走到出生点，否则直接追击
	var initial: StringName = &"Spawn" if state == Game.enemyState.init else &"Chase"
	fsm.start(initial)


# ---------------------------------------------------------------- 目标 / 坐标

## 找最近的玩家
func findTarget() -> Node2D:
	var best: Node2D = null
	var bestDis := INF
	for p in get_tree().get_nodes_in_group("player"):
		if p == null or not is_instance_valid(p):
			continue
		if p.get("isDead") == true:
			continue
		var dis: float = global_position.distance_squared_to(p.global_position)
		if dis < bestDis:
			bestDis = dis
			best = p
	return best


## 目标是否有效（存活、未被回收）
func hasTarget() -> bool:
	return target != null and is_instance_valid(target) and target.get("isDead") != true


## 按间隔刷新目标，避免每帧遍历玩家组
## @return 当前是否有目标
func refreshTarget(delta: float) -> bool:
	targetTimer -= delta
	if targetTimer <= 0.0 or not hasTarget():
		targetTimer = targetRefreshInterval
		target = findTarget()
	return hasTarget()


## 当前所在格坐标
func gridPosition() -> Vector2i:
	return Vector2i(floori(global_position.x / MapData.cellSize),
			floori(global_position.y / MapData.cellSize))


## 当前目标对应的流场 id（多玩家时每个玩家一张流场）
func targetId() -> int:
	if hasTarget() and target.get("playerId") != null:
		return int(target.playerId)
	return 1


# ---------------------------------------------------------------- 方向 / 转向

## 向量 → 朝向索引 0..7
static func angleFromVector(v: Vector2) -> int:
	if v == Vector2.ZERO:
		return 0
	return wrapi(int(round(v.angle() / (PI / 4.0))), 0, 8)


## 朝向索引 → 方向向量（已归一化）
static func vectorFromAngle(a: int) -> Vector2:
	return DIRS[wrapi(a, 0, 8)].normalized()


## 从自己指向目标的朝向索引
func dirToTarget() -> int:
	if not hasTarget():
		return angle
	return angleFromVector(target.global_position - global_position)


## 目标是否在攻击范围内
func targetInAttackRange() -> bool:
	if not hasTarget():
		return false
	var offset: Vector2 = target.global_position - global_position
	return offset.length_squared() <= attackRange * attackRange


## 是否朝着目标（±45° 容差）
##
## 原版要求方向索引完全相等，但玩家贴脸时 dirToTarget() 会在相邻两个
## 方向之间来回跳变（差几像素就换一格），导致 Chase/Attack 反复切到 Turn，
## 表现为僵尸原地摇摆。这里放宽到 ±1 个方向（45°），抖动就不再触发转身。
func isFacingTarget() -> bool:
	if not hasTarget():
		return false
	var diff := wrapi(dirToTarget() - angle, 0, 8)
	return diff <= 1 or diff >= 7


# ---------------------------------------------------------------- 移动 / 探测

## 下一步能否通过 —— 地形用格子判定，实物用 ShapeCast 探测
##
## ShapeCast 的探测长度固定为**半格**（cellSize / 2 = 16px），
## 正好覆盖"到下一个格子中心"的距离，不会探得太远导致误判。
func canStep(dir: Vector2) -> bool:
	if dir == Vector2.ZERO:
		return false
	var step := Vector2i(roundi(dir.normalized().x), roundi(dir.normalized().y))
	if step == Vector2i.ZERO:
		return false

	var cell := gridPosition()

	# 纯格子判定：地形障碍 + 别的僵尸占用的格子（原版 mCollide_NonMovable = 227）
	if isDirBlocked(cell, angleFromVector(dir)):
		return false
	return true

func sidestepAroundZombies(desired: Vector2) -> Vector2:
	if desired == Vector2.ZERO:
		return freeDirectionTowardsTarget()

	var cell := gridPosition()
	var best := Vector2.ZERO
	var bestDot := -INF
	for step in range(1, 5):
		for side in [1, -1]:
			var d: Vector2 = desired.rotated(side * step * PI / 4.0)
			var s := Vector2i(roundi(d.normalized().x), roundi(d.normalized().y))
			if s == Vector2i.ZERO:
				continue
			if not isCellFree(cell + s):
				continue
			var occ: Node = MapData.getZombieAt(cell + s)
			if occ != null and occ != self:
				continue
			var dot := d.normalized().dot(desired.normalized())
			if dot > bestDot:
				bestDot = dot
				best = d
		if best != Vector2.ZERO:
			break
	return best


## 当前格选定的移动方向 / 它是给哪一格算的
##
## 原版 `State_CellToCell` 走满一格才回 `GotoPlayer` 重算方向，
## 所以方向在「一格之内」保持不变——这正是它不会来回摇摆的原因。
var cellDir: Vector2 = Vector2.ZERO
var cellDirGrid: Vector2i = Vector2i(-9999, -9999)

## 转身后至少保持这个方向多久（秒）
##
## 对应原版：转完身要等 `State_Turn` 播完，方向又不对还会 `State_Sleep` 1/3 秒。
## 没有这个锁就会每帧按 ShapeCast 结果改方向 → 原地反复转。
const TURN_WAIT: float = 0.3

## 当前锁定的移动方向 / 锁剩余时间
var lockedDir: Vector2 = Vector2.ZERO
var turnLockTimer: float = 0.0


## 给方向加转向锁：锁定期内保持旧方向，到期才允许改
func applyTurnLock(dir: Vector2, delta: float) -> Vector2:
	if dir == Vector2.ZERO:
		return dir

	# 锁定期内：忽略新方向，继续走旧的
	if turnLockTimer > 0.0:
		turnLockTimer -= delta
		if lockedDir != Vector2.ZERO:
			return lockedDir
		return dir

	# 锁到期：方向确实变了才重新上锁
	if lockedDir == Vector2.ZERO or not lockedDir.is_equal_approx(dir):
		lockedDir = dir
		turnLockTimer = TURN_WAIT
	return dir


## 判定「已经走到格心」的容差（像素）
##
## `gridPosition()` 用的是 floori：僵尸一跨过格子边界，就被算成"在下一格"。
## 若这时立刻按新格子的流场转向，它其实还贴在上一个格子的边上，
## 一转向就撞墙 → 转不过去 → 反复转。
## 所以只有真正走到格心附近（±CELL_CENTER_TOL）才允许重算方向。
const CELL_CENTER_TOL: float = 6.0


## 卡住计时：连续多少秒几乎没移动
var stuckTimer: float = 0.0
var lastPhysPos: Vector2 = Vector2.ZERO


## 取当前格该走的方向；只有接近格心时才重算
func dirForCurrentCell() -> Vector2:
	# 卡住太久 → 强制允许重算（否则停在两格之间会永远不动）
	if stuckTimer >= BLOCKED_WAIT:
		stuckTimer = 0.0
		cellDir = Vector2.ZERO
		cellDirGrid = Vector2i(-9999, -9999)

	var cell := gridPosition()
	var nearCenter: bool = global_position.distance_to(MapData.cellCenter(cell)) <= CELL_CENTER_TOL

	# 没走到格心：沿用上一次的方向，不要因为"被判成下一格"就改主意
	if not nearCenter:
		if cellDir == Vector2.ZERO:
			# 首次进入还没有缓存，兜底算一次
			cellDirGrid = cell
			cellDir = chooseDirTowardsTarget()
		return cellDir

	# 到了格心：换格了才重算
	if cell == cellDirGrid and cellDir != Vector2.ZERO:
		return cellDir

	cellDirGrid = cell
	cellDir = chooseDirTowardsTarget()
	return cellDir


## 重算方向：流场优先，被挡就 ±45°..±180° 找一条能走的
func chooseDirTowardsTarget() -> Vector2:
	var want := flowDirection()
	if want != Vector2.ZERO and canStep(want):
		return want
	var fallback: Vector2 = want if want != Vector2.ZERO else vectorFromAngle(angle)
	return sidestepDirection(fallback)


## 作废当前格的方向缓存（等待超时 / 清承诺时用）
func invalidateCellDir() -> void:
	cellDir = Vector2.ZERO
	cellDirGrid = Vector2i(-9999, -9999)


## 前方格子里有没有别的僵尸挡着（用于移动闸门，不影响寻路）
##
## 对应原版 `State_WaitToMove`：前方格被生物占住就停下等，
## 等它走开或超过 1 秒再继续。这样僵尸会排队而不是互相硬推。
func isBlockedByZombie(dir: Vector2) -> bool:
	if dir == Vector2.ZERO:
		return false
	var step := Vector2i(roundi(dir.normalized().x), roundi(dir.normalized().y))
	if step == Vector2i.ZERO:
		return false
	var occupant: Node = MapData.getZombieAt(gridPosition() + step)
	return occupant != null and occupant != self


## 某个格子是否可走
##
## 原版 Nav_Direction 用的掩码 `mCollide_NonMovable` = 227
## = StaticImpassable | Creature | Object | Player，
## 也就是**既避地形也避同伴**（doc/02-pathfinding.md:314）。
func isCellFree(cell: Vector2i) -> bool:
	if MapData.isObstacle(cell):
		return false
	# 占用格判断（暂不启用）
	# var occupant: Node = MapData.getZombieAt(cell)
	# return occupant == null or occupant == self
	return true


## 按方向移动
func moveInDirection(dir: Vector2, delta: float) -> void:
	if dir == Vector2.ZERO:
		return
	velocity = dir.normalized() * speed
	var col := move_and_collide(velocity * delta)
	separateFrom(col, delta)


## 流场给的方向；若当前位置在障碍格内或流场没数据，则退化为"朝目标的自由方向"
func flowDirection() -> Vector2:
	var cell := gridPosition()
	if MapData.obstacle.has("%s-%s" % [cell.x, cell.y]):
		# 站在障碍格里（例如玩家把墙放在僵尸脚下）→ 必须先离开，不能原地卡死
		return freeDirectionTowardsTarget()

	var dir: Vector2 = MapData.getFlowDir(global_position, targetId())
	if dir == Vector2.ZERO:
		dir = freeDirectionTowardsTarget()
	return dir


## 在 8 个方向里挑一个"能走且最接近目标方向"的方向
func freeDirectionTowardsTarget() -> Vector2:
	var want := Vector2.ZERO
	if hasTarget():
		want = Vector2(target.global_position - global_position).normalized()
	if want == Vector2.ZERO:
		want = vectorFromAngle(angle)

	var best := Vector2.ZERO
	var bestDot := -INF
	for d in DIRS:
		if not canStep(d):
			continue
		var dot := d.normalized().dot(want)
		if dot > bestDot:
			bestDot = dot
			best = d

	# 八个方向都被判定为障碍 → 说明自己正卡在障碍格/墙角里，强行找个空格走出去
	if best == Vector2.ZERO:
		best = escapeDirection()
	return best


## 卡在障碍里时的脱困方向：取最近的可行空格
func escapeDirection() -> Vector2:
	var cell := gridPosition()

	# 半径 3 格内找最近的空格。
	# 只看 8 邻格是不够的：僵尸被挤进墙里时，8 个邻居可能全是墙，
	# 那样就返回 ZERO、永远贴在墙边——就是"一直靠墙"的那只。
	var bestCell := cell
	var bestDist := 1.0e9
	var found := false
	for r in range(1, 4):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var c: Vector2i = cell + Vector2i(dx, dy)
				if MapData.isObstacle(c):
					continue
				var d2: float = float(dx * dx + dy * dy)
				if d2 < bestDist:
					bestDist = d2
					bestCell = c
					found = true
		if found:
			break

	if not found:
		return Vector2.ZERO

	var to: Vector2 = MapData.cellCenter(bestCell) - global_position
	if to.length() < 0.5:
		return Vector2.ZERO
	return to.normalized()


## 期望方向被挡住时，左右各试 45°..180°，取"能走且偏离最小"的那个
func sidestepDirection(desired: Vector2) -> Vector2:
	if desired == Vector2.ZERO:
		return freeDirectionTowardsTarget()

	var best := Vector2.ZERO
	var bestDot := -INF
	for step in range(1, 5):
		for side in [1, -1]:
			var d: Vector2 = desired.rotated(side * step * PI / 4.0)
			if not canStep(d):
				continue
			var dot := d.normalized().dot(desired.normalized())
			if dot > bestDot:
				bestDot = dot
				best = d
		if best != Vector2.ZERO:
			# 同一偏角下已经找到可行方向，就不再扩大偏角
			break
	return best


# ---------------------------------------------------------------- 动画

## 播放某个动作在当前朝向下的动画
## kind: walk / stand / attack / hitFront / hitRear
## force = true 时强制从头重播（攻击/受击这种一次性动画要重播）
func playAnim(kind: String, force: bool = false) -> void:
	var animName := "%s_%d" % [kind, angle]
	if not ani.sprite_frames.has_animation(animName):
		animName = "stand_%d" % angle
		force = false
	if force or ani.animation != animName:
		ani.play(animName)


## 播放倒地方向（fallDown 只有 0..3 四个方向）
func playFallAnim() -> void:
	var animName := "fallDown_%d" % int(angle / 2.0)
	if ani.sprite_frames.has_animation(animName):
		ani.play(animName)


## 当前动画是否还在播
func isAnimPlaying() -> bool:
	return ani.is_playing()


# ---------------------------------------------------------------- 攻击 / 受伤

## 结算一次近战命中：范围内 + 朝向一致 才算命中
## 取代旧实现里按方向摆放 attackArea 的做法
## @return 是否命中
func dealDamage() -> bool:
	if not targetInAttackRange():
		return false
	if not isFacingTarget():
		return false
	if target.has_method("hit"):
		target.hit(damage, global_position, 20)
		#attackSound.play()
		return true
	return false


## 受伤入口（子弹/爆炸调用）
func hit(_damage: int, _attackPos: Vector2, recoil: float = 0) -> void:
	if isDead:
		return

	hp -= _damage

	if hp <= 0:
		die()
		return

	# 判断是否来自正面：攻击方向与当前朝向同侧
	var attackerDir := angleFromVector(_attackPos - global_position)
	var diff := wrapi(attackerDir - angle, 0, 8)
	hitFromFront = diff <= 1 or diff >= 7

	# 先切状态再设击退速度！
	# Chase.exit() 里有 velocity = Vector2.ZERO，先设速度会被它清掉。
	fsm.transitionTo(&"Hurt")

	# 击退：按原版公式算初速，之后由 Hurt 状态按 0.65/帧 衰减
	var s := knockbackSpeed(_damage, recoil <= 0 and _damage >= 100)
	knockbackTime = KNOCKBACK_MAX_TIME
	velocity = (global_position - _attackPos).normalized() * s


## 死亡：切到 Dead 状态并发出击杀信号
func die() -> void:
	isDead = true
	fsm.transitionTo(&"Dead")
	fsm.enabled = false
	Game.enemyKilled.emit(global_position)


## 供 Dead 状态调用：关闭碰撞与受击
func disableHitbox() -> void:
	body.monitorable = false
	body.monitoring = false
	bodyShape.disabled = true
	shape.disabled = true


# ---------------------------------------------------------------- Godot 内置

func _physics_process(_delta: float) -> void:
	# 与状态无关的公共处理：限制在地图内 + 按 Y 排序
	# 所有状态都要钳取（含 Spawn）：出生点都在地图内，
	# 不钳的话出生阶段的僵尸会走到地图外沿一直走。
	position.x = clampf(position.x, bodySize.x / 2.0, MapData.mapSize.x - bodySize.x / 2.0)
	position.y = clampf(position.y, bodySize.y / 2.0, MapData.mapSize.y - bodySize.y / 2.0)
	z_index = roundi(global_position.y / MapData.cellSize) + 1

	# 卡住检测：这一帧几乎没挪动就累加，动了就清零
	if global_position.distance_to(lastPhysPos) < 0.3:
		stuckTimer += _delta
	else:
		stuckTimer = 0.0
		lastPhysPos = global_position

	# 登记自己占用的格子，供别的僵尸避让
	if not isDead:
		updateOccupancy()
		resolveOverlap(_delta)


## 是否需要重新决策移动方向
# 三种情况需要：还没承诺过 / 已经走够 minMoveGrid 格 / 承诺的方向已经走不通
## 承诺方向的最长保持时间（秒）
##
## 被其他僵尸挤住时，格子判定仍然说「能走」，但物理上一步也挪不动，
## 于是永远走不满 minMoveGrid 格、永远不重新决策 → 一群僵尸卡在同一朝向。
## 超时后强制重算，至少能重新选方向/侧移。
const COMMIT_TIMEOUT: float = 0.5

## 当前承诺已经保持了多久（秒）
var commitTimer: float = 0.0

## 做出承诺时所处的位置（用于判断是否真的卡住没动）
var commitPos: Vector2 = Vector2.ZERO


func needNewDir(delta: float = 0.0) -> bool:
	commitTimer += delta
	if committedDir == Vector2.ZERO:
		return true
	var d := gridPosition() - commitGrid
	if maxi(absi(d.x), absi(d.y)) >= minMoveGrid:
		return true

	# 超时只在"格子里也没挪动"时才算数。
	# 分离推力会让像素位置一直抖动，用像素位移判断会误判成卡住 → 不停重算方向。
	if commitTimer >= COMMIT_TIMEOUT:
		if gridPosition() == commitGrid:
			return true

	return not canStep(committedDir)


## 承诺一个移动方向，并记下当前的格子和位置作为起点
func commitDir(dir: Vector2) -> void:
	committedDir = dir
	commitGrid = gridPosition()
	commitPos = global_position
	commitTimer = 0.0


## 每帧把自己从挤在一起的同伴身上推开
##
## move_and_collide 只能挡住新的穿透，解不开已经重叠的身体，
## 所以出生点一挤就会永远贴着。这里用自身 Area2D 找附近同伴，
## 每帧朝远离方向挪一点。
func resolveOverlap(delta: float) -> void:
	# body 默认 mask=0（只用来被子弹打中），这里让它也探测生物所在层
	if body.collision_mask != MapData.LAYER_ENEMY:
		body.collision_mask = MapData.LAYER_ENEMY

	var pushed := Vector2.ZERO
	for other in body.get_overlapping_bodies():
		if other == self or not (other is CharacterBody2D):
			continue
		var away: Vector2 = global_position - (other as Node2D).global_position
		var dist := away.length()
		if dist > SEPARATE_DISTANCE or dist < 0.01:
			continue
		pushed += away / dist

	if pushed == Vector2.ZERO:
		return
	move_and_collide(pushed.normalized() * SEPARATE_SPEED * delta)


## 取消承诺（进攻击/受击后要重新决策）
func clearCommit() -> void:
	committedDir = Vector2.ZERO
	justTurned = false
	turnRetryTimer = 0.0
	invalidateCellDir()


## 击退速度（px/s）—— 原版公式
##
## 子弹：max(damage/5*2 / cellSize, 0.3) / mass
## 爆炸：min(damage/5*2 / cellSize / mass, 0.3)
func knockbackSpeed(_damage: int, fromExplosion := false) -> float:
	var raw: float = float(_damage) * 2.0 / 5.0 / MapData.cellSize
	var cells: float
	if fromExplosion:
		cells = minf(raw / mass, 0.3)
	else:
		cells = maxf(raw, 0.3) / mass

	# 格/帧 -> px/s（速度不上限，保证高伤害武器依然「砰」得有力）
	return cells * MapData.cellSize * MapData.TICKS_PER_SEC


## 撞到别的僵尸时互相轻推，把已经重叠的分开
##
## move_and_collide 只能阻止新的穿透，不能把已经叠在一起的分开，
## 所以出生点一挤就会永远贴着。这里每帧给一点分离速度。
func separateFrom(col: KinematicCollision2D, delta: float) -> void:
	if col == null:
		return
	var other := col.get_collider()
	if not (other is Node2D):
		return
	var away: Vector2 = global_position - (other as Node2D).global_position
	if away.length() < 0.01:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	# 挤得越近推得越狠
	move_and_collide(away.normalized() * SEPARATE_SPEED * delta)


## 维护自己占用的格子（供别的僵尸避让）
func updateOccupancy() -> void:
	var cell := gridPosition()
	if cell == occCell:
		return
	if occCell != Vector2i(-9999, -9999):
		MapData.clearZombieCell(occCell, self)
	occCell = cell
	MapData.setZombieCell(cell, self)


## 离开场景时注销占用，避免留下幽灵占位
func _exit_tree() -> void:
	if occCell != Vector2i(-9999, -9999):
		MapData.clearZombieCell(occCell, self)

# ================================================================ 导航（照搬参考项目）
#
# 只在「流场方向被挡」时才换向；不按格子/时间重算方向。
# 这是 godot4flow-field/script/enemy.gd 的做法，不会来回摇摆。

## 0 = 跟随流场，1 = 被挡后自主找路
var navState: int = 0
## 当前实际移动方向（持久保存，被挡才会变）
var currDir: Vector2 = Vector2.ZERO
## 上一次记录的格子（用于判断走了 minMoveGrid 格）
var lastNavGrid: Vector2i = Vector2i(-9999, -9999)


## 选方向：返回归一化方向；无路可走返回 ZERO
func inNavBounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 \
		and cell.x < int(MapData.mapSize.x / MapData.cellSize) \
		and cell.y < int(MapData.mapSize.y / MapData.cellSize)


## 彻底找不到方向时的兜底：随机挑一个可走的方向
##
## 原版僵尸不会站着不动——它会到处乱走。没有这个兜底，
## 出生点被围住 / 流场没算好时，僵尸就会永远杵在原地。
func wanderDir() -> Vector2:
	var cell := gridPosition()
	var options: Array = []
	for d in DIRS:
		var step := Vector2i(roundi(d.normalized().x), roundi(d.normalized().y))
		# 只用格子判定：canStep 走 ShapeCast，一群僵尸围着时会 8 向全挡，
		# 反而一个方向都挑不出来 → 站着不动。
		if MapData.isObstacle(cell + step):
			continue
		options.append(d.normalized())
	if options.is_empty():
		return Vector2.ZERO
	return options[randi() % options.size()]


# ================================================================ 原版导航
# 依据 2P/CMap_Cell.as:280-538：Nav_Direction 三段式 + 8 向位掩码

## 方向索引 -> 格子步进
static func dirStep(d: int) -> Vector2i:
	var v: Vector2 = DIRS[wrapi(d, 0, 8)]
	return Vector2i(roundi(v.x), roundi(v.y))


## 某格是否被墙/物件/别的僵尸占着（原版 mCollide_NonMovable = 227）
func isNavBlocked(cell: Vector2i) -> bool:
	if MapData.isObstacle(cell):
		return true
	return MapData.isReservedByOther(cell, self)


## 方向 d 是否可走（斜向还要两侧正交格都通，原版 NavReal_d 的 OR 语义）
func isDirBlocked(cell: Vector2i, d: int) -> bool:
	var step: Vector2i = dirStep(d)
	if isNavBlocked(cell + step):
		return true
	if step.x != 0 and step.y != 0:
		if isNavBlocked(cell + Vector2i(step.x, 0)):
			return true
		if isNavBlocked(cell + Vector2i(0, step.y)):
			return true
	return false


## 走一格的时长（秒）：正交 cellSize/speed，对角 1.4142 倍
func cellTravelTime(d: int) -> float:
	var step: Vector2i = dirStep(d)
	var factor: float = 1.4142135623730951 if (step.x != 0 and step.y != 0) else 1.0
	return factor * MapData.cellSize / maxf(speed, 0.01)


## 原版 Nav_Direction：①目标方向 ②当前方向 ③按距离升序全扫描
func navDirection(cDir: int, tDir: int) -> int:
	var cell := gridPosition()
	var myDist: int = MapData.navDistAt(cell)

	# ① 目标方向更近且可走
	if myDist < 0 or MapData.navDistAt(cell + dirStep(tDir)) < myDist:
		if not isDirBlocked(cell, tDir):
			return tDir

	# ② 当前方向可走 → 保持（防抖核心）
	if not isDirBlocked(cell, cDir):
		return cDir

	# ③ 按距离升序全扫描
	var best := -1
	var bestDist := 1 << 30
	for d in range(8):
		if isDirBlocked(cell, d):
			continue
		var nd: int = MapData.navDistAt(cell + dirStep(d))
		if nd < 0:
			nd = 1 << 20
		if nd < bestDist:
			bestDist = nd
			best = d
	return best


## 清掉可能的缓存（当前实现无缓存，保留接口）
func clearNavCache() -> void:
	pass


# ================================================================ 击退 / 位置修正
# 依据原版 CMap_Collide.as:69-94 (CreatureCollide) 与 CThing_Creature.as:271-320

## 已预留的目标格（原版 SetCollideDirection 的作用点）
var reservedCell: Vector2i = Vector2i(-9999, -9999)

## 击退位移（每帧衰减 0.65，原版 mDelta）
var knockbackDelta: Vector2 = Vector2.ZERO

## 击退剩余帧数（原版 mStateCount）
var knockbackFrames: int = 0


## 对应原版 ClearCollideCell：受击时释放自己占的格子
func clearReservation() -> void:
	if reservedCell != Vector2i(-9999, -9999):
		MapData.releaseCell(reservedCell, self)
		reservedCell = Vector2i(-9999, -9999)


## 原版 State_BulletHit_Init：由击退初速算出衰减帧数
func beginKnockback(dir: Vector2, speed: float) -> void:
	knockbackDelta = dir.normalized() * speed / MapData.TICKS_PER_SEC / MapData.TICKS_PER_SEC
	knockbackFrames = 0
	var l: float = knockbackDelta.length()
	while l >= 0.01:
		knockbackFrames += 1
		l *= 0.65
	if MapData.isObstacle(gridPosition()):
		knockbackDelta = Vector2.ZERO


## 对应原版 CreatureCollide：圆形位置修正
## 先解开与其它生物的圆重叠，再处理与墙的碰撞，最多迭代 2 次
func creatureCollide(pos: Vector2) -> Vector2:
	var radius: float = 14.4      # 原版 SetRadius(0.45) × 32
	for i in range(2):
		var before := pos
		pos = resolveCreatureOverlap(pos, radius)
		var col := move_and_collide(pos - before, true)
		if col == null:
			break
		pos = before + (pos - before).slide(col.get_normal())
	return pos


## 两圆相交就沿连线推开（半径相同 → 各推一半）
func resolveCreatureOverlap(pos: Vector2, radius: float) -> Vector2:
	# 原版 GetCellList_Area：只查附近的对象（这里用 detect Area2D 圆）
	# 半径 32 覆盖 2×14.4 的相切距离 + 一格余量
	var near: Array = []
	if detect != null:
		near = detect.get_overlapping_bodies()
	else:
		near = get_tree().get_nodes_in_group("enemy")

	var self_offset: Vector2 = global_position - pos
	for other in near:
		if other == self or not (other is Character):
			continue
		var c := other as Character
		if c.isDead:
			continue
		var other_pos: Vector2 = c.global_position + self_offset
		var d: Vector2 = pos - other_pos
		var dist := d.length()
		var min_dist: float = radius * 2.0
		if dist < min_dist and dist > 0.01:
			# 原版 Collide_Mapwho：把重叠量**完整**推出去
			pos += d / dist * (min_dist - dist)

	# ---- 与物件（油桶 / 假墙）的圆形碰撞，对应原版 Collide_Map 里的物件部分
	# 这些是 Area2D，move_and_collide 碰不到，必须单独解算
	if detect != null:
		for area in detect.get_overlapping_areas():
			var sn := area.get_node_or_null("shape") as CollisionShape2D
			if sn == null or sn.shape == null:
				continue
			var ctr: Vector2 = sn.global_position + self_offset
			var other_r := 0.0
			if sn.shape is CircleShape2D:
				other_r = (sn.shape as CircleShape2D).radius
			elif sn.shape is RectangleShape2D:
				var sz := (sn.shape as RectangleShape2D).size
				other_r = maxf(sz.x, sz.y) * 0.5
			if other_r <= 0.0:
				continue
			var d2: Vector2 = pos - ctr
			var dist2 := d2.length()
			var min_d2: float = radius + other_r
			if dist2 < min_d2 and dist2 > 0.01:
				pos += d2 / dist2 * (min_d2 - dist2)
	return pos
