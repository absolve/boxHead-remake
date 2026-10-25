extends State

## 恶魔 RemoveObject（原版 State_RemoveObject，CThing_Creature_Devil.as:203-218）
##
## 原版从 State_EnterMap 进入：若当前朝向前方的相邻格仍带 mCollide_Object，
## 就对那一格施加 CThing_Affect_DevilAttack(this, this, 100000, mAngle)；
## 格子清空后回 State_GotoPlayer。
##
## 本项目里可破坏物是假墙（wall_obj，hp 10）和油桶（barrel_obj，被击中就爆），
## 它们统一提供 hit() 接口，所以这里直接调用 hit(100000)：
## 数值远大于任何血量，等价于原版的"直接摧毁"。
##
## 进入来源：原版只从 State_EnterMap 进入一次；本项目按需求也在 Chase 检测到
## 朝玩家方向的相邻格是可破坏物时转入本状态，用来主动拆掉挡路的假墙/油桶。


var d: Devil:
	get:
		return actor as Devil


func enter(_msg: Dictionary = {}) -> void:
	d.velocity = Vector2.ZERO
	d.playAnim("stand", true)


func physicsUpdate(_delta: float) -> void:
	if d.isDead:
		return

	d.velocity = Vector2.ZERO
	var obj = d.frontObject()
	if obj == null:
		# 前方已经清空 → 回 GotoPlayer
		stateMachine.transitionTo(&"Chase")
		return

	d.playAnim("stand")
	# 原版每帧施加一次；油桶会进入引爆流程，假墙当帧碎裂
	obj.hit(d.objectDamage)
