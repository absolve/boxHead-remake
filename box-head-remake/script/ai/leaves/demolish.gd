extends ActionLeaf

## 拆物：站定，用当前枪打爆油桶 / 打碎墙
##
## 只在 should_demolish 通过时进入：挡路的墙、能炸到敌人的油桶；
## 打油桶前 CpuBrain 已确认爆区里没有自己人。

func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE

	var prop: Node2D = blackboard.get_value("demolish_target")
	if prop == null or not is_instance_valid(prop):
		return FAILURE

	var to: Vector2 = prop.global_position - p.global_position
	var d: float = to.length()
	if d > b.effectiveRange(p.currWeapon):
		return FAILURE
	var aim: Vector2 = to / maxf(d, 0.001)
	p.cpuAimDir = aim
	p.cpuMoveDir = Vector2.ZERO
	# 被别的物体挡住就打不到 → 交回后面的战斗分支，避免卡死
	if not b.shotHitsProp(aim, prop):
		return FAILURE
	p.cpuWantFire = true
	return RUNNING
