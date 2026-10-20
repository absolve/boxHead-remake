extends State

## 恶魔 Chase —— 流场追击 + 进入射程后转正

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

	# 进入 5 格射程：朝向对就开打，不对先转
	if d.targetInRange():
		d.velocity = Vector2.ZERO
		if d.isFacingTarget():
			stateMachine.transitionTo(&"Attack")
		else:
			stateMachine.transitionTo(&"Turn", {"to": d.dirToTarget(), "next": "Attack"})
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
