extends Node2D

## 出生点 / 油桶 / 墙 编辑器（测试场景）
##
## 只编辑这四类东西，**静态障碍物（wallObstacles）只读**：
##   - 墙       wallPoint（Vector2i 数组）
##   - 油桶     barrelPoint（Vector2i 数组）
##   - 僵尸/恶魔/玩家出生点  map_sign 实例（玩家点唯一）
##
## 规则：
##   - 静态障碍格不能放东西
##   - 墙和油桶同一格互斥（放一个会把另一个顶掉）
##   - 同格最多一个僵尸点 + 一个恶魔点（可以共存，但各自不能重复）
##   - 玩家出生点唯一：放新的会把旧的挪走
##
## 操作：
##   1~6         选择：墙 / 油桶 / 僵尸点 / 恶魔点 / 玩家点 / 橡皮擦
##   左键        放置（按住可连续画）
##   右键        擦除
##   Shift+拖拽  矩形批量（墙 / 油桶 / 擦除）
##   [ ]         新出生点朝向（左/右/上/下）
##   滚轮        缩放    中键拖动 / WASD  平移
##   ← →         切换地图
##   S           保存到房间 .tscn
##   R           重新载入（丢弃修改）
##   V 贴图开关   G 网格   C 清空本次修改

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

const SIGN_SCENE: String = "res://scene/level/map_sign.tscn"
const PAN_SPEED: float = 600.0

enum Mode { Wall, Barrel, Zombie, Devil, Player, Erase }
const MODE_NAMES: Array = ["墙", "油桶", "僵尸点", "恶魔点", "玩家点", "橡皮擦"]
const DIR_NAMES: Array = ["左", "右", "上", "下"]

var mode: int = Mode.Barrel
## 新出生点的朝向（Game.mapSignDir 值）
var newDir: int = 3

var room: Node2D = null
var index: int = 0
var hoverCell: Vector2i = Vector2i(-1, -1)

## 静态障碍（只读）
var staticObs: Dictionary = {}
## 墙 / 油桶：Vector2i -> true
var walls: Dictionary = {}
var barrels: Dictionary = {}
## 出生点：{type:int, dir:int, cell:Vector2i}
var signs: Array = []
## 玩家出生点：下标就是槽位（0=1P, 1=2P, 2=3P, 3=4P）
var players: Array = []
## 当前编辑的玩家槽位
var playerSlot: int = 0

var showArt: bool = true
var showGrid: bool = true
var dragging: bool = false
var painting: bool = false
var erasing: bool = false
var rectActive: bool = false
var rectStart: Vector2i = Vector2i(-1, -1)
var rectEnd: Vector2i = Vector2i(-1, -1)
var rectErase: bool = false

@onready var label: Label = $ui/label
@onready var hoverLabel: Label = $ui/hoverLabel
@onready var cam: Camera2D = $camera
var modeButtons: Array = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#222222"))
	hoverLabel.visible = false
	modeButtons = [$ui/btn0, $ui/btn1, $ui/btn2, $ui/btn3, $ui/btn4, $ui/btn5]
	for i in range(modeButtons.size()):
		var b: Button = modeButtons[i]
		b.pressed.connect(func(): mode = i; updateLabel())
	$ui/btnSave.pressed.connect(saveScene)
	$ui/btnReload.pressed.connect(func(): loadRoom(index))
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
	room.z_index = -10
	add_child(room)
	await get_tree().process_frame

	MapData.mapSize = room.get("mapSize")

	staticObs.clear()
	for c in room.get("wallObstacles"):
		staticObs[Vector2i(c)] = true
	walls.clear()
	for c in room.get("wallPoint"):
		walls[Vector2i(c)] = true
	barrels.clear()
	for c in room.get("barrelPoint"):
		barrels[Vector2i(c)] = true

	# 玩家出生点单独按「槽位」存：数组顺序 = 1P/2P/3P/4P
	# （map.gd 用 playerSpawnPoint[slot]，所以节点声明顺序就是槽位）
	players.clear()
	signs.clear()
	for n in room.find_children("*", "Node", true, false):
		if not n.is_in_group("sign"):
			continue
		var entry: Dictionary = {
			"type": int(n.get("type")),
			"dir": int(n.get("dir")),
			"cell": MapData.worldToCell((n as Node2D).global_position),
		}
		if int(n.get("type")) == Game.mapSign.Player:
			players.append(entry)
		else:
			signs.append(entry)
	playerSlot = clampi(playerSlot, 0, slotLimit() - 1)

	cam.global_position = MapData.mapSize * 0.5
	cam.zoom = Vector2.ONE
	applyArtVisibility()
	updateLabel()
	queue_redraw()


