extends ActionLeaf

## 撤退：沿直线远离目标；有队友时往队友方向退
## 前方被墙 / 角色挡住就沿敌人源距离场往"更远"的邻格退

func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE

	var t: Node2D = blackboard.get_value("target")
	var away := Vector2.ZERO
	if t != null and is_instance_valid(t):
		away = (p.global_position - t.global_position).normalized()

	# 有队友就往队友那边退，没有就单纯远离
	var ally := b.nearestAlly()
	if ally != null:
		var toAlly: Vector2 = ally.global_position - p.global_position
		if toAlly.length() > 3.0 * MapData.cellSize:
			away = (away + toAlly.normalized() * 1.5).normalized()

	if away == Vector2.ZERO:
		return FAILURE

	if not b.canStepTo(p.global_position, away * MapData.cellSize):
		var f := MapData.cpuFieldAwayDir(p.global_position)
		if f != Vector2.ZERO and b.canStepTo(p.global_position, f * MapData.cellSize):
			away = f

	p.cpuMoveDir = away
	if t != null and is_instance_valid(t):
		p.cpuAimDir = (t.global_position - p.global_position).normalized()
	return RUNNING
