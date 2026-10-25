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
	if ps.size() > 0:
		target = ps[0]


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
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
