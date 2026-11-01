extends Node2D

## 流场寻路测试场景
## 和 map 场景类似：加载 room_001 + 一个玩家 + 一次生成 N 只僵尸（默认 50，
## 在 Inspector 里改 zombieCount），僵尸从生成起就直接进入 Chase 追玩家。
## 用来对照 godot4flow-field demo 的群体追击行为 / 性能。


## 房间列表（和 test_rooms 一致）
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

## 当前房间下标（static：reload 场景后还能保持）
static var roomIndex: int = 0

## 一次性生成的僵尸数量
@export var zombieCount: int = 50
## 测试用的僵尸移速（原版 16 太慢，看不清寻路效果）
@export var zombieSpeed: float = 50.0
## 刷怪间隔（秒），像 map 的 spawnTimer 一样逐个刷，避免一次性叠在出生点互相卡死
@export var spawnInterval: float = 0.4
## 是否显示网格 / 障碍 / 流场箭头 / FPS
@export var isDebug: bool = true


var zombie: PackedScene = preload("res://scene/character/zombie.tscn")
var player: PackedScene = preload("res://scene/character/player.tscn")
## 房间实例（room_001）
var room: Node2D = null
var font: FontFile
## 流场刷新间隔（物理帧）
var updateFlowFieldDelay: int = 60
var updateTimer: int = 0
## 已生成僵尸数
var spawnedCount: int = 0
## 刷怪计时器（代码创建，等价于 map 场景里的 spawnTimer）
var spawnTimer: Timer


func _ready() -> void:
	# 和 map 一致：背景色 + 按 selectedMapId 加载房间（没有就回退 room_001）
	RenderingServer.set_default_clear_color(Color("#EDE2CF"))
	MapData.playerCount = 1

	# 命令行可直接指定房间：-- room=5（就是列表第 5 个）
	for a in OS.get_cmdline_user_args():
		if a.begins_with("room="):
			roomIndex = clampi(int(a.get_slice("=", 1)) - 1, 0, ROOMS.size() - 1)
	roomIndex = wrapi(roomIndex, 0, ROOMS.size())
	var path: String = ROOMS[roomIndex]
	print("[test_flow_field] 房间 %s（roomIndex=%d）" % [path, roomIndex])

	room = load(path).instantiate()
	add_child(room)
	MapData.mapSize = room.mapSize
	updateFlowField()
	font = ThemeDB.fallback_font

	# 房间外圈补一层地面色，避免视口边缘露黑（map 里由房间贴图铺满，测试场景没有 UI 遮罩）
	var ground := ColorRect.new()
	ground.color = Color("#EDE2CF")
	ground.z_index = -100
	ground.position = Vector2.ZERO
	ground.size = MapData.mapSize
	add_child(ground)

	# 左上角：当前房间 + 切换提示
	var info := Label.new()
	info.name = "roomInfo"
	info.position = Vector2(8, 6)
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	info.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.7))
	info.add_theme_constant_override("shadow_offset_x", 1)
	info.add_theme_constant_override("shadow_offset_y", 1)
	info.text = "[%d/%d] %s    ← → 切换房间   R 重开" % [
		roomIndex + 1, ROOMS.size(), path.get_file().get_basename()]
	add_child(info)

	# 一个玩家当追击目标（必须在僵尸之前生成，僵尸 _ready 里要找目标）
	var p: Node2D = player.instantiate()
	p.playerId = 1
	p.global_position = findFreeSpawn(room.playerSpawnPoint[0].global_position)
	add_child(p)

	# 测试场景给玩家开无敌：否则几十只僵尸几秒就把他打死，
	# 之后全是"无目标"状态，测不到寻路行为。
	# （player.gd 里 invincible 是 bool，invincibleTime 是倒计时，两个都要设）
	p.invincible = true
	p.invincibleTime = 0.0
	p.ani.modulate.a = 1.0
	print("[test_flow_field] 玩家已设为无敌，用于持续观察寻路")

	# 定时逐个刷僵尸（照 map 的 spawnTimer 思路）
	spawnTimer = Timer.new()
	spawnTimer.wait_time = spawnInterval
	spawnTimer.timeout.connect(spawnOneZombie)
	add_child(spawnTimer)
	spawnTimer.start()


## ← → 切换房间（重载场景，玩家/僵尸/流场全部重建）；R 重开当前房间
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = (event as InputEventKey).physical_keycode
	if key == KEY_LEFT or key == KEY_BRACKETLEFT:
		roomIndex = wrapi(roomIndex - 1, 0, ROOMS.size())
		get_tree().reload_current_scene()
	elif key == KEY_RIGHT or key == KEY_BRACKETRIGHT:
		roomIndex = wrapi(roomIndex + 1, 0, ROOMS.size())
		get_tree().reload_current_scene()
	elif key == KEY_R:
		get_tree().reload_current_scene()


