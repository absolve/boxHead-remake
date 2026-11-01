extends ActionLeaf

## 前往枪声位置查看（队友/玩家在远处交火时，别站着发呆）


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null or p.isDead:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE
	if Time.get_ticks_msec() >= b.noiseUntilMs:
		return FAILURE

	# 半路看到敌人：立刻交给 combat 分支
	if b.target != null and is_instance_valid(b.target):
		return FAILURE

	var to: Vector2 = b.noisePos - p.global_position
	if to.length() <= MapData.cellSize * 1.5:
		# 到了：清掉枪声记忆，交给后续分支
		b.noiseUntilMs = 0
		p.cpuMoveDir = Vector2.ZERO
		return SUCCESS

	var dir: Vector2 = b.pathDirSimple(p.global_position, to.normalized())
	p.cpuMoveDir = dir
	if dir != Vector2.ZERO:
		p.cpuAimDir = dir
	return RUNNING
