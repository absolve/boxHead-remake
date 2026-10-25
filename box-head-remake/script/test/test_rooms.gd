extends Node2D

## 房间浏览测试场景
##
## 按 ← / → 切换房间，检查每个房间的尺寸、出生点、障碍格是否正常。
## 画面会叠一层调试绘制：
##   红色半透明格 = 固定障碍物（wallObstacles）
##   绿色圆点 = 玩家出生点   红色 = 僵尸   紫色 = 恶魔   蓝色 = 箱子   橙色 = 油桶
##   灰色网格 = 32px 格线


const ROOMS: Array = [
	"res://scene/level/room_001.tscn",
	"res://scene/level/room_0002.tscn",
	"res://scene/level/room_0003.tscn",
	"res://scene/level/room_0004.tscn",
	"res://scene/level/room_0005.tscn",
	"res://scene/level/room_0006.tscn",
	"res://scene/level/room_0007.tscn",
	"res://scene/level/room_0008.tscn",
	"res://scene/level/room_0009.tscn",
	"res://scene/level/room_0010.tscn",
	"res://scene/level/room_0011.tscn",
	"res://scene/level/room_0012.tscn",
	"res://scene/level/room_0013.tscn",
	"res://scene/level/room_0014.tscn",
	"res://scene/level/room_0015.tscn",
	"res://scene/level/room_0016.tscn",
	"res://scene/level/room_0017.tscn",
	"res://scene/level/room_0018.tscn",
]

## 相机模式名称
const CAM_NAMES: Array = ["正常跟随", "方向键移动"]

## 方向键移动相机的速度（px/s）
const PAN_SPEED: float = 600.0


var room: Node2D = null

## 鼠标当前所在格（-1,-1 = 不在房间内）
var hoverCell: Vector2i = Vector2i(-1, -1)

var player: Character = null

var index: int = 0

## 是否显示障碍物
var showObstacles: bool = true

## 相机模式：0 正常跟随玩家 / 1 方向键自由移动
var camMode: int = 0

## 手动相机的基准位置（按 M 切换瞬间的相机位置）
var camBase: Vector2 = Vector2.ZERO

## 相对基准位置的偏移
var camOffset: Vector2 = Vector2.ZERO

## 是否正在拖动相机
var dragging: bool = false


@onready var label: Label = $ui/label

## 跟随鼠标显示的格子坐标（场景里已摆好）
@onready var hoverLabel: Label = $ui/hoverLabel

## 障碍物显示开关（默认显示：墙体/油桶 + 红色障碍格）
@onready var toggleBtn: Button = $ui/toggleObstacles


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#EDE2CF"))
	MapData.playerCount = 1
	hoverLabel.visible = false
	toggleBtn.pressed.connect(toggleObstacles)
	loadRoom(0)


## 切换障碍物“图片”显示；红色障碍格始终显示
func toggleObstacles() -> void:
	showObstacles = not showObstacles
	toggleBtn.text = "隐藏障碍物图片" if showObstacles else "显示障碍物图片"
	applyObstacleVisibility()


## 把开关状态应用到当前房间
func applyObstacleVisibility() -> void:
	if room == null or not is_instance_valid(room):
		return
	for n in room.get_children():
		var nm: String = n.name
		if nm.begins_with("wall") or nm.begins_with("blk") or nm.begins_with("barrel"):
			if n is CanvasItem:
				(n as CanvasItem).visible = showObstacles
	queue_redraw()


## 切换相机模式：0 正常跟随玩家 / 1 方向键自由移动
func cycleCamera() -> void:
	camMode = (camMode + 1) % 2
	var cam: Camera2D = $camera
	if camMode == 0:
		# 从自由模式切回来：缩放还原成 1.0，偏移清零
		cam.zoom = Vector2.ONE
		camOffset = Vector2.ZERO
		cam.set_physics_process(true)     # 恢复 game_camera 自己的跟随
		cam.reset_smoothing()
		setPlayerFrozen(false)
	else:
		# 进入手动模式时**完全不移动相机**：以当前相机位置为基准点，
		# 之后所有平移都相对这个基准做（camOffset 从 0 开始）。
		cam.set_physics_process(false)
		setPlayerFrozen(true)
		cam.reset_smoothing()
		camBase = cam.get_screen_center_position()
		camOffset = Vector2.ZERO


## 以鼠标位置为锚点缩放（缩放前后光标下的世界点保持不动）
func zoomAtMouse(cam: Camera2D, factor: float) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var before := cam.zoom
	var newZoom: Vector2 = (before * factor).clamp(Vector2(0.1, 0.1), Vector2(3, 3))
	if newZoom.is_equal_approx(before):
		return
	# 鼠标相对屏幕中心的偏移（屏幕像素）
	var off: Vector2 = mouse - vp * 0.5
	# 该偏移对应的世界距离：缩放越大，世界距离越小
	var worldBefore: Vector2 = off * before
	var worldAfter: Vector2 = off * newZoom
	# 让光标下的世界点保持不变 → 视野中心平移 (worldBefore - worldAfter)
	cam.zoom = newZoom
	cam.global_position = cam.global_position + (worldBefore - worldAfter)
	cam.reset_smoothing()
	camOffset = cam.global_position - camBase


