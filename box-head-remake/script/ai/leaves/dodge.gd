extends ActionLeaf

## 躲火球：沿垂直方向闪一段，朝向尽量保持对着目标


func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE

	var side: Vector2 = blackboard.get_value("hazard_side", Vector2.ZERO)
	if side == Vector2.ZERO:
		return FAILURE

	var t: Node2D = blackboard.get_value("target")
	if t != null and is_instance_valid(t):
		p.cpuAimDir = (t.global_position - p.global_position).normalized()
	p.cpuMoveDir = side
	return RUNNING
