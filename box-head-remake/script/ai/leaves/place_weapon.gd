extends ActionLeaf

## 使用放置类武器：切枪 → 朝敌人方向放一个 → 后退一小段（别站在自己的雷/桶上）


func tick(actor: Node, _blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null or p.isDead:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE

	var w: Node = b.placementChoice()
	if w == null:
		return FAILURE

	# 先切到这把武器
	if p.currWeapon != w:
		p.cpuRequestWeapon(w.type)
		if p.currWeapon != w:
			return RUNNING

	var aim: Vector2 = p.vector
	if b.target != null and is_instance_valid(b.target):
		aim = (b.target.global_position - p.global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	p.cpuAimDir = aim
	p.cpuMoveDir = Vector2.ZERO
	p.currWeapon.fire(aim)

	# 放完立刻离开这一格（地雷/油桶/充电包都在自己脚下）
	b.placeCooldownMs = Time.get_ticks_msec() + 5000
	b.postPlaceDir = -aim
	b.postPlaceUntilMs = Time.get_ticks_msec() + 900
	return SUCCESS
