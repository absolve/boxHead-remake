extends ActionLeaf

## 更新主策略（内部 1 秒节流 + 15 秒驻留 + 强制切换规则，见 CpuBrain.updateStrategy）


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE
	b.updateStrategy()
	return SUCCESS
