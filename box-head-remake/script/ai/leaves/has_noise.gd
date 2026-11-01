extends ConditionLeaf

## 是否听到枪声、要去查看（没有目标、枪声还在有效期内）


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null or p.isDead:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE
	if b.target != null and is_instance_valid(b.target):
		return FAILURE
	if Time.get_ticks_msec() >= b.noiseUntilMs:
		return FAILURE
	return SUCCESS
