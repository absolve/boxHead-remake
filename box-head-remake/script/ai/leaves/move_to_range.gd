extends ActionLeaf

## 走位：
## - 距离带外：沿瞄准方向直线接近 / 后退（不做横向游走）
## - 距离带内：站定开火，不再左右乱晃
## - 前方被墙 / 玩家 / 敌人挡住：交给 CpuBrain.pathDir 绕（目标本人不算挡路）

func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain

	var t: Node2D = blackboard.get_value("target")
	if t == null or not is_instance_valid(t):
		return FAILURE

	var to: Vector2 = t.global_position - p.global_position
	var dist: float = to.length()
	var aim: Vector2 = to / maxf(dist, 0.001)
	p.cpuAimDir = aim

	# 缰绳：离锚点太远先回去（继续朝目标瞄准，开火交给 fire_if_safe）
	if b != null and b.leashCells() > 0:
		var anchor: Vector2 = b.leashAnchor()
		if p.global_position.distance_to(anchor) > float(b.leashCells()) * MapData.cellSize:
			p.cpuMoveDir = b.pathDir(p.global_position, (anchor - p.global_position).normalized())
			return SUCCESS

	# 交战距离按武器本身来（霰弹贴脸、轨道炮远程），策略只做小幅修正
	var want: float = 208.0 if b == null else b.idealDistance(p.currWeapon)
	var move := Vector2.ZERO
	if dist > want + 24.0:
		move = aim
	elif dist < want - 32.0:
		move = -aim
	elif b != null and not b.shotHitsTarget(aim, t):
		# 距离带内但打不到（队友/墙/油桶挡住）：侧移找角度；打得到就站定
		var side := 1.0 if int(Time.get_ticks_msec() / 1000) % 2 == 0 else -1.0
		move = aim.orthogonal() * side

	if move != Vector2.ZERO and b != null:
		move = b.pathDir(p.global_position, move, t)
	p.cpuMoveDir = move
	return SUCCESS
