extends ConditionLeaf

## 是否该巡逻：主策略是巡逻、没有目标、也没有"最后见到目标"的记忆


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE
	if b.strategy != CpuBrain.Strategy.PATROL:
		return FAILURE
	if b.target != null and is_instance_valid(b.target):
		return FAILURE
	if b.hasLastKnown:
		return FAILURE
	return SUCCESS
