extends State

## 恶魔 Attack —— 播攻击动画，第 3 帧喷火球（原版就是第 3 帧）
##
## 素材缺失时 hasAnim("attack") 为 false，此时退化为"按冷却直接开火"，
## 否则 isAnimPlaying() 恒为 false，判定帧那段永远走不到。

var d: Devil:
	get:
		return actor as Devil

## 本次攻击是否已放出火球
var hasFired: bool = false
## 攻击冷却计时
var cooldown: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	hasFired = false
	cooldown = 0.0
	d.velocity = Vector2.ZERO
	d.playAnim("attack", true)


func physicsUpdate(delta: float) -> void:
	d.velocity = Vector2.ZERO
	cooldown += delta

	# 没有攻击动画：按冷却直接开火
	if not d.hasAnim("attack"):
		if cooldown < d.attackDelay:
			return
		cooldown = 0.0
		if d.targetInRange() and d.isFacingTarget():
			d.fireFireball()
		else:
			stateMachine.transitionTo(&"Chase")
		return

	# 攻击动画进行中：到判定帧放火球
	if d.isAnimPlaying():
		if not hasFired and d.ani.frame >= d.attackHitFrame:
			hasFired = true
			d.fireFireball()
		return

	# 动画播完，等冷却
	if cooldown < d.attackDelay:
		return
	if not d.targetInRange() or not d.isFacingTarget():
		stateMachine.transitionTo(&"Chase")
	else:
		hasFired = false
		cooldown = 0.0
		d.playAnim("attack", true)
