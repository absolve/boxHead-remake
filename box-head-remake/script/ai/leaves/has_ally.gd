extends ConditionLeaf

## 附近是否有人类队友（CPU 自己的队友不算）


func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE

	var ally := b.nearestAlly()
	if ally == null:
		return FAILURE
	blackboard.set_value("ally", ally)
	return SUCCESS
