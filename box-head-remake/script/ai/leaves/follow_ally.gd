extends ActionLeaf

## 没有敌人时跟紧人类队友（超过 4 格才动）
## 走位会避开墙和其他角色；队友本人不算挡路

const KEEP_CELLS: float = 4.0


func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE

	var ally: Player = blackboard.get_value("ally")
	if ally == null or not is_instance_valid(ally) or ally.isDead:
		return FAILURE

	var to: Vector2 = ally.global_position - p.global_position
	if to.length() > KEEP_CELLS * MapData.cellSize:
		var b := p.cpuBrain as CpuBrain
		var dir: Vector2 = to.normalized()
		if b != null:
			dir = b.pathDir(p.global_position, dir, ally)
		# 距离场里没敌人时可能还是直的，借玩家流场再兜一次
		if p.blockedByCell(p.global_position + dir * MapData.cellSize):
			var f := MapData.getFlowDir(p.global_position, "multi")
			if f != Vector2.ZERO:
				dir = f
		p.cpuMoveDir = dir
		if p.cpuAimDir == Vector2.ZERO:
			p.cpuAimDir = dir
	return RUNNING
