extends ActionLeaf

## 无事可做：原地待机（指令已在 Perceive 里清零）


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	# 没事干时往画面中间靠：不要四个人都贴着相机边缘（回滞，避免边界摇摆）
	if b != null and MapData.viewRect.size.x > 0.0:
		var home: Vector2 = b.roamHomeDir()
		if home != Vector2.ZERO:
			var dir0: Vector2 = b.pathDirSimple(p.global_position, home)
			p.cpuMoveDir = dir0
			if dir0 != Vector2.ZERO:
				p.cpuAimDir = dir0
			return RUNNING
		var center: Vector2 = b.roamRect().get_center()
		if p.global_position.distance_to(center) > 4.0 * MapData.cellSize:
			var dir: Vector2 = b.pathDirSimple(p.global_position,
					(center - p.global_position).normalized())
			p.cpuMoveDir = dir
			if dir != Vector2.ZERO:
				p.cpuAimDir = dir
			return RUNNING
	p.cpuMoveDir = Vector2.ZERO
	return RUNNING
