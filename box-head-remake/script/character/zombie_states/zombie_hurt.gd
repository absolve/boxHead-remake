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
	z.playAnim("hitFront" if z.hitFromFront else "hitRear", true)


func physicsUpdate(_delta: float) -> void:
	# 60fps 下每物理帧 ≈ 1/2.4 个逻辑帧，位移按逻辑帧衰减
	# knockbackDelta 的单位是"格/帧"（hurt 里再 ×cellSize），
	# 阈值必须按格算：0.01 格 ≈ 0.32px，用 0.5 会把所有击退都跳过
	if z.knockbackFrames > 0 and z.knockbackDelta.length() > 0.01:
		z.knockbackFrames -= 1

		# ① 先算出本帧要走到的位置
		var next: Vector2 = z.global_position + z.knockbackDelta * MapData.cellSize

		# ② 圆形位置修正（生物 → 墙，迭代 2 次）
		var corrected: Vector2 = z.creatureCollide(next)

		# ③ 应用并衰减
		z.global_position = corrected
		z.knockbackDelta *= 0.65
	else:
		z.knockbackDelta = Vector2.ZERO
		z.knockbackFrames = 0

	if stateTime >= z.hurtDelay and z.knockbackFrames <= 0:
		# 击退结束时把"落到的新格子"占住（原版下一次 CellToCell_Init 会 SetCollideDirection）
		z.claimCurrentCell()
		stateMachine.transitionTo(&"Chase")
