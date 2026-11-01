extends State

## Hurt 状态 —— 受击硬直 + 击退
##
## 对应原版 `State_BulletHit`（CThing_Creature.as:271-320）：
##   进入：由击退速度算出衰减帧数（每帧 ×0.65，直到 <0.01）；清掉自己的格子占用
##   每帧：位置先经 `CreatureCollide()` 做圆形修正（先生物后墙，迭代 2 次），
##         再 Move；位移每帧 ×0.65
## 是否"正面"由 zombie.hit() 根据攻击来向与当前朝向的夹角算出。


## 宿主
var z: Zombie:
	get:
		return actor as Zombie


func enter(_msg: Dictionary = {}) -> void:
	z.clearCommit()
	# 原版 ClearCollideCell：受击时释放格子占用
	z.clearReservation()
	# 原版随机二选一（shothit_1 / shothit_2），不区分前后
	z.playAnim("hitFront" if randi() % 2 == 1 else "hitRear", true)


func physicsUpdate(delta: float) -> void:
	# 击退：连续衰减（快→慢），每帧推进一小段并做圆形位置修正
	var stepVec: Vector2 = z.advanceKnockback(delta)
	if stepVec != Vector2.ZERO:
		var next: Vector2 = z.global_position + stepVec
		# 后面有墙 / 敌人 / 可玩区域边界 → 直接停住（不滑墙、不挤出去）
		if z.knockbackBlocked(next, z.bodyRadius()):
			z.clearKnockback()
		else:
			z.global_position = z.creatureCollide(next)

	if stateTime >= z.hurtDelay and z.knockbackDone():
		# 致命伤：把"被打飞"演完再倒下（原版先 BulletHit 再 Dying）
		if z.dying:
			z.die()
			return
		# 击退结束时把"落到的新格子"占住（原版下一次 CellToCell_Init 会 SetCollideDirection）
		z.claimCurrentCell()
		stateMachine.transitionTo(&"Chase")
