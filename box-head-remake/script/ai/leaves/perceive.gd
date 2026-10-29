extends ConditionLeaf

## 刷新感知与敌人源距离场，并清空上一 tick 的指令
##
## 永远返回 SUCCESS（它只负责更新数据），具体分支由后面的条件叶子判断。


func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE

	b.ensureField()
	b.scan()
	blackboard.set_value("target", b.target)
	blackboard.set_value("hazards", b.hazards)

	# 每 tick 先清零，避免上一个分支的残留指令
	p.cpuMoveDir = Vector2.ZERO
	p.cpuWantFire = false
	return SUCCESS
