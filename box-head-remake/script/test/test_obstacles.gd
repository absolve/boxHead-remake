extends Node2D

## 障碍物编辑器（测试场景）
##
## 用途：地图的 `wallObstacles` 里缺格子时，直接在这里点出来并保存回 .tscn。
##
## 操作：
##   ← → / [ ]   切换地图
##   左键        添加障碍格（可按住拖拽连续画）
##   右键        删除障碍格
##   滚轮        以鼠标为锚点缩放
##   中键拖动    平移画面（WASD / 方向键也可以）
##   S           保存到当前地图的 .tscn
##   R           重新载入（丢弃未保存修改）
##   V           显示/隐藏地图贴图（只看障碍格）
##   G           显示/隐藏网格
##   C           清空本次的所有修改
##
## 视觉：
##   红色 = 场景里已有的障碍格
##   绿色 = 这次新加的（还没保存）
##   橙色 = 这次删掉的（还没保存）

## 和 test_rooms 保持一致的地图列表
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

## 方向键平移速度（屏幕像素/秒）
const PAN_SPEED: float = 600.0

var room: Node2D = null
var index: int = 0
## 鼠标所在格（-1,-1 = 不在房间内）
var hoverCell: Vector2i = Vector2i(-1, -1)
## 场景里原有障碍（Vector2i 集合）
var original: Dictionary = {}
## 本次新增 / 删除
var added: Dictionary = {}
var removed: Dictionary = {}
## 显示开关
var showArt: bool = true
var showGrid: bool = true
## 相机拖动
var dragging: bool = false
## 鼠标当前是否按着左键画格子
var painting: bool = false
var erasing: bool = false
## Shift + 拖拽 = 矩形批量加/删
var rectActive: bool = false
var rectStart: Vector2i = Vector2i(-1, -1)
var rectEnd: Vector2i = Vector2i(-1, -1)
var rectErase: bool = false

@onready var label: Label = $ui/label
@onready var hoverLabel: Label = $ui/hoverLabel
@onready var btnSave: Button = $ui/btnSave
@onready var btnReload: Button = $ui/btnReload
@onready var cam: Camera2D = $camera


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#2A2A2A"))
	hoverLabel.visible = false
	btnSave.pressed.connect(saveObstacles)
	btnReload.pressed.connect(func(): loadRoom(index))
	loadRoom(0)


# ---------------------------------------------------------------- 加载

