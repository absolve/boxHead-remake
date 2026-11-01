extends ConditionLeaf

## 是否该去开补给箱（拿新武器 / 补血）
##
## 原则：**没解锁新武器之前不去开箱**。
## 开局箱子里只有手枪（weaponUnlock 里还没有别的武器）或回血，
## 为它满地图跑纯属浪费时间。
##
## 触发条件（满足其一）：
##   1) 血量低于一半（箱子里会给 Life）
##   2) 有已解锁、但自己还没有的武器（新武器开出来了）
##   3) 当前武器没子弹了（箱子里能补同款弹药）
## 有敌人时只有箱子很近（2.5 格）才顺路捡，避免丢下战斗满图跑。

const VERY_CLOSE_CELLS: float = 2.5
const MAX_CELLS: float = 12.0


func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE

	var now := Time.get_ticks_msec()
	if now < b.pickupBlockedUntilMs:
		return FAILURE

	var box: Node2D = b.boxTarget
	if box == null or not is_instance_valid(box):
		return FAILURE

	var dist: float = p.global_position.distance_to(box.global_position)
	if dist > MAX_CELLS * MapData.cellSize:
		return FAILURE

	# ---- 这个箱子对当前 CPU 有没有用？----
	var lowHp: bool = p.hp < p.maxHp * 0.5
	var hasNewWeapon := false
	for wt in MapData.weaponUnlock:
		if wt == Game.weaponType.Pistol:
			continue
		if p.getWeapon(wt) == null:
			hasNewWeapon = true
			break
	var ammoEmpty: bool = p.currWeapon != null \
			and p.currWeapon.maxAmmoNum > 0 and p.currWeapon.ammoNum <= 0

	# 开局只有手枪、箱子开不出新东西 → 不去
	if not lowHp and not hasNewWeapon and not ammoEmpty:
		return FAILURE

	# 正在打人时：先打近处的敌人，别为了箱子往怪堆里走
	if b.target != null and is_instance_valid(b.target):
		var targetDist: float = p.global_position.distance_to(b.target.global_position)
		if targetDist < 3.0 * MapData.cellSize:
			return FAILURE
		# 远处有敌人时，只有箱子贴脸才顺路捡
		if dist > VERY_CLOSE_CELLS * MapData.cellSize:
			return FAILURE

	blackboard.set_value("pickup_box", box)
	return SUCCESS
