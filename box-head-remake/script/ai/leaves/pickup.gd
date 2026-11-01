extends ActionLeaf

## 走到补给箱上开箱（碰撞触发拾取，这里只负责走过去）
##
## 8 秒没走到就放弃并冷却 15 秒，避免箱子在墙后时一直卡着绕圈。

const ARRIVE_DIST: float = 14.0
const TIMEOUT_MS: int = 8000
const COOLDOWN_MS: int = 15000


func tick(actor: Node, blackboard: Blackboard) -> int:
	var p := actor as Player
	if p == null:
		return FAILURE
	var b := p.cpuBrain as CpuBrain
	if b == null:
		return FAILURE

	var box: Node2D = blackboard.get_value("pickup_box")
	if box == null or not is_instance_valid(box):
		blackboard.set_value("pickup_start", 0)
		return FAILURE

	var to: Vector2 = box.global_position - p.global_position
	var dist: float = to.length()
	var dir: Vector2 = to / maxf(dist, 0.001)

	if dist <= ARRIVE_DIST:
		# 已经踩上去了，开箱是碰撞触发的，这一帧保持原地
		p.cpuMoveDir = Vector2.ZERO
		blackboard.set_value("pickup_start", 0)
		return RUNNING

	var now := Time.get_ticks_msec()
	var start: int = int(blackboard.get_value("pickup_start", 0))
	if start == 0:
		blackboard.set_value("pickup_start", now)
	elif now - start > TIMEOUT_MS:
		# 走不到（墙后 / 被挡）→ 放弃一段时间
		blackboard.set_value("pickup_start", 0)
		b.pickupBlockedUntilMs = now + COOLDOWN_MS
		return FAILURE

	p.cpuMoveDir = b.pathDirSimple(p.global_position, dir)
	if p.cpuAimDir == Vector2.ZERO:
		p.cpuAimDir = dir
	return RUNNING