func applyArtVisibility() -> void:
	if room == null:
		return
	for n in room.get_children():
		if n is Sprite2D or (n is CanvasItem and str(n.name).begins_with("wall")):
			(n as CanvasItem).visible = showArt


# ---------------------------------------------------------------- 数据操作

func inMap(cell: Vector2i) -> bool:
	var cells := Vector2i(
			int(MapData.mapSize.x / MapData.cellSize),
			int(MapData.mapSize.y / MapData.cellSize))
	return cell.x >= 0 and cell.y >= 0 and cell.x < cells.x and cell.y < cells.y


func signAt(cell: Vector2i, signType: int) -> Dictionary:
	for s in signs:
		if s.type == signType and s.cell == cell:
			return s
	return {}


## 可选的槽位数：已有槽 + （没满 4 个时多一个「新增」位）
func slotLimit() -> int:
	return clampi(players.size() + (1 if players.size() < 4 else 0), 1, 4)


func playerAt(cell: Vector2i) -> int:
	for i in range(players.size()):
		if players[i].cell == cell:
			return i
	return -1


func place(cell: Vector2i) -> void:
	if not inMap(cell) or staticObs.has(cell):
		return
	match mode:
		Mode.Wall:
			barrels.erase(cell)
			walls[cell] = true
		Mode.Barrel:
			walls.erase(cell)
			barrels[cell] = true
		Mode.Zombie:
			addSign(Game.mapSign.Zombie, cell)
		Mode.Devil:
			addSign(Game.mapSign.Devil, cell)
		Mode.Player:
			placePlayer(cell)
		Mode.Erase:
			eraseAt(cell)
	queue_redraw()
	updateLabel()


func addSign(signType: int, cell: Vector2i) -> void:
	if not signAt(cell, signType).is_empty():
		return
	signs.append({"type": signType, "dir": newDir, "cell": cell})


## 放置玩家出生点：每个槽位最多一个
##   选中槽已有 → 移动它
##   选中槽 = 已有数量 → 新增下一个槽（1P→2P→3P→4P）
func placePlayer(cell: Vector2i) -> void:
	playerSlot = clampi(playerSlot, 0, slotLimit() - 1)
	var entry: Dictionary = {"type": Game.mapSign.Player, "dir": newDir, "cell": cell}
	if playerSlot < players.size():
		players[playerSlot] = entry
	else:
		# 最多 4 个槽位（P1~P4），第 5 个不加
		if players.size() < 4:
			players.append(entry)


func eraseAt(cell: Vector2i) -> void:
	walls.erase(cell)
	barrels.erase(cell)
	for i in range(players.size() - 1, -1, -1):
		if players[i].cell == cell:
			players.remove_at(i)
	for i in range(signs.size() - 1, -1, -1):
		var s: Dictionary = signs[i]
		if s.cell != cell:
			continue
		if s.type in [Game.mapSign.Zombie, Game.mapSign.Devil]:
			signs.remove_at(i)


func fillRect(a: Vector2i, b: Vector2i) -> void:
	if a.x < 0 or b.x < 0:
		return
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			var cell := Vector2i(x, y)
			if rectErase:
				eraseAt(cell)
			else:
				place(cell)
	queue_redraw()
	updateLabel()


# ---------------------------------------------------------------- 保存

func cellList(cellSet: Dictionary) -> Array:
	var arr: Array = cellSet.keys()
	arr.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	return arr


func formatCells(cells: Array) -> String:
	cells = cells.duplicate()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	var parts: PackedStringArray = []
	for c in cells:
		parts.append("Vector2i(%d, %d)" % [c.x, c.y])
	return "[%s]" % ", ".join(parts)


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


## 替换场景文本里的数组属性（wallPoint / barrelPoint）
## 统一写成 Godot 的 typed array 形式
func replaceArrayProp(text: String, prop: String, cells: Array) -> String:
	var body: String = "Array[Vector2i](%s)" % formatCells(cells)
	var r: Vector2i = findPropValueRange(text, prop)
	if r.x < 0:
		var key: String = prop + " ="
		var sp: int = text.find("script = ExtResource")
		if sp < 0:
			return text
		var le: int = text.find("\n", sp)
		return text.substr(0, le + 1) + key + " " + body + "\n" + text.substr(le + 1)
	return text.substr(0, r.x) + body + text.substr(r.y)



