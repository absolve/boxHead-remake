extends ActionLeaf

## 撤退：沿直线远离目标；有队友时往队友方向退
## 前方被墙 / 角色挡住就沿敌人源距离场往"更远"的邻格退

func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE

	var t: Node2D = blackboard.get_value("target")
	if t == null or not is_instance_valid(t):
		return FAILURE

	# 优先往队友方向退（有人接应），但同样要避开墙角
	var ally := b.nearestAlly()
	var away := Vector2.ZERO
	if ally != null:
		var toAlly: Vector2 = ally.global_position - p.global_position
		if toAlly.length() > 3.0 * MapData.cellSize:
			away = b.pathDirSimple(p.global_position, toAlly.normalized())
	if away == Vector2.ZERO:
		away = b.fleeDirection(t.global_position)
	if away == Vector2.ZERO:
		# 无路可退：就地打，不要贴着墙角左右摇
		return FAILURE

	p.cpuMoveDir = away
	if t != null and is_instance_valid(t):
		p.cpuAimDir = (t.global_position - p.global_position).normalized()
	return RUNNING