func loadRoom(i: int) -> void:
	if room != null and is_instance_valid(room):
		remove_child(room)
		room.queue_free()
	room = null
	await get_tree().process_frame

	index = wrapi(i, 0, ROOMS.size())
	var ps: PackedScene = ResourceLoader.load(ROOMS[index], "PackedScene",
			ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	room = ps.instantiate()
	# 房间画在底层：障碍格/网格要盖在地图贴图上面才看得清
	room.z_index = -10
	add_child(room)
	await get_tree().process_frame

	original.clear()
	added.clear()
	removed.clear()
	for c in room.get("wallObstacles"):
		original[c] = true

	# 相机对准地图中心
	MapData.mapSize = room.get("mapSize")
	cam.global_position = MapData.mapSize * 0.5
	cam.zoom = Vector2.ONE
	applyArtVisibility()
	queue_redraw()


func applyArtVisibility() -> void:
	if room == null:
		return
	for n in room.get_children():
		if n is Sprite2D:
			(n as Sprite2D).visible = showArt
		elif n is CanvasItem and str(n.name).begins_with("wall"):
			(n as CanvasItem).visible = showArt


# ---------------------------------------------------------------- 当前障碍集合

## 最终障碍集合（原有 ∪ 新增 − 删除）
func currentSet() -> Dictionary:
	var out: Dictionary = {}
	for c in original:
		if not removed.has(c):
			out[c] = true
	for c in added:
		out[c] = true
	return out


func isBlocked(cell: Vector2i) -> bool:
	if removed.has(cell):
		return false
	return original.has(cell) or added.has(cell)


func inMap(cell: Vector2i) -> bool:
	var cells: Vector2i = Vector2i(
			int(MapData.mapSize.x / MapData.cellSize),
			int(MapData.mapSize.y / MapData.cellSize))
	return cell.x >= 0 and cell.y >= 0 and cell.x < cells.x and cell.y < cells.y


func paintCell(cell: Vector2i) -> void:
	if not inMap(cell):
		return
	if original.has(cell):
		if removed.has(cell):
			removed.erase(cell)
			return
		# 已经存在且要画：只把"删除"撤销
		return
	if added.has(cell):
		return
	added[cell] = true
	removed.erase(cell)
	queue_redraw()


func eraseCell(cell: Vector2i) -> void:
	if not inMap(cell):
		return
	if added.has(cell):
		added.erase(cell)
	elif original.has(cell):
		removed[cell] = true
	queue_redraw()


## 矩形批量填充（Shift + 拖拽）
func fillRect(a: Vector2i, b: Vector2i, erase: bool) -> void:
	if a.x < 0 or b.x < 0:
		return
	var x0: int = mini(a.x, b.x)
	var x1: int = maxi(a.x, b.x)
	var y0: int = mini(a.y, b.y)
	var y1: int = maxi(a.y, b.y)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if erase:
				eraseCell(Vector2i(x, y))
			else:
				paintCell(Vector2i(x, y))
	queue_redraw()


# ---------------------------------------------------------------- 保存

## 把当前集合写回 ROOMS[index] 的 `wallObstacles = [...]`
## 找到属性「整个值表达式」的 [start, end) 区间。
## 兼容：
##   prop = Array[Vector2i]([...])     Godot typed array
##   prop = [...]                      普通数组
##   prop = Vector2(1, 2)              其它值（到行尾）
func findPropValueRange(text: String, prop: String) -> Vector2i:
	var key: String = prop + " ="
	var start: int = text.find(key)
	if start < 0:
		return Vector2i(-1, -1)
	var i: int = start + key.length()
	while i < text.length() and (text[i] == " " or text[i] == "\t"):
		i += 1
	var valueStart: int = i

	# typed array：Array[Vector2i](...)
	if text.substr(i, 6) == "Array[":
		var tclose: int = text.find("]", i)
		if tclose < 0:
			return Vector2i(-1, -1)
		i = tclose + 1
		while i < text.length() and (text[i] == " " or text[i] == "\t"):
			i += 1
		if i < text.length() and text[i] == "(":
			var depth0: int = 0
			var m0: int = i
			while m0 < text.length():
				if text[m0] == "(":
					depth0 += 1
				elif text[m0] == ")":
					depth0 -= 1
					if depth0 == 0:
						break
				m0 += 1
			return Vector2i(valueStart, m0 + 1)
		return Vector2i(-1, -1)

	# 普通数组
	if i < text.length() and text[i] == "[":
		var depth: int = 0
		var j: int = i
		while j < text.length():
			if text[j] == "[":
				depth += 1
			elif text[j] == "]":
				depth -= 1
				if depth == 0:
					break
			j += 1
		return Vector2i(valueStart, j + 1)

	# 其它值：到行尾
	var lineEnd: int = text.find("\n", i)
	if lineEnd < 0:
		lineEnd = text.length()
	return Vector2i(valueStart, lineEnd)



func saveObstacles() -> void:
	var path: String = ROOMS[index]
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		toast("读不到文件：%s" % path, Color.RED)
		return

	var cells: Array = currentSet().keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	var parts: PackedStringArray = []
	for c in cells:
		parts.append("Vector2i(%d, %d)" % [c.x, c.y])
	var body: String = "[%s]" % ", ".join(parts)

	# 用和 test_spawns 同一套写法：兼容 Array[Vector2i]([...]) typed array，
	# 否则会把 "Array[Vector2i]" 里的方括号当成数组值，写坏场景文件
	var full: String = "Array[Vector2i](%s)" % body
	var r: Vector2i = findPropValueRange(text, "wallObstacles")
	if r.x < 0:
		var scriptPos: int = text.find("script = ExtResource")
		if scriptPos < 0:
			toast("找不到根节点，保存失败", Color.RED)
			return
		var lineEnd: int = text.find("\n", scriptPos)
		text = text.substr(0, lineEnd + 1) + "wallObstacles = " + full + "\n" \
				+ text.substr(lineEnd + 1)
	else:
		text = text.substr(0, r.x) + full + text.substr(r.y)

	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		toast("写入失败：%s" % path, Color.RED)
		return
	f.store_string(text)
	f.close()

	var n: int = cells.size()
	toast("已保存 %d 格到 %s" % [n, path.get_file()], Color.GREEN)
	# 保存后把"原始"更新成刚写入的，避免 added/removed 还挂着
	original = currentSet()
	added.clear()
	removed.clear()
	queue_redraw()


func toast(s: String, _color: Color) -> void:
	label.text = "%s\n\n（2 秒后恢复）" % s
	await get_tree().create_timer(2.0).timeout
	updateLabel()


# ---------------------------------------------------------------- 输入

func _unhandled_input(event: InputEvent) -> void:
	if mouseOverUi():
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					zoomAtMouse(1.15)
				return
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					zoomAtMouse(1.0 / 1.15)
				return
			MOUSE_BUTTON_LEFT:
				if mb.pressed and Input.is_key_pressed(KEY_SHIFT):
					rectActive = true
					rectErase = false
					rectStart = hoverCell
					rectEnd = hoverCell
				elif mb.pressed:
					painting = true
					paintCell(hoverCell)
				else:
					if rectActive:
						fillRect(rectStart, rectEnd, rectErase)
						rectActive = false
					painting = false
				return
			MOUSE_BUTTON_RIGHT:
				if mb.pressed and Input.is_key_pressed(KEY_SHIFT):
					rectActive = true
					rectErase = true
					rectStart = hoverCell
					rectEnd = hoverCell
				elif mb.pressed:
					erasing = true
					eraseCell(hoverCell)
				else:
					if rectActive:
						fillRect(rectStart, rectEnd, rectErase)
						rectActive = false
					erasing = false
				return
			MOUSE_BUTTON_MIDDLE:
				dragging = mb.pressed
				return

	elif event is InputEventMouseMotion:
		if dragging:
			var mm := event as InputEventMouseMotion
			cam.global_position -= mm.relative / maxf(cam.zoom.x, 0.001)
		elif rectActive:
			rectEnd = hoverCell
			queue_redraw()
		elif painting:
			paintCell(hoverCell)
		elif erasing:
			eraseCell(hoverCell)
		return

	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = (event as InputEventKey).physical_keycode
		match key:
			KEY_LEFT, KEY_BRACKETLEFT:
				loadRoom(index - 1)
			KEY_RIGHT, KEY_BRACKETRIGHT:
				loadRoom(index + 1)
			KEY_S:
				saveObstacles()
			KEY_R:
				loadRoom(index)
			KEY_V:
				showArt = not showArt
				applyArtVisibility()
				queue_redraw()
			KEY_G:
				showGrid = not showGrid
				queue_redraw()
			KEY_C:
				added.clear()
				removed.clear()
				queue_redraw()


func mouseOverUi() -> bool:
	for b in [btnSave, btnReload]:
		if b != null and b.get_global_rect().has_point(get_viewport().get_mouse_position()):
			return true
	return false


## 以鼠标为锚点缩放
func zoomAtMouse(factor: float) -> void:
	var vp: Vector2 = get_viewport_rect().size
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var before: Vector2 = cam.zoom
	var after: Vector2 = (before * factor).clamp(Vector2(0.15, 0.15), Vector2(4.0, 4.0))
	if after.is_equal_approx(before):
		return
	var off: Vector2 = mouse - vp * 0.5
	cam.zoom = after
	cam.global_position += off * before - off * after
	cam.reset_smoothing()
	queue_redraw()


# ---------------------------------------------------------------- 每帧

func _process(delta: float) -> void:
	var mp: Vector2 = get_global_mouse_position()
	var mapSize: Vector2 = MapData.mapSize
	if mp.x >= 0 and mp.y >= 0 and mp.x < mapSize.x and mp.y < mapSize.y:
		hoverCell = MapData.worldToCell(mp)
	else:
		hoverCell = Vector2i(-1, -1)

	# 方向键 / WASD 平移
	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("ui_right"):
		dir.x += 1.0
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1.0
	if Input.is_action_pressed("ui_down"):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		cam.global_position += dir.normalized() * PAN_SPEED * delta / maxf(cam.zoom.x, 0.001)

	updateHoverLabel()
	updateLabel()
	queue_redraw()


func updateHoverLabel() -> void:
	if hoverLabel == null:
		return
	if hoverCell.x < 0:
		hoverLabel.visible = false
		return
	hoverLabel.visible = true
	var center: Vector2 = MapData.cellCenter(hoverCell)
	var state: String = "空"
	if removed.has(hoverCell):
		state = "已删"
	elif added.has(hoverCell):
		state = "新增"
	elif original.has(hoverCell):
		state = "原有"
	hoverLabel.text = "第 %d 列  第 %d 行   中心 (%d, %d)   %s" % [
		hoverCell.x, hoverCell.y, int(center.x), int(center.y), state]
	var screen: Vector2 = get_viewport().get_mouse_position()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var lsize: Vector2 = hoverLabel.size
	var pos: Vector2 = screen + Vector2(18, 18)
	if pos.x + lsize.x > vp.x:
		pos.x = screen.x - lsize.x - 8
	if pos.y + lsize.y > vp.y:
		pos.y = screen.y - lsize.y - 8
	hoverLabel.position = pos


func updateLabel() -> void:
	if label == null:
		return
	var cells: Vector2i = Vector2i(
			int(MapData.mapSize.x / MapData.cellSize),
			int(MapData.mapSize.y / MapData.cellSize))
	label.text = (
			"[%d/%d] %s   %d x %d 格   障碍 原始 %d / 新增 %d / 删除 %d   "
			+ "缩放 %.2fx\n"
			+ "左键添加   右键删除   Shift+拖拽=矩形批量   滚轮缩放   中键拖动平移   WASD/方向键平移\n"
			+ "S 保存到场景   R 重新载入   V 贴图开关   G 网格   C 清空修改   ← → 切换地图") % [
		index + 1, ROOMS.size(), ROOMS[index].get_file().get_basename(),
		cells.x, cells.y, original.size(), added.size(), removed.size(), cam.zoom.x]


# ---------------------------------------------------------------- 绘制

func _draw() -> void:
	var cs: float = MapData.cellSize
	var mapSize: Vector2 = MapData.mapSize
	if mapSize == Vector2.ZERO:
		return

	# 只看障碍格时（V 关掉贴图）才铺底板，否则会盖住地图贴图
	if not showArt:
		draw_rect(Rect2(Vector2.ZERO, mapSize), Color("#EDE2CF"), true)

	# 网格
	if showGrid:
		var cells: Vector2i = Vector2i(int(mapSize.x / cs), int(mapSize.y / cs))
		var gridColor := Color(0, 0, 0, 0.12)
		for x in range(cells.x + 1):
			draw_line(Vector2(x * cs, 0), Vector2(x * cs, mapSize.y), gridColor, 1.0)
		for y in range(cells.y + 1):
			draw_line(Vector2(0, y * cs), Vector2(mapSize.x, y * cs), gridColor, 1.0)

	# 原有障碍（红）
	for c in original:
		if removed.has(c):
			continue
		var r := Rect2(c.x * cs, c.y * cs, cs, cs)
		draw_rect(r, Color(1.0, 0.15, 0.1, 0.35), true)
		draw_rect(r, Color(1.0, 0.15, 0.1, 0.85), false, 1.5)

	# 新增（绿）
	for c in added:
		var r2 := Rect2(c.x * cs, c.y * cs, cs, cs)
		draw_rect(r2, Color(0.1, 0.95, 0.3, 0.45), true)
		draw_rect(r2, Color(0.1, 0.95, 0.3, 0.95), false, 2.0)

	# 删除（橙 + 叉）
	for c in removed:
		var r3 := Rect2(c.x * cs, c.y * cs, cs, cs)
		draw_rect(r3, Color(1.0, 0.6, 0.0, 0.30), true)
		draw_rect(r3, Color(1.0, 0.6, 0.0, 0.95), false, 2.0)
		draw_line(r3.position, r3.end, Color(1.0, 0.6, 0.0, 0.95), 1.5)
		draw_line(Vector2(r3.end.x, r3.position.y), Vector2(r3.position.x, r3.end.y),
				Color(1.0, 0.6, 0.0, 0.95), 1.5)

	# Shift 矩形预览
	if rectActive and rectStart.x >= 0 and rectEnd.x >= 0:
		var x0: int = mini(rectStart.x, rectEnd.x)
		var x1: int = maxi(rectStart.x, rectEnd.x)
		var y0: int = mini(rectStart.y, rectEnd.y)
		var y1: int = maxi(rectStart.y, rectEnd.y)
		var rr := Rect2(x0 * cs, y0 * cs, (x1 - x0 + 1) * cs, (y1 - y0 + 1) * cs)
		var col := Color(1.0, 0.35, 0.2, 0.95) if rectErase else Color(0.2, 1.0, 1.0, 0.95)
		draw_rect(rr, Color(col.r, col.g, col.b, 0.18), true)
		draw_rect(rr, col, false, 2.0)

	# 悬停格
	if hoverCell.x >= 0 and inMap(hoverCell):
		var hr := Rect2(hoverCell.x * cs, hoverCell.y * cs, cs, cs)
		draw_rect(hr, Color(0.1, 0.9, 1.0, 0.22), true)
		draw_rect(hr, Color(0.1, 0.9, 1.0, 0.95), false, 2.0)