func findSignExtId(text: String) -> String:
	var idx: int = text.find(SIGN_SCENE)
	if idx < 0:
		return ""
	var lineStart: int = text.rfind("[ext_resource", idx)
	var lineEnd: int = text.find("\n", idx)
	var line: String = text.substr(lineStart, lineEnd - lineStart)
	# 注意：uid="..." 里也含 id="，必须带前导空格再找
	var p: int = line.find(" id=\"")
	if p < 0:
		return ""
	var rest: String = line.substr(p + 5)
	return rest.substr(0, rest.find("\""))


func signBlock(signType: int, dir: int, cell: Vector2i, signId: String, nodeName: String) -> String:
	var c: Vector2 = MapData.cellCenter(cell)
	return "[node name=\"%s\" parent=\".\" instance=ExtResource(\"%s\")]\nposition = Vector2(%d, %d)\ntype = %d\ndir = %d\n" % [
		nodeName, signId, int(c.x), int(c.y), signType, dir]


func saveScene() -> void:
	var path: String = ROOMS[index]
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		toast("读不到文件：%s" % path, Color.RED)
		return

	text = replaceArrayProp(text, "wallPoint", cellList(walls))
	text = replaceArrayProp(text, "barrelPoint", cellList(barrels))

	var signId: String = findSignExtId(text)
	if signId.is_empty():
		toast("场景里没有 map_sign 的 ext_resource，保存失败", Color.RED)
		return

	# 删掉旧的出生点节点块（从 [node 到下一个 [node 之前）
	var lines: PackedStringArray = text.split("\n")
	var out: PackedStringArray = []
	var skipping: bool = false
	for line in lines:
		var l: String = line.strip_edges()
		if l.begins_with("[node "):
			skipping = ("instance=ExtResource(\"%s\")" % signId) in l
		if skipping:
			continue
		out.append(line)
	text = "\n".join(out)
	if not text.ends_with("\n"):
		text += "\n"

	# 依次生成：玩家（按槽位顺序，1P→4P） → 僵尸 → 恶魔 → 箱子
	# 玩家必须保持槽位顺序：map.gd 用 playerSpawnPoint[slot] 取出生点
	var idx: int = 1
	for p in players:
		var nm: String = "mapSign" if idx == 1 else "mapSign%d" % idx
		text += "\n" + signBlock(Game.mapSign.Player, int(p.dir), p.cell, signId, nm)
		idx += 1

	var sorted: Array = signs.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.type != b.type:
			return a.type < b.type
		if a.cell.y != b.cell.y:
			return a.cell.y < b.cell.y
		return a.cell.x < b.cell.x)
	for s in sorted:
		var nm2: String = "mapSign" if idx == 1 else "mapSign%d" % idx
		text += "\n" + signBlock(int(s.type), int(s.dir), s.cell, signId, nm2)
		idx += 1

	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		toast("写入失败：%s" % path, Color.RED)
		return
	f.store_string(text)
	f.close()

	var playerCells: PackedStringArray = []
	for p2 in players:
		playerCells.append("P%d(%d,%d)" % [players.find(p2) + 1, p2.cell.x, p2.cell.y])
	toast("已保存：墙 %d / 油桶 %d / 出生点 %d   玩家槽：%s" % [
		walls.size(), barrels.size(), signs.size(), " ".join(playerCells)], Color.GREEN)
	loadRoom(index)


func toast(s: String, color: Color) -> void:
	label.text = "%s" % s
	label.add_theme_color_override("font_color", color)


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
					rectErase = mode == Mode.Erase
					rectStart = hoverCell
					rectEnd = hoverCell
				elif mb.pressed:
					painting = true
					place(hoverCell)
				else:
					if rectActive:
						fillRect(rectStart, rectEnd)
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
					eraseAt(hoverCell)
					queue_redraw()
					updateLabel()
				else:
					if rectActive:
						fillRect(rectStart, rectEnd)
						rectActive = false
					erasing = false
				return
			MOUSE_BUTTON_MIDDLE:
				dragging = mb.pressed
				return

	elif event is InputEventMouseMotion:
		if dragging:
			cam.global_position -= (event as InputEventMouseMotion).relative / maxf(cam.zoom.x, 0.001)
		elif rectActive:
			rectEnd = hoverCell
			queue_redraw()
		elif painting:
			place(hoverCell)
		elif erasing:
			eraseAt(hoverCell)
			queue_redraw()
		return

	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int = (event as InputEventKey).physical_keycode
		match key:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				mode = key - KEY_1
				updateLabel()
			KEY_COMMA:
				playerSlot = wrapi(playerSlot - 1, 0, slotLimit())
				updateLabel()
			KEY_PERIOD:
				playerSlot = wrapi(playerSlot + 1, 0, slotLimit())
				updateLabel()
			KEY_BRACKETLEFT:
				newDir = wrapi(newDir - 1, 0, 4)
				updateLabel()
			KEY_BRACKETRIGHT:
				newDir = wrapi(newDir + 1, 0, 4)
				updateLabel()
			KEY_LEFT:
				loadRoom(index - 1)
			KEY_RIGHT:
				loadRoom(index + 1)
			KEY_S:
				saveScene()
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
				loadRoom(index)


