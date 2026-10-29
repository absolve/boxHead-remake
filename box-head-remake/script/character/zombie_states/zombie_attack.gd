extends State

## Attack 状态 —— 近战挥击
##
## 对应原版僵尸的 State_Attack：
##   - 播放当前朝向的 attack_N 动画；
##   - 到攻击判定帧时结算一次伤害（同一挥击只结算一次）；
##   - 动画放完等冷却，之后目标仍在范围内且朝向一致就再挥，否则回 Chase。
##
## 与旧实现的差别（旧版有两个 bug）：
##   1) 旧版 `hasAttacked` 只在"冷却结束重播动画"时重置，从 Chase 进入 Attack 时
##      没有重置，导致**从追击切进攻击的第一次挥击不造成伤害**。这里每次挥击
##      （_swing）都重置，从根上避免。
##   2) 旧版攻击用 attackArea 的区域重叠判定，还要按方向摆位置和额外旋转。
##      现在改成 zombie.deal_damage()：范围内 + 朝向一致 即命中。


## 宿主
var z: Zombie:
	get:
		return actor as Zombie

## 本次挥击是否已经结算过伤害
var hasHit: bool = false
## 距上次挥击结束的冷却计时
var cooldown: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	z.velocity = Vector2.ZERO
	cooldown = 0.0
	z.clearCommit()
	swing()


func exit() -> void:
	cooldown = 0.0
	hasHit = false


## 开始一次新的挥击
func swing() -> void:
	hasHit = false
	z.playAnim("attack", true)


func physicsUpdate(delta: float) -> void:
	z.velocity = Vector2.ZERO

	# 挥击过程中：到判定帧结算一次
	if z.isAnimPlaying():
		if not hasHit and z.ani.frame >= z.attackHitFrame:
			hasHit = true
			z.dealDamage()
			# 原版：命中后进 State_Sleep 停 10 帧（0.4 秒）再回追击
			stateMachine.transitionTo(&"Sleep", {"next": "Chase", "time": 0.4})
		return

	# 挥击结束：等冷却
	cooldown += delta
	if cooldown < z.attackDelay:
		return
	cooldown = 0.0

	# 目标不在范围内 → 回去追
	if not z.hasTarget() or not z.targetInAttackRange():
		stateMachine.transitionTo(&"Chase")
		return

	# 目标跑到侧面/背后 → 先转身
	if not z.isFacingTarget():
		stateMachine.transitionTo(&"Turn", {"to": z.dirToTarget(), "next": "Attack"})
		return

	swing()
