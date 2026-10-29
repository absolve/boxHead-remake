extends ActionLeaf

## 去目标最后出现的位置看看（走敌人源距离场，能绕墙）


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null or not b.hasLastKnown:
		return FAILURE

	var to: Vector2 = b.lastKnownPos - p.global_position
	if to.length() < 24.0:
		b.hasLastKnown = false
		return SUCCESS

	var dir: Vector2 = to.normalized()
	p.cpuMoveDir = b.pathDir(p.global_position, dir)
	p.cpuAimDir = dir
	return RUNNING