func mouseOverUi() -> bool:
	var mp: Vector2 = get_viewport().get_mouse_position()
	for b in modeButtons:
		if b != null and b.get_global_rect().has_point(mp):
			return true
	for b in [$ui/btnSave, $ui/btnReload]:
		if b != null and b.get_global_rect().has_point(mp):
			return true
	return false


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
	queue_redraw()


func describeCell(cell: Vector2i) -> String:
	if staticObs.has(cell):
		return "静态障碍（只读）"
	var parts: PackedStringArray = []
	if walls.has(cell):
		parts.append("墙")
	if barrels.has(cell):
		parts.append("油桶")
	for i in range(players.size()):
		if players[i].cell == cell:
			parts.append("玩家点 P%d" % (i + 1))
	for s in signs:
		if s.cell != cell:
			continue
		match int(s.type):
			Game.mapSign.Zombie:
				parts.append("僵尸点")
			Game.mapSign.Devil:
				parts.append("恶魔点")
			Game.mapSign.Box:
				parts.append("箱子点")
	return "、".join(parts) if not parts.is_empty() else "空"


func updateHoverLabel() -> void:
	if hoverLabel == null:
		return
	if hoverCell.x < 0:
		hoverLabel.visible = false
		return
	hoverLabel.visible = true
	var center: Vector2 = MapData.cellCenter(hoverCell)
	hoverLabel.text = "第 %d 列  第 %d 行   中心 (%d, %d)   %s" % [
		hoverCell.x, hoverCell.y, int(center.x), int(center.y), describeCell(hoverCell)]
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
	var zombies := 0
	var devils := 0
	var boxes := 0
	for s in signs:
		match int(s.type):
			Game.mapSign.Zombie:
				zombies += 1
			Game.mapSign.Devil:
				devils += 1
			Game.mapSign.Box:
				boxes += 1
	# 玩家槽位列表：P1(304,256) P2(338,256) …
	var slotTxt: PackedStringArray = []
	for i in range(players.size()):
		slotTxt.append("P%d(%d,%d)" % [i + 1, players[i].cell.x, players[i].cell.y])
	if players.is_empty():
		slotTxt.append("无")
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1))
	label.text = (
			"[%d/%d] %s   静态障碍 %d（只读）   墙 %d   油桶 %d   缩放 %.2fx\n"
			+ "出生点：僵尸 %d / 恶魔 %d / 箱子 %d\n"
			+ "玩家槽（%d 个）：%s   当前编辑：P%d   , . 切换槽位\n"
			+ "当前：%s   新点朝向：%s   1~6 选类型   左键放   右键擦   Shift+拖拽=矩形   [ ] 朝向\n"
			+ "S 保存   R 重载   V 贴图   G 网格   C 撤销全部   ← → 切换地图") % [
		index + 1, ROOMS.size(), ROOMS[index].get_file().get_basename(),
		staticObs.size(), walls.size(), barrels.size(), cam.zoom.x,
		zombies, devils, boxes,
		players.size(), " ".join(slotTxt), playerSlot + 1,
		MODE_NAMES[mode], DIR_NAMES[newDir]]


# ---------------------------------------------------------------- 绘制

## 画一个出生点标记（圆圈 + 文字 + 朝向箭头；selected = 当前编辑的玩家槽）
func drawSignMarker(font: Font, center: Vector2, col: Color, ch: String,
		dir: int, selected: bool) -> void:
	var cs: float = MapData.cellSize
	draw_circle(center, cs * 0.3, Color(col.r, col.g, col.b, 0.30))
	draw_arc(center, cs * 0.3, 0, TAU, 20, col, 2.5 if selected else 1.5)
	var wide: bool = ch.length() > 1
	draw_string(font, center + Vector2(-cs * (0.34 if wide else 0.20), cs * 0.22), ch,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(cs * (0.52 if wide else 0.62)), col)
	var dv: Vector2 = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN][clampi(dir, 0, 3)]
	draw_line(center, center + dv * cs * 0.42, Color(col.r, col.g, col.b, 0.9), 2.0)
	if selected:
		draw_arc(center, cs * 0.44, 0, TAU, 24, Color(1, 1, 1, 0.9), 2.0)