## 手动相机模式下冻结玩家（方向键用来移动相机）
func setPlayerFrozen(frozen: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.set_physics_process(not frozen)
	if frozen:
		player.velocity = Vector2.ZERO


## 手动模式下每帧摆放相机
func updateCamera(delta: float, _vp: Vector2) -> void:
	if camMode == 0:
		return
	var cam: Camera2D = $camera
	#var size: Vector2 = MapData.mapSize

	# 方向键自由平移（不限制在地图内，方便看边界外）
	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("ui_right"):
		dir.x += 1.0
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1.0
	if Input.is_action_pressed("ui_down"):
		dir.y += 1.0
	# 除以缩放：Godot 的 zoom 越大画面越大，世界位移要按反比换算，
	# 这样无论缩放到多少，屏幕上看起来的移动速度都恒定。
	camOffset += dir.normalized() * PAN_SPEED * delta / maxf(cam.zoom.x, 0.001)
	cam.global_position = camBase + camOffset


## 鼠标是否落在 UI（按钮/标签）上
func mouseOverUi() -> bool:
	var btn: Control = get_node_or_null("ui/toggleObstacles")
	if btn != null and btn.get_global_rect().has_point(get_viewport().get_mouse_position()):
		return true
	return false


## 加载指定房间（循环切换）
func loadRoom(i: int) -> void:
	if room != null and is_instance_valid(room):
		# 先从场景树上摘下来，保证新房间 _ready 时看不到旧房间的标记
		remove_child(room)
		room.queue_free()
	if player != null and is_instance_valid(player):
		player.queue_free()

	index = wrapi(i, 0, ROOMS.size())
	MapData.selectedMapId = index

	room = load(ROOMS[index]).instantiate()
	add_child(room)
	await get_tree().process_frame
	applyObstacleVisibility()

	player = load("res://scene/character/player.tscn").instantiate()
	player.playerId = 1
	player.invincible = true
	add_child(player)
	await get_tree().process_frame

	placePlayer()
	updateLabel()


## 把玩家放在可走区域中心
func placePlayer() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.global_position = MapData.mapSize * 0.5


func updateLabel() -> void:
	if label == null:
		return
	var cells: Vector2 = MapData.mapSize / MapData.cellSize
	var obs: Array = room.get("wallObstacles") if room != null else []
	var obsCount: int = obs.size() if obs != null else 0
	var hoverTxt := "-" if hoverCell.x < 0 else "(%d, %d)" % [hoverCell.x, hoverCell.y]
	label.text = (
			"[%d/%d] %s   %d x %d 格  (%d x %d px)   障碍 %d 格   "
			+ "鼠标格 %s   相机：%s\n← → 切换房间   R 回中心   "
			+ "M 切换相机（正常跟随/方向键移动，手动时用 [ ] 切房间）") % [
		index + 1, ROOMS.size(), ROOMS[index].get_file().get_basename(),
		int(cells.x), int(cells.y), int(MapData.mapSize.x), int(MapData.mapSize.y), obsCount, hoverTxt,
		CAM_NAMES[camMode]]


func _unhandled_input(event: InputEvent) -> void:
	# 鼠标在按钮 / 文字上时，不处理相机操作（避免点按钮顺带拖动或缩放相机）
	if event is InputEventMouse and mouseOverUi():
		return

	# 手动相机模式：滚轮缩放 / 左键按住拖动平移
	if camMode == 1:
		var cam: Camera2D = $camera
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				zoomAtMouse(cam, 1.15)
				return
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				zoomAtMouse(cam, 1.0 / 1.15)
				return
			if mb.button_index == MOUSE_BUTTON_LEFT:
				dragging = mb.pressed
				return
		elif event is InputEventMouseMotion and dragging:
			var mm := event as InputEventMouseMotion
			# 屏幕位移换算成世界位移：world = screen / zoom（zoom 越大，同样鼠标位移对应的世界位移越小）
			camOffset -= mm.relative / maxf(cam.zoom.x, 0.001)
			cam.global_position = camBase + camOffset
			return

	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = (event as InputEventKey).physical_keycode
		if key == KEY_BRACKETRIGHT or (key == KEY_RIGHT and camMode != 1):
			loadRoom(index + 1)
		elif key == KEY_BRACKETLEFT or (key == KEY_LEFT and camMode != 1):
			loadRoom(index - 1)
		elif key == KEY_R:
			placePlayer()
		elif key == KEY_M:
			cycleCamera()
			updateLabel()


func _process(delta: float) -> void:
	var mp: Vector2 = get_global_mouse_position()
	var mapSize: Vector2 = MapData.mapSize
	if mp.x >= 0 and mp.y >= 0 and mp.x < mapSize.x and mp.y < mapSize.y:
		hoverCell = MapData.worldToCell(mp)
	else:
		hoverCell = Vector2i(-1, -1)

	if hoverLabel != null:
		if hoverCell.x >= 0:
			hoverLabel.visible = true
			hoverLabel.text = "第 %d 列  第 %d 行" % [hoverCell.x, hoverCell.y]
			# 默认放在光标右下；贴近右/下边缘时翻到另一侧，保证始终可见
			var screen: Vector2 = get_viewport().get_mouse_position()
			var vp: Vector2 = get_viewport().get_visible_rect().size
			var lsize: Vector2 = hoverLabel.size
			var pos: Vector2 = screen + Vector2(16, 16)
			if pos.x + lsize.x > vp.x:
				pos.x = screen.x - lsize.x - 8
			if pos.y + lsize.y > vp.y:
				pos.y = screen.y - lsize.y - 8
			pos.x = clampf(pos.x, 2, maxf(vp.x - lsize.x - 2, 2))
			pos.y = clampf(pos.y, 2, maxf(vp.y - lsize.y - 2, 2))
			hoverLabel.position = pos
		else:
			hoverLabel.visible = false

	updateCamera(delta, get_viewport_rect().size)
	queue_redraw()


## 调试绘制：格子、障碍、出生点
func _draw() -> void:
	if room == null or not is_instance_valid(room):
		return
	var cs: float = MapData.cellSize
	var mapSize: Vector2 = MapData.mapSize

	# 格线
	var cols: int = int(mapSize.x / cs)
	var rows: int = int(mapSize.y / cs)
	for c in range(cols + 1):
		draw_line(Vector2(c * cs, 0), Vector2(c * cs, mapSize.y), Color(0, 0, 0, 0.08), 1.0)
	for r in range(rows + 1):
		draw_line(Vector2(0, r * cs), Vector2(mapSize.x, r * cs), Color(0, 0, 0, 0.08), 1.0)

	# 固定障碍物（红色半透明格）
	var staticCells: Dictionary = {}
	var obs: Array = room.get("wallObstacles")
	if obs != null:
		for cell in obs:
			var c2: Vector2i = Vector2i(cell)
			staticCells[c2] = true
			draw_rect(Rect2(c2.x * cs, c2.y * cs, cs, cs), Color(1, 0, 0, 0.22), true)
			draw_rect(Rect2(c2.x * cs, c2.y * cs, cs, cs), Color(0.8, 0, 0, 0.55), false, 1.0)

	# 动态障碍物（油桶 / 假墙等运行期生成的物体）：橙色格，和静态障碍区分开
	for key in MapData.obstacle.keys():
		var v: Vector2 = MapData.obstacle[key]
		var dc := Vector2i(int(v.x), int(v.y))
		if staticCells.has(dc):
			continue
		draw_rect(Rect2(dc.x * cs, dc.y * cs, cs, cs), Color(1.0, 0.55, 0.0, 0.25), true)
		draw_rect(Rect2(dc.x * cs, dc.y * cs, cs, cs), Color(0.9, 0.45, 0, 0.7), false, 1.0)

	# 鼠标所在格高亮
	if hoverCell.x >= 0:
		var hr := Rect2(hoverCell.x * cs, hoverCell.y * cs, cs, cs)
		draw_rect(hr, Color(0.1, 0.9, 1.0, 0.25), true)
		draw_rect(hr, Color(0.1, 0.9, 1.0, 0.9), false, 2.0)

	# 出生点：直接用房间脚本收集好的数组（room_generic 加载时已按 type 归类）
	var groups := {
		"playerSpawnPoint": Color(0.1, 1.0, 0.2, 0.9),
		"zombieSpawnPoint": Color(1.0, 0.15, 0.15, 0.9),
		"devilSpawnPoint": Color(0.8, 0.2, 1.0, 0.9),
		"itemSpawnPoint": Color(0.2, 0.6, 1.0, 0.9),
	}
	#print(room.get("playerSpawnPoint"))
	for gname in groups:
		var arr: Variant = room.get(gname)
		if arr == null or not (arr is Array):
			continue
		var col: Color = groups[gname]
		for n in arr:
			if n == null or not is_instance_valid(n) or not (n is Node2D):
				continue
			var p: Vector2 = (n as Node2D).position
			draw_circle(p, 7.0, col)
			draw_arc(p, 11.0, 0.0, TAU, 16, col, 1.5)
