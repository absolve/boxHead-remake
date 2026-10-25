extends State

## 恶魔 Attack —— 播攻击动画，在**动画第 3 帧**发射火球（原版 CThing_Creature_Devil.as:166-195）
##
## 原版判定是 `_loc3_.mNewFrame && _loc3_.mFrameIndex == 3`：不是动画结束才开火。
## 动画播完（mAnimEnd）后回到 mReturnStateID，也就是 State_GotoPlayer。
## 素材缺失时 hasAnim("attack") 为 false，此时退化为"冷却到了直接开火"，
## 否则 isAnimPlaying() 恒为 false，判定帧那段永远走不到。


var d: Devil:
	get:
		return actor as Devil

## 本次攻击是否已放出火球
var hasFired: bool = false

## 攻击冷却计时（仅无攻击动画的退化路径使用）
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
		if d.canAttack():
			hasFired = true
			d.fireFireball()
		stateMachine.transitionTo(&"Chase")
		return

	# 攻击动画进行中：到判定帧放火球（>= 防止低帧率跳帧漏掉）
	if d.isAnimPlaying():
		if not hasFired and d.ani.frame >= d.attackHitFrame:
			hasFired = true
			d.fireFireball()
		return

	# 动画播完 → 回追击状态（原版 mReturnStateID = State_GotoPlayer）
	stateMachine.transitionTo(&"Chase")
