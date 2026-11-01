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
			b.steer(b.pathDir(p.global_position, (anchor - p.global_position).normalized()))
			return SUCCESS

	# 被僵尸围住了：先拉开距离，边走边打
	if b != null:
		var crowd: Vector2 = b.crowdDir()
		if crowd != Vector2.ZERO:
			b.steer(b.pathDir(p.global_position, crowd, t))
			return SUCCESS

	# 交战距离按武器本身来（霰弹贴脸、轨道炮远程），策略只做小幅修正
	var want: float = 208.0 if b == null else b.idealDistance(p.currWeapon)
	var hit: Node = b.firstHit(aim) if b != null else t
	var hitEnemy: bool = b != null and hit != null and hit != t and b.isEnemy(hit)
	var canHit: bool = b == null or hit == t
	# 前面挡着的是另一只敌人：也算能打（打谁都掉血），别为了找角度一直侧移
	var canShootSomething: bool = canHit or hitEnemy

	# ★ 能打到东西 → 站定开枪，不后退也不侧移。
	#   以前目标一靠近就往后撤，僵尸再贴上来，看起来就是一直挪。
	var move := Vector2.ZERO
	if canShootSomething:
		move = Vector2.ZERO
	elif dist > want + 32.0:
		# 打不到且太远：走近一点
		move = aim
	elif dist < want - 40.0:
		# 打不到且贴太近（被自己人/道具挡视线）：拉开一点找角度
		move = -aim
	else:
		# 距离合适但视线被挡：侧移找角度（方向保持 1.2 秒）
		move = aim.orthogonal() * b.strafeDirection()

	if b != null:
		# 站位分散：队友离得太近（尤其拿火箭时）先散开，别全挤在一起开火
		var sep: Vector2 = b.separationDir(1.8)
		if sep != Vector2.ZERO:
			if b.allyInBlast():
				move = sep
			elif move != Vector2.ZERO:
				move = (move + sep * 0.7).normalized()
		if move == Vector2.ZERO:
			b.steer(Vector2.ZERO)
		else:
			b.steer(b.pathDir(p.global_position, move, t))
	else:
		p.cpuMoveDir = move
	return SUCCESS
