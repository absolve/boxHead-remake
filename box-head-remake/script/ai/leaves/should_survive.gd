extends ConditionLeaf

## 低血求生：血量低于阈值（默认 25%，单人生存时 40%）且（附近有箱子 或 有敌人）时接管
##
## 优先级排在救援之前 —— 自己都快死了，先保命。

## 敌人在这个距离外就不用逃，继续正常打
const PANIC_CELLS: float = 6.0
## 僵尸（近战慢）在这个距离外完全不用怕
const ZOMBIE_SAFE_CELLS: float = 2.5


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

	# 敌人还远（或只是慢速僵尸在远处）就不要慌，继续正常打
	if b.boxTarget == null and b.target != null and is_instance_valid(b.target):
		var dist: float = p.global_position.distance_to(b.target.global_position)
		if dist > PANIC_CELLS * MapData.cellSize:
			return FAILURE
		if b.target.get("type") == Game.roleType.Zombie \
				and dist > ZOMBIE_SAFE_CELLS * MapData.cellSize:
			return FAILURE
	return SUCCESS