## 生成一只僵尸：只在没被占住的出生点刷（照 map 的 hasBlock 判定，
## 上一只没走出出生点就换下一个点 / 等下一帧再试，避免叠在出生点上）
func spawnOneZombie() -> void:
	if spawnedCount >= zombieCount:
		spawnTimer.stop()
		return
	var points: Array = room.zombieSpawnPoint
	if points.is_empty():
		spawnTimer.stop()
		push_warning("test_flow_field: 房间没有僵尸出生点")
		return
	for i in points.size():
		var sp: Node2D = points[(spawnedCount + i) % points.size()]
		if sp.hasBlock():
			continue
		var z: Node2D = zombie.instantiate()
		z.position = sp.global_position
		z.speed = zombieSpeed
		# 按出生点的 dir 设置初始朝向（和 map.gd 一致），否则僵尸一律朝右
		z.state = Game.enemyState.init
		z.initPos = sp.global_position
		match int(sp.dir):
			Game.mapSignDir.Down:
				z.velocity = Vector2.DOWN
				z.position -= Vector2(0, 20)
			Game.mapSignDir.Up:
				z.velocity = Vector2.UP
				z.position += Vector2(0, 20)
			Game.mapSignDir.Left:
				z.velocity = Vector2.LEFT
				z.position -= Vector2(20, 0)
			Game.mapSignDir.Right:
				z.velocity = Vector2.RIGHT
				z.position += Vector2(20, 0)
		add_child(z)
		spawnedCount += 1
		return


## 按所有玩家位置重算流场（照抄 map.gd 的策略：flowDirty 立即刷 + 固定间隔刷）
func updateFlowField() -> void:
	# 多源单场（方案 A）：所有存活玩家一起当 BFS 种子
	var seeds: Array = []
	for i in get_tree().get_nodes_in_group("player"):
		if i == null or not is_instance_valid(i) or i.isDead or i.hp <= 0:
			continue
		seeds.append(MapData.worldToCell(i.global_position))
	# 旧实现：每玩家一张场（僵尸的 targetId 已改为 "multi"，不再使用）
	# var x := floori(i.global_position.x / MapData.cellSize)
	# var y := floori(i.global_position.y / MapData.cellSize)
	# MapData.computeFields(i.playerId, Vector2(x, y))
	MapData.computeFieldMulti(seeds)


## 找一个没被障碍占住的出生位置（照抄 map.gd）
func findFreeSpawn(pos: Vector2) -> Vector2:
	var cell: Vector2i = MapData.worldToCell(pos)
	if not MapData.isObstacle(cell):
		return pos

	var cs: int = int(MapData.cellSize)
	var grid := Vector2i(int(MapData.mapSize.x / cs), int(MapData.mapSize.y / cs))
	for r in range(1, 10):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var c: Vector2i = cell + Vector2i(dx, dy)
				if c.x < 0 or c.y < 0 or c.x >= grid.x or c.y >= grid.y:
					continue
				if not MapData.isObstacle(c):
					return MapData.cellCenter(c)
	return pos


## 离开测试场景时把全局状态还原，避免影响后续进 map
func _exit_tree() -> void:
	MapData.playerCount = 4
	MapData.zombieCells.clear()


func _physics_process(_delta: float) -> void:
	if isDebug:
		queue_redraw()

	if MapData.flowDirty:
		MapData.flowDirty = false
		updateTimer = 0
		updateFlowField()
		return

	updateTimer += 1
	if updateTimer > updateFlowFieldDelay:
		updateTimer = 0
		updateFlowField()


func _draw() -> void:
	if not isDebug:
		return

	var width := int(MapData.mapSize.x / MapData.cellSize)
	var height := int(MapData.mapSize.y / MapData.cellSize)

	# 只画相机可见范围：大房间（如 room_0018 是 85x85 格）全画会掉到个位数帧
	var x0 := 0
	var x1 := width
	var y0 := 0
	var y1 := height
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		var half: Vector2 = get_viewport_rect().size * 0.5 / cam.zoom
		var view := Rect2(cam.get_screen_center_position() - half, half * 2.0).grow(96.0)
		x0 = clampi(floori(view.position.x / MapData.cellSize), 0, width)
		x1 = clampi(ceili(view.end.x / MapData.cellSize), 0, width)
		y0 = clampi(floori(view.position.y / MapData.cellSize), 0, height)
		y1 = clampi(ceili(view.end.y / MapData.cellSize), 0, height)

	# 网格线
	for i in range(x0, x1 + 1):
		draw_line(Vector2(i * MapData.cellSize, y0 * MapData.cellSize),
				Vector2(i * MapData.cellSize, y1 * MapData.cellSize), Color.GRAY, 0.5, true)
	for j in range(y0, y1 + 1):
		draw_line(Vector2(x0 * MapData.cellSize, j * MapData.cellSize),
				Vector2(x1 * MapData.cellSize, j * MapData.cellSize), Color.GRAY, 0.5, true)

	# 障碍格
	for x in range(x0, x1):
		for y in range(y0, y1):
			if not MapData.obstacle.has("%d-%d" % [x, y]):
				continue
			draw_rect(Rect2(x * MapData.cellSize, y * MapData.cellSize,
					MapData.cellSize, MapData.cellSize), Color(1, 0, 0, 0.5), true)

	# 流场箭头
	for id in MapData.flowFieldDict.keys():
		var field = MapData.flowFieldDict[id]
		if typeof(field) != TYPE_DICTIONARY:
			continue
		for x in range(x0, x1):
			for y in range(y0, y1):
				var dir: Vector2 = field.get("%d-%d" % [x, y], Vector2.ZERO)
				if dir == Vector2.ZERO:
					continue
				var center := Vector2(x * MapData.cellSize + MapData.cellSize * 0.5,
						y * MapData.cellSize + MapData.cellSize * 0.5)
				var tip := center + dir.normalized() * MapData.cellSize * 0.35
				draw_line(center, tip, Color(0, 0, 0, 0.85), 1.2, true)

	# FPS 与场上僵尸数
	var info := "FPS %d  zombies %d" % [Engine.get_frames_per_second(),
			get_tree().get_nodes_in_group("enemy").size()]
	draw_string(font, Vector2(8, 18), info,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
