extends ConditionLeaf

## 低血求生：血量低于阈值（默认 25%，单人生存时 40%）且（附近有箱子 或 有敌人）时接管
##
## 优先级排在救援之前 —— 自己都快死了，先保命。

func tick(actor: Node, _blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE

	var ratio := float(p.hp) / maxf(float(p.maxHp), 1.0)
	if ratio >= b.surviveThreshold():
		return FAILURE
	if b.boxTarget == null and b.target == null:
		return FAILURE
	return SUCCESS
