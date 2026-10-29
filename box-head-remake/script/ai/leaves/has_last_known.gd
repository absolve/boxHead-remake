extends ConditionLeaf

## 目标丢失，但还在记忆时间内：去最后看到的位置找


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null or not b.hasLastKnown:
		return FAILURE
	# 已经重新看到目标就交给 combat 分支
	if b.target != null and is_instance_valid(b.target):
		return FAILURE
	return SUCCESS
