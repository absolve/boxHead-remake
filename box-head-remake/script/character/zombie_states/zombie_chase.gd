extends State

## Chase —— 按原版 Boxhead 还原（2P/CThing_Creature.as:159-181 + CMap_Cell.as:280-335）
##
## 原版核心：
##   · 一次只走**一格**，耗时 1/mSpeed 帧（正交 50 帧=2s，对角 71 帧≈2.84s）
##   · 走的全过程中方向固定，**绝不中途改向**
##   · 到达后吸附格心，再重新决策
## 决策：① 目标方向更近且可走 → 用它
##       ② 当前方向可走 → 保持（不抖动的关键）
##       ③ 按距离升序全扫描，取第一个可走方向
##       ④ 都不行 → 站 1 秒（State_Wait）


var z: Zombie:
	get:
		return actor as Zombie

## 是否正在走一格
var moving: bool = false
var moveTimer: float = 0.0
var moveDuration: float = 1.0
var moveFrom: Vector2 = Vector2.ZERO
var moveTo: Vector2 = Vector2.ZERO
## 无路时的等待计时
var waitTimer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	waitTimer = 0.0
	# 原版走到 State_GotoPlayer 时设置 mFlag_Collidable：进入可玩区才能被打
	z.setHittable(true)


func exit() -> void:
	z.velocity = Vector2.ZERO
	cancelMove()


func physicsUpdate(delta: float) -> void:
	if z.isDead:
		return

	# 目标丢失 → 乱走（原版无此分支，这里避免玩家死后全体站桩）
	if not z.refreshTarget(delta):
		wanderFallback(delta)
		return

	# 卡在障碍格里（被击退推进墙 / 出生点压墙）→ 先直线挪到最近空格再说
	# 对应原版：Collide_Map 两个轴都堵时原地不动，靠下一次 Nav_Direction 找路脱困
	# 只有真的卡住（1 秒几乎没动）才脱困；否则被障碍围住时会一直"飘"
	if MapData.isObstacle(z.gridPosition()) and z.stuckTimer >= 1.0:
		var esc: Vector2 = z.escapeDirection()
		if esc != Vector2.ZERO:
			z.global_position = z.global_position.move_toward(
					z.global_position + esc * MapData.cellSize, z.speed * delta)
			z.playAnim("walk")
			return

	# 攻击距离内且朝向对 → 打
	if z.targetInAttackRange():
		cancelMove()
		z.claimCurrentCell()   # 停下打人了，也要占着脚下这格
		if z.isFacingTarget():
			stateMachine.transitionTo(&"Attack")
		else:
			stateMachine.transitionTo(&"Turn", {"to": z.dirToTarget(), "next": "Attack"})
		return

	# ---- 正在走一格：期间不改方向
	if moving:
		moveTimer += delta
		var t: float = clampf(moveTimer / moveDuration, 0.0, 1.0)
		z.global_position = moveFrom.lerp(moveTo, t)
		z.playAnim("walk")
		if t >= 1.0:
			finishMove()
		return

	# ---- 到达格心，重新决策
	var cell: Vector2i = z.gridPosition()
	var cDir: int = z.angle
	var tDir: int = Zombie.angleFromVector(z.target.global_position - z.global_position)
	var d: int = z.navDirection(cDir, tDir)

	if d == -1:
		# 原版 State_Wait：八个方向都不通就站 1 秒，**不移动**
		# （旧实现在这里朝最近空格挪，导致被围住时僵尸一直飘走）
		waitTimer += delta
		z.velocity = Vector2.ZERO
		z.playAnim("stand")
		if waitTimer >= 1.0:
			waitTimer = 0.0
		return
	waitTimer = 0.0
	# 朝向不对 → 先转身（Turn 结束后 next=Chase，会重新进来）
	# 原版 SetState_WithDirection_Wait：刚转完身又不对 → 先 Sleep，避免反复转
	if d != cDir:
		if z.justTurned:
			z.justTurned = false
			stateMachine.transitionTo(&"Sleep", {"next": "Chase", "time": Zombie.TURN_RETRY_WAIT})
			return
		stateMachine.transitionTo(&"Turn", {"to": d, "next": "Chase"})
		return

	# 走起来了 → 说明「刚转完身」这段已经过去，清掉防抖标记
	# （原版用 mReturnStateID == State_Turn 判断，只在转完的下一帧生效）
	z.justTurned = false
	startMove(cell, d)


## 开始走一格：预留目标格并按时长插值
func startMove(cell: Vector2i, d: int) -> void:
	var step: Vector2i = Zombie.dirStep(d)
	var nextCell: Vector2i = cell + step

	# 目标格已被别的僵尸抢先占住 → 这一帧不走（下一帧重新决策）
	if MapData.isReservedByOther(nextCell, z):
		return
	# 原版 SetCollideDirection：**先释放旧格，再占目标格** → 移动期间只占 1 格
	if z.reservedCell != Vector2i(-9999, -9999) and z.reservedCell != nextCell:
		MapData.releaseCell(z.reservedCell, z)
	MapData.reserveCell(nextCell, z)
	z.reservedCell = nextCell
	z.moveTargetCell = nextCell

	moveFrom = z.global_position
	moveTo = MapData.cellCenter(nextCell)
	moveDuration = z.cellTravelTime(d)
	moveTimer = 0.0
	moving = true
	# 同步 velocity：受击方向、音效等外部逻辑依赖它（位置本身是插值移动的）
	z.velocity = (moveTo - moveFrom).normalized() * z.speed
	z.playAnim("walk")


## 到达：吸附格心、释放预留
func finishMove() -> void:
	# 不再吸附到格心：lerp 终点本来就是 moveTo，
	# 若途中被钳取/脱困改过位置，这里再赋值会把差值一次性补上（瞬移）。
	z.velocity = Vector2.ZERO
	z.knockbackDelta = Vector2.ZERO
	moving = false
	moveTimer = 0.0

	# 落格：目标格变成"我占的格"，同时释放原来那一格。
	# 原版僵尸**始终占着自己所在格**（SetCollideDirection 只在换格时转移），
	# 所以一个格子永远最多只有一只僵尸。
	# 起走时已经把占位转移到目标格，落格只需确认一下
	var landed: Vector2i = z.moveTargetCell
	if landed != Vector2i(-9999, -9999):
		z.reservedCell = landed
		z.moveTargetCell = Vector2i(-9999, -9999)
		MapData.reserveCell(landed, z)


## 中断移动（进攻击 / 退出状态时）
func cancelMove() -> void:
	if not moving:
		return
	moving = false
	moveTimer = 0.0
	# 释放的是"目标格"；自己站的格必须继续占着，
	# 否则停下攻击时别人能走进来和它重叠
	if z.moveTargetCell != Vector2i(-9999, -9999):
		MapData.releaseCell(z.moveTargetCell, z)
		z.moveTargetCell = Vector2i(-9999, -9999)
	z.claimCurrentCell()


## 没有目标时的兜底：随便找个能走的方向挪
func wanderFallback(delta: float) -> void:
	var dir: Vector2 = z.wanderDir()
	if dir == Vector2.ZERO:
		z.velocity = Vector2.ZERO
		z.playAnim("stand")
		return
	z.moveInDirection(dir, delta)
	z.playAnim("walk")
