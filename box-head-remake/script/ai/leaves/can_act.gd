extends ConditionLeaf

## 是否允许决策：CPU、未死亡、处于 Idle（受伤/死亡交给状态机）


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null or not p.isCpu or p.isDead:
		return FAILURE
	if p.cpuBrain == null:
		return FAILURE
	if p.state != Game.playerState.Idle:
		return FAILURE
	return SUCCESS
