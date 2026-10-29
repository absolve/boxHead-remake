extends ActionLeaf

## 低血求生：
## 1) 附近有补给箱 → 去捡（血量 ≤ 50% 时箱子给回血）
## 2) 没箱子 → 边后退拉开距离边打（放风筝）
##
## 两步都会顺带尝试开火，不会因为跑路完全停手。

func tick(actor: Node, _blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE

	# 1) 先找箱子
	var box: Node2D = b.boxTarget
	if box != null and is_instance_valid(box):
		var toBox: Vector2 = box.global_position - p.global_position
		if toBox.length() < 20.0:
			p.cpuMoveDir = Vector2.ZERO
		else:
			p.cpuMoveDir = b.pathDirSimple(p.global_position, toBox.normalized())
		_tryFire(p, b)
		return RUNNING

	# 2) 没箱子：沿远离敌人的方向后退
	var t: Node2D = b.target
	if t == null or not is_instance_valid(t):
		return FAILURE
	var away: Vector2 = (p.global_position - t.global_position).normalized()
	if not b.canStepTo(p.global_position, away * MapData.cellSize):
		var f := MapData.cpuFieldAwayDir(p.global_position)
		if f != Vector2.ZERO:
			away = f
	p.cpuMoveDir = away
	_tryFire(p, b)
	return RUNNING


## 顺手开火：射程内 + 射线能打到 + 爆炸物不误伤
func _tryFire(p: Player, b: CpuBrain) -> void:
	var t: Node2D = b.target
	if t == null or not is_instance_valid(t):
		return
	var aim: Vector2 = (t.global_position - p.global_position).normalized()
	p.cpuAimDir = aim
	if p.global_position.distance_to(t.global_position) > b.effectiveRange(p.currWeapon):
		return
	if not b.shotHitsTarget(aim, t):
		return
	if MapData.friendlyFireOn() and b.isExplosive(p.currWeapon) and not b.explosiveSafe(t.global_position):
		return
	p.cpuWantFire = true
