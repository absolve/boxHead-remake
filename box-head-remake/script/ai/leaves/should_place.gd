extends ConditionLeaf

## 现在该不该用放置类武器（地雷/油桶/墙/充电包/手榴弹）


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null or p.isDead:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE
	return SUCCESS if b.placementChoice() != null else FAILURE
