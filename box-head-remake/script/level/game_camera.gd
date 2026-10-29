extends Camera2D

## 简单的跟随相机
##
## 跟随玩家并把视野限制在地图内；地图比视口小时居中。
## （项目里装了 phantom_camera 插件，但它的 API 需要额外验证，
##   这里是 40 行的等价实现，行为可预测。）


## 跟随平滑速度（越大越跟手）
@export var smoothSpeed: float = 8.0

## 相机四周至少离地图边缘多远（像素）：原版相机不会贴到地图边界
@export var edgeMargin: float = 32.0


## ---- 画面抖动（爆炸）----
## 原版是 CWorld.Shake(0, 30) + 每 25Hz tick 换向并 ×0.5。
## 但 Draw 里先 Process_Shake 再画，所以玩家看到的第一帧已经是 ±15，
## 之后 7.5 / 3.75 / …，约 0.2s 肉眼可见、0.36s 归零（640×480 舞台上约 3% 屏高）。
## 这里用连续正弦 + 指数包络还原同样的手感，避免 60Hz 步进抖动。

## 单次爆炸的可见峰值（像素）
@export var shakeImpulse: float = 15.0

## 叠加后的峰值上限：原版 Shake 里 |mShake| < 32 才允许累加，
## 可见峰值大约封顶在 31，也就是 2 倍单发
@export var shakeMax: float = 32.0

## 换向频率：原版每 40ms 换一次向 → 12.5Hz
@export var shakeFrequency: float = 12.5

## 幅度半衰期：原版每 40ms ×0.5
@export var shakeHalfLife: float = 0.04

## 低于该幅度直接归零（避免长时间亚像素抖动）
@export var shakeMin: float = 0.3


## 当前抖动幅度与相位
var shakeAmp: float = 0.0
var shakePhase: float = 0.0


## 当前跟随目标
var target: Node2D = null


## 2D 音频监听器：场景里的子节点，作为位置音效的听点
@onready var listener: AudioListener2D = $audioListener


func _ready() -> void:
	# 自己插值，不用引擎的位置平滑
	position_smoothing_enabled = false
	refreshTarget()

	# 没有 current 的监听器时，位置音效会按世界原点计算（僵尸低吼跑到地图左上角）
	listener.make_current()


func refreshTarget() -> void:
	var ps := get_tree().get_nodes_in_group("player")
	# 优先跟「活着的人类玩家」：槽位顺序里 CPU 可能排在前面，人类也可能已经倒地
	for p in ps:
		if bool(p.get("isCpu")) or bool(p.get("isDead")):
			continue
		target = p
		return
	for p in ps:
		if not bool(p.get("isCpu")):
			target = p
			return
	if ps.size() > 0:
		target = ps[0]


func _physics_process(delta: float) -> void:
	_updateShake(delta)

	if target == null or not is_instance_valid(target) \
			or bool(target.get("isCpu")) or bool(target.get("isDead")):
		refreshTarget()
		if target == null:
			return

	var vp: Vector2 = get_viewport_rect().size
	var goal: Vector2 = target.global_position

	# 地图边界用「格子网格」= (0,0)..mapSize，而不是房间内容的实际包围盒。
	# 用 mapRect 会让相机跟着墙体包围盒偏移（room_001 里整体下移 25px），
	# 而设计上红框 = mapSize，内缩 edgeMargin 正好是相机视口。
	var bounds := Rect2(Vector2.ZERO, MapData.mapSize)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		bounds = MapData.mapRect

	# 相机四周至少留 edgeMargin（默认 32px = 一格），不能贴到地图边缘
	bounds = bounds.grow(-edgeMargin)

	# 视口中心的允许范围：保证视口完整落在 bounds 内
	var minC: Vector2 = bounds.position + vp * 0.5
	var maxC: Vector2 = bounds.end - vp * 0.5

	# 地图（内缩后）比视口还小 → 居中；否则夹取
	var cx: float = (
			(bounds.position.x + bounds.size.x * 0.5)
			if minC.x > maxC.x else clampf(goal.x, minC.x, maxC.x))
	var cy: float = (
			(bounds.position.y + bounds.size.y * 0.5)
			if minC.y > maxC.y else clampf(goal.y, minC.y, maxC.y))
	var goalCenter := Vector2(cx, cy)

	# Camera2D 的 anchor_mode 决定了 position 指的是哪一点：
	#   FIXED_TOP  → position 是视口左上角
	#   DRAG_CENTER→ position 是视口中心（默认）
	# 不换算的话，改成 Fixed Top 后画面会整体偏移半个屏幕。
	# 0 = ANCHOR_MODE_FIXED_TOP，1 = ANCHOR_MODE_DRAG_CENTER
	# （Godot 4 里枚举常量名不可直接引用，用数值判断）
	var anchorFix := Vector2.ZERO
	if anchor_mode == 0:
		anchorFix = -vp * 0.5

	global_position = global_position.lerp(goalCenter + anchorFix, minf(smoothSpeed * delta, 1.0))


## 一次爆炸给相机加一下抖动（多个爆炸叠加，封顶在 shakeMax）
func shake(amount: float = -1.0) -> void:
	if not bool(MapData.mapConfig.get("screenShake", true)):
		return
	if shakeAmp <= 0.0:
		# 从峰值起步：原版第一帧就是 ±15 的硬跳，不是从 0 慢慢荡起来
		shakePhase = PI * 0.5
	shakeAmp = minf(shakeAmp + (shakeImpulse if amount < 0.0 else amount), shakeMax)


## 抖动衰减：指数包络 + 12.5Hz 正弦，写进 Camera2D.offset
## 不写 global_position —— 那是跟随插值的状态，混进去会互相打架
func _updateShake(delta: float) -> void:
	if shakeAmp > 0.0:
		if bool(MapData.mapConfig.get("screenShake", true)):
			shakeAmp *= exp(-delta * (log(2.0) / shakeHalfLife))
			shakePhase = fmod(shakePhase + TAU * shakeFrequency * delta, TAU)
			if shakeAmp < shakeMin:
				shakeAmp = 0.0
		else:
			shakeAmp = 0.0      # 设置里关掉开关：立刻停
	if shakeAmp <= 0.0:
		offset = Vector2.ZERO
		return
	# 原版是纯竖直抖动；取整避免像素画在亚像素偏移下发糊
	offset = Vector2(0.0, shakeAmp * sin(shakePhase)).round()
