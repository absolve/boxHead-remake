extends State

## Hurt 状态 —— 受击硬直
##
## 对应原版僵尸的受击动画：正面中弹播 hitFront_N，背面中弹播 hitRear_N，
## 期间带一点击退惯性，hurtDelay 秒后回到 Chase。
## 是否"正面"由 zombie.hit() 根据攻击来向与当前朝向的夹角算出。

## 宿主
var z: Zombie:
	get:
		return actor as Zombie


func enter(_msg: Dictionary = {}) -> void:
	z.clearCommit()
	z.playAnim("hitFront" if z.hitFromFront else "hitRear", true)


func physicsUpdate(delta: float) -> void:
	# 击退：速度按 0.65/逻辑帧 衰减（原版 mDelta *= 0.65）
	if z.knockbackTime > 0.0 and z.velocity.length() > 8.0:
		z.knockbackTime -= delta
		# 60fps 下每物理帧相当于 1/2.4 个逻辑帧，所以要开方
		var decay: float = pow(z.KNOCKBACK_DECAY, delta * MapData.TICKS_PER_SEC)
		z.velocity *= decay
		z.move_and_collide(z.velocity * delta)
	else:
		z.velocity = Vector2.ZERO
		z.knockbackTime = 0.0

	if stateTime >= z.hurtDelay and z.knockbackTime <= 0.0:
		stateMachine.transitionTo(&"Chase")
