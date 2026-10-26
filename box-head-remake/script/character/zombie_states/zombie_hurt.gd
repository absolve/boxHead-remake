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


## 25Hz 累积器：原版每 1/25 秒位移一次并 ×0.65
var moveAcc: float = 0.0


func physicsUpdate(delta: float) -> void:
	# 位移按 25Hz 结算（原来 60Hz，同样的距离只用了 0.4 倍时间）
	moveAcc += delta
	var step: float = 1.0 / MapData.TICKS_PER_SEC
	while moveAcc >= step and z.knockbackFrames > 0 and z.knockbackDelta.length() > 0.01:
		moveAcc -= step
		z.knockbackFrames -= 1
		# ① 先算出本帧要走到的位置
		var next: Vector2 = z.global_position + z.knockbackDelta * MapData.cellSize
		# ② 圆形位置修正（生物 → 墙，迭代 2 次）
		var corrected: Vector2 = z.creatureCollide(next)
		# ③ 应用并衰减
		z.global_position = corrected
		z.knockbackDelta *= 0.65
	if z.knockbackFrames <= 0 or z.knockbackDelta.length() < 0.01:
		z.knockbackDelta = Vector2.ZERO
		z.knockbackFrames = 0

	if stateTime >= z.hurtDelay and z.knockbackFrames <= 0:
		# 致命伤：把"被打飞"演完再倒下（原版先 BulletHit 再 Dying）
		if z.dying:
			z.die()
			return
		# 击退结束时把"落到的新格子"占住（原版下一次 CellToCell_Init 会 SetCollideDirection）
		z.claimCurrentCell()
		stateMachine.transitionTo(&"Chase")
