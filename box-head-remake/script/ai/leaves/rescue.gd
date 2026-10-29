extends ActionLeaf

## 救援：贴到队友身边（3~5 格），优先打威胁队友的敌人
## 3~5 格内站定开火，不再绕着队友转圈

const NEAR_CELLS: float = 3.0
const FAR_CELLS: float = 5.0
const THREAT_CELLS: float = 4.0


func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE

	var ally: Player = blackboard.get_value("rescue_ally")
	if ally == null or not is_instance_valid(ally) or ally.isDead:
		return FAILURE

	# 优先打队友身边的敌人，没有就退回普通目标
	var t: Node2D = b.enemyNear(ally.global_position, THREAT_CELLS * MapData.cellSize)
	if t == null:
		t = blackboard.get_value("target")
	blackboard.set_value("target", t)

	# 与队友保持 3~5 格；带内站定
	var toAlly: Vector2 = ally.global_position - p.global_position
	var d: float = toAlly.length()
	var cell: float = MapData.cellSize
	var move := Vector2.ZERO
	if d > FAR_CELLS * cell:
		move = toAlly.normalized()
		move = b.pathDir(p.global_position, move, ally)
		# 距离场里没有敌人时 pathDir 可能还是直的，借玩家流场再兜一次
		if p.blockedByCell(p.global_position + move * cell):
			var f := MapData.getFlowDir(p.global_position, "multi")
			if f != Vector2.ZERO:
				move = f
	elif d < NEAR_CELLS * cell:
		move = -toAlly.normalized()
	p.cpuMoveDir = move

	if t != null and is_instance_valid(t):
		var aim: Vector2 = (t.global_position - p.global_position).normalized()
		p.cpuAimDir = aim
		var inRange: bool = p.global_position.distance_to(t.global_position) \
				<= float(p.currWeapon.wRange)
		var clear: bool = b.shotHitsTarget(aim, t)
		var safe := true
		if clear and MapData.friendlyFireOn() and b.isExplosive(p.currWeapon):
			safe = b.explosiveSafe(t.global_position)
		p.cpuWantFire = inRange and clear and safe
	return RUNNING
