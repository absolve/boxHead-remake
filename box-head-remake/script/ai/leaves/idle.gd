extends ActionLeaf

## 无事可做：原地待机（指令已在 Perceive 里清零）


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	p.cpuMoveDir = Vector2.ZERO
	return RUNNING
