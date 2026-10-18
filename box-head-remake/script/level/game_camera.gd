extends Camera2D

## 简单的跟随相机
##
## 跟随玩家并把视野限制在地图内；地图比视口小时居中。
## （项目里装了 phantom_camera 插件，但它的 API 需要额外验证，
##   这里是 40 行的等价实现，行为可预测。）

## 跟随平滑速度（越大越跟手）
@export var smoothSpeed: float = 8.0

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

	var ms: Vector2 = MapData.mapSize
	var vp: Vector2 = get_viewport_rect().size
	var goal: Vector2 = target.global_position

	# 先按视口中心算出镜头应该停在哪
	# 地图比视口小就居中，否则夹在边界内
	var cx: float = ms.x * 0.5 if ms.x <= vp.x else clampf(goal.x, vp.x * 0.5, ms.x - vp.x * 0.5)
	var cy: float = ms.y * 0.5 if ms.y <= vp.y else clampf(goal.y, vp.y * 0.5, ms.y - vp.y * 0.5)
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
