extends State

## 恶魔 Hurt —— 受击硬直 + 击退


var d: Devil:
	get:
		return actor as Devil


func enter(_msg: Dictionary = {}) -> void:
	# 原版随机二选一，不区分前后
	d.playAnim("hitFront" if randi() % 2 == 1 else "hitRear", true)


func physicsUpdate(delta: float) -> void:
	# 击退：连续衰减（快→慢），每帧推进一小段
	var stepVec: Vector2 = d.advanceKnockback(delta)
	if stepVec != Vector2.ZERO:
		var next: Vector2 = d.global_position + stepVec
		# 后面有墙 / 敌人 / 可玩区域边界 → 直接停住
		if d.knockbackBlocked(next, d.bodyRadius()):
			d.clearKnockback()
		else:
			d.move_and_collide(stepVec)

	if stateTime >= d.hurtDelay and d.knockbackDone():
		if d.dying:
			d.die()
			return
		stateMachine.transitionTo(&"Chase")
