extends State

## Spawn 状态 —— 从出生点外侧走进房间
##
## 对应原版 World_Init 里僵尸的 State_EnterMap：实体在房间外生成，先朝出生点走，
## 走到位之后才交棒给 Chase。这个阶段故意不做地图边界夹取（zombie._physics_process
## 里对 Spawn 跳过 clamp），否则出生点在墙外的僵尸会被立刻拽回地图内。


## 判定"到位"的距离（像素）
const ARRIVE_DISTANCE: float = 2.0

## 兜底超时：超过这个时间还没走进来就强制进 Chase
## 防止出生点被墙挡住时僵尸永远停在地图外（那样它既不参与寻路也不会被发现）
const ARRIVE_TIMEOUT: float = 4.0


## 宿主（类型化，便于静态检查）
var z: Zombie:
	get:
		return actor as Zombie


func enter(_msg: Dictionary = {}) -> void:
	z.velocity = Vector2.ZERO
	# 原版 State_EnterMap 会清 mFlag_Collidable：走进来之前打不到
	z.setHittable(false)
	z.playAnim("walk")


func physicsUpdate(delta: float) -> void:
	var to: Vector2 = z.initPos - z.global_position

	# 到位，或卡太久（出生点可能在墙里/地图外）→ 进 Chase，
	# 进 Chase 后 _physics_process 会把它夹回地图内
	if to.length() <= ARRIVE_DISTANCE or stateTime > ARRIVE_TIMEOUT:
		# 精确吸附到出生点（格心），否则进 Chase 时第一次走格会从半个格子外
		# 一路插值过去，看起来就是瞬移一下
		z.global_position = z.initPos
		stateMachine.transitionTo(&"Chase")
		return

	# 朝向出生点
	var want := Zombie.angleFromVector(to)
	if want != z.angle:
		z.angle = want
		z.oldAngle = want

	# 直接朝出生点走，**不做 canStep 判定**：
	# canStep 走 ShapeCast，会命中同出生点的其他僵尸，
	# 导致一出生就互相判挡、站着不动直到 4 秒超时。
	z.moveInDirection(to, delta)
	z.playAnim("walk")
