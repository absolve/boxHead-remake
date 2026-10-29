extends ActionLeaf

## 巡逻：在锚点附近随机走动，到点后停 0.5~1.5 秒再换下一个点
##
## 敌人一旦出现，perceive 会写 target、战斗分支排在巡逻之前，会先接管；
## 这里不需要自己判断"有没有敌人"。


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE

	var dir := b.patrolMove()
	p.cpuMoveDir = dir
	if dir != Vector2.ZERO:
		p.cpuAimDir = dir
	return RUNNING