func _draw() -> void:
	var cs: float = MapData.cellSize
	var mapSize: Vector2 = MapData.mapSize
	if mapSize == Vector2.ZERO:
		return
	if not showArt:
		draw_rect(Rect2(Vector2.ZERO, mapSize), Color("#E8DFCB"), true)

	var cells := Vector2i(int(mapSize.x / cs), int(mapSize.y / cs))
	if showGrid:
		var gridColor := Color(0, 0, 0, 0.10)
		for x in range(cells.x + 1):
			draw_line(Vector2(x * cs, 0), Vector2(x * cs, mapSize.y), gridColor, 1.0)
		for y in range(cells.y + 1):
			draw_line(Vector2(0, y * cs), Vector2(mapSize.x, y * cs), gridColor, 1.0)

	# 静态障碍（只读，深灰）
	for c in staticObs:
		var r := Rect2(c.x * cs, c.y * cs, cs, cs)
		draw_rect(r, Color(1.0, 0.15, 0.1, 0.35), true)
		draw_rect(r, Color(1.0, 0.15, 0.1, 0.85), false, 1.5)

	# 墙（蓝）
	for c in walls:
		var r2 := Rect2(c.x * cs, c.y * cs, cs, cs)
		draw_rect(r2, Color(0.25, 0.55, 1.0, 0.55), true)
		draw_rect(r2, Color(0.25, 0.55, 1.0, 0.95), false, 1.5)

	# 油桶（橙圆）
	for c in barrels:
		draw_circle(Vector2(c.x * cs + cs * 0.5, c.y * cs + cs * 0.5), cs * 0.32,
				Color(1.0, 0.55, 0.1, 0.75))

	# 玩家出生点：按槽位画 P1~P4（各自颜色 + 槽号）
	var font: Font = ThemeDB.fallback_font
	var playerColors: Array = [
		Color(1.0, 0.9, 0.15), Color(0.25, 0.85, 1.0),
		Color(0.4, 1.0, 0.5), Color(1.0, 0.55, 0.3),
	]
	for i in range(players.size()):
		var p: Dictionary = players[i]
		var pc: Vector2 = MapData.cellCenter(p.cell)
		var col: Color = playerColors[i % playerColors.size()]
		drawSignMarker(font, pc, col, "P%d" % (i + 1), int(p.dir), i == playerSlot)

	# 其他出生点（同格有多个时左右错开，僵尸+恶魔都看得见）
	var byCell: Dictionary = {}
	for s in signs:
		if not byCell.has(s.cell):
			byCell[s.cell] = []
		byCell[s.cell].append(s)
	for s in signs:
		var group: Array = byCell[s.cell]
		var gi: int = group.find(s)
		var offX: float = (gi - (group.size() - 1) * 0.5) * cs * 0.30
		var center: Vector2 = MapData.cellCenter(s.cell) + Vector2(offX, 0)
		var col2 := Color.WHITE
		var ch := "?"
		match int(s.type):
			Game.mapSign.Zombie:
				col2 = Color(0.2, 1.0, 0.3)
				ch = "Z"
			Game.mapSign.Devil:
				col2 = Color(0.85, 0.35, 1.0)
				ch = "D"
			Game.mapSign.Box:
				col2 = Color(0.6, 0.6, 0.6)
				ch = "B"
		drawSignMarker(font, center, col2, ch, int(s.dir), false)

	# 矩形预览
	if rectActive and rectStart.x >= 0 and rectEnd.x >= 0:
		var x0: int = mini(rectStart.x, rectEnd.x)
		var x1: int = maxi(rectStart.x, rectEnd.x)
		var y0: int = mini(rectStart.y, rectEnd.y)
		var y1: int = maxi(rectStart.y, rectEnd.y)
		var rr := Rect2(x0 * cs, y0 * cs, (x1 - x0 + 1) * cs, (y1 - y0 + 1) * cs)
		var col2 := Color(1.0, 0.35, 0.2, 0.95) if rectErase else Color(0.2, 1.0, 1.0, 0.95)
		draw_rect(rr, Color(col2.r, col2.g, col2.b, 0.15), true)
		draw_rect(rr, col2, false, 2.0)

	# 悬停格
	if hoverCell.x >= 0 and inMap(hoverCell):
		var hr := Rect2(hoverCell.x * cs, hoverCell.y * cs, cs, cs)
		draw_rect(hr, Color(0.1, 0.9, 1.0, 0.18), true)
		draw_rect(hr, Color(0.1, 0.9, 1.0, 0.95), false, 2.0)
