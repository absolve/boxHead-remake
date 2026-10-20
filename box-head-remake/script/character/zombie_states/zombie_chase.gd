extends State

## Chase 状态 —— 流场寻路追击玩家
##
## 对齐原版 `State_GotoPlayer` + `State_CellToCell`（doc/01-enemy-ai.md:332-338）：
##   1) 每格只算一次方向：`dirForCurrentCell()` 在同一格里返回缓存方向；
##      走满一格（格子坐标变化）才重算 —— 这是原版不会来回摇摆的原因。
##   2) 方向由流场给出；被挡（墙/油桶/其他僵尸）就 ±45°..±180° 找一条能走的。
##   3) 无路可走 → 站住 1 秒（原版 State_Wait）。
##   4) 朝向与移动方向不一致 → 先转身（Turn），转完再回来。

## 宿主
var z: Zombie:
	get:
		return actor as Zombie


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	z.velocity = Vector2.ZERO


func physicsUpdate(delta: float) -> void:
	if z.isDead:
		return

	# 目标丢失（玩家死亡/被回收）→ 站桩等刷新
	if not z.refreshTarget(delta):
		z.velocity = Vector2.ZERO
		z.playAnim("stand")
		return

	# ---- 1) 进入攻击距离：朝向对就直接打，不对就转身再打
	if z.targetInAttackRange():
		z.velocity = Vector2.ZERO
		if z.isFacingTarget():
			stateMachine.transitionTo(&"Attack")
		else:
			stateMachine.transitionTo(&"Turn", {"to": z.dirToTarget(), "next": "Attack"})
		return

	# ---- 2) 取当前格的移动方向（同格内不会变）
	var dir: Vector2 = z.dirForCurrentCell()

	if dir == Vector2.ZERO:
		# 无路可走 → 原版 State_Wait：站住 1 秒，然后重算
		z.blockedTimer += delta
		z.velocity = Vector2.ZERO
		z.playAnim("stand")
		if z.blockedTimer >= z.BLOCKED_WAIT:
			z.blockedTimer = 0.0
			z.invalidateCellDir()
		return

	z.blockedTimer = 0.0

	# ---- 3) 朝向与移动方向不一致 → 先转身
	var want := Zombie.angleFromVector(dir)
	if want != z.angle and stateTime > z.turnCooldown:
		z.velocity = Vector2.ZERO

		# 原版 SetState_WithDirection_Wait 的 State_Sleep 分支：
		# 刚转完一次身、方向又不对 → 停 1/3 秒防抖，而不是立刻又转回去。
		if z.justTurned:
			z.justTurned = false
			z.turnRetryTimer = Zombie.TURN_RETRY_WAIT
		if z.turnRetryTimer > 0.0:
			z.turnRetryTimer -= delta
			z.playAnim("stand")
			return

		stateMachine.transitionTo(&"Turn", {"to": want, "next": "Chase"})
		return

	z.justTurned = false
	z.turnRetryTimer = 0.0

	# ---- 4) 前进
	z.moveInDirection(dir, delta)
	z.playAnim("walk")
