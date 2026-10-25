extends State

## 恶魔 Chase（原版 State_GotoPlayer）—— 流场追击 + 射程内转正开火 + 顺手拆障碍
##
## 原版每帧的顺序（CThing_Creature_Devil.as:106-135）：
##   1) Brain()：能打玩家就直接进 Attack；
##   2) 检查"朝玩家方向的相邻格"是不是 mCollide_Object（128）→ 是就转去拆；
##   3) 否则 Nav_Direction 选方向走一格。
## 本项目的移动用流场，所以第 3 步换成 flowDirection()；前两步保持一致。


var d: Devil:
	get:
		return actor as Devil


func physicsUpdate(delta: float) -> void:
	if d.isDead:
		return

	if not d.refreshTarget(delta):
		d.velocity = Vector2.ZERO
		d.playAnim("stand")
		return

	var tDir: int = d.dirToTarget()

	# Brain()：射程内 + 朝向对 + 通视 → 直接开火
	if d.canAttack():
		d.velocity = Vector2.ZERO
		stateMachine.transitionTo(&"Attack")
		return

	# 射程内但还没对准 → 先转向（原版由 Nav 决策转向，这里保留现有手感）
	if d.targetInRange() and d.attackReady() and d.hasLineOfSight() and d.angle != tDir:
		d.velocity = Vector2.ZERO
		stateMachine.transitionTo(&"Turn", {"to": tDir, "next": "Attack"})
		return

	# 朝玩家方向的相邻格是可破坏物（假墙/油桶）→ 先拆掉再继续追
	if d.objectInDirection(tDir) != null:
		d.velocity = Vector2.ZERO
		if d.angle == tDir:
			stateMachine.transitionTo(&"RemoveObject")
		else:
			stateMachine.transitionTo(&"Turn", {"to": tDir, "next": "RemoveObject"})
		return

	var dir: Vector2 = d.flowDirection()
	if dir == Vector2.ZERO:
		d.velocity = Vector2.ZERO
		d.playAnim("stand")
		return

	var want := Zombie.angleFromVector(dir)
	if want != d.angle:
		stateMachine.transitionTo(&"Turn", {"to": want, "next": "Chase"})
	else:
		d.moveInDirection(dir, delta)
		d.playAnim("walk")
