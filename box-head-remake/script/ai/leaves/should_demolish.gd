extends ConditionLeaf

## 是否要拆东西：挡在目标射线上的墙 / 油桶，或能炸到敌人的油桶

func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE

	var prop := b.demolitionTarget()
	if prop == null:
		return FAILURE
	blackboard.set_value("demolish_target", prop)
	return SUCCESS
