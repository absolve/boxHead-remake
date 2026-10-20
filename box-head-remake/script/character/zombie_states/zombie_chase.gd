extends State

## Chase 状态 —— 流场寻路追击玩家
##
## 对应原版僵尸的 State_GotoPlayer / State_CellToCell：
##   1) 每帧取"我所在格"的流场方向（指向玩家的 BFS 距离场梯度）；
##   2) 被挡住（木头桶/墙/其他僵尸）时左右各试 45°..180° 绕行；
##   3) 走到目标格就换格，方向随之更新。
##
## 进入攻击的两个条件与原版一致：距离进入 attackRange，且朝向与目标方向一致；
## 朝向不对时先去 Turn 转个身，转完再回到本状态继续判定。

## 宿主
var z: Zombie:
	get:
		return actor as Zombie
		
var dir: Vector2

func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	z.velocity = Vector2.ZERO


func physicsUpdate(delta: float) -> void:
	if z.isDead:
		return

	# 目标丢失（玩家死了/被回收）→ 站桩等刷新
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

	# ---- 2) 取一个可走的方向
	# 有"承诺"时先沿承诺方向走（原版 minMoveGrid 滞回），
	# 只有走够格数、或承诺方向被挡住时，才重新看流场。
	
	if z.needNewDir(delta):
		dir = z.flowDirection()
		if dir == Vector2.ZERO or not z.canStep(dir):
			var fallback: Vector2 = dir if dir != Vector2.ZERO else Zombie.vectorFromAngle(z.angle)
			dir = z.sidestepDirection(fallback)
		if dir != Vector2.ZERO:
			z.commitDir(dir)
	else:
		dir = z.committedDir

	if dir == Vector2.ZERO:
		# 八个方向全堵死（被围住）→ 原地待命
		z.velocity = Vector2.ZERO
		z.playAnim("stand")
		return

	# ---- 3) 朝向与移动方向不一致 → 先转身
	var want := Zombie.angleFromVector(dir)
	if want != z.angle and stateTime > z.turnCooldown:
		z.velocity = Vector2.ZERO
		stateMachine.transitionTo(&"Turn", {"to": want, "next": "Chase"})
		return

	# ---- 4) 前进
	z.moveInDirection(dir, delta)
	z.playAnim("walk")
