extends ActionLeaf

## 开火：射程内 + 有视线 + 友伤安全（队友不在射线上、爆炸物不波及队友）才扣扳机


func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	var t: Node2D = blackboard.get_value("target")
	if t == null or not is_instance_valid(t):
		return FAILURE

	var aim: Vector2 = p.cpuAimDir
	if aim == Vector2.ZERO:
		aim = (t.global_position - p.global_position).normalized()
	p.cpuAimDir = aim

	# 够不着 / 被墙挡住 / 会打到队友：这一 tick 不开火，但整体仍算"战斗中"
	# （必须返回 SUCCESS，否则战斗序列会失败、被后面的"跟随队友"分支顶掉）
	var range: float = float(p.currWeapon.wRange) if b == null else b.effectiveRange(p.currWeapon)
	var inRange: bool = p.global_position.distance_to(t.global_position) <= range
	# 用武器的真实射线：第一命中必须是目标（挡枪的队友 / 墙 / 油桶都会拦住）
	var clear: bool = b == null or b.shotHitsTarget(aim, t)
	# 爆炸物还要检查爆区里有没有自己人（含自己）
	var safe := true
	if clear and b != null and MapData.friendlyFireOn() and b.isExplosive(p.currWeapon):
		safe = b.explosiveSafe(t.global_position)
	if inRange and clear and safe:
		p.cpuWantFire = true
	return SUCCESS
