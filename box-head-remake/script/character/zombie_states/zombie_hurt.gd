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
	# 击退惯性指数衰减，避免受击后一直滑
	z.velocity = z.velocity.lerp(Vector2.ZERO, minf(8.0 * delta, 1.0))
	if z.velocity.length() > 1.0:
		z.move_and_collide(z.velocity * delta)

	if stateTime >= z.hurtDelay:
		stateMachine.transitionTo(&"Chase")
