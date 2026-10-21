extends Node2D

## 流场寻路测试场景
## 和 map 场景类似：加载 room_001 + 一个玩家 + 一次生成 N 只僵尸（默认 50，
## 在 Inspector 里改 zombieCount），僵尸从生成起就直接进入 Chase 追玩家。
## 用来对照 godot4flow-field demo 的群体追击行为 / 性能。

## 一次性生成的僵尸数量
@export var zombieCount: int = 50
## 测试用的僵尸移速（原版 16 太慢，看不清寻路效果）
@export var zombieSpeed: float = 50.0
## 刷怪间隔（秒），像 map 的 spawnTimer 一样逐个刷，避免一次性叠在出生点互相卡死
@export var spawnInterval: float = 0.1
## 是否显示网格 / 障碍 / 流场箭头 / FPS
@export var isDebug: bool = true

var zombie := preload("res://scene/character/zombie.tscn")
var player := preload("res://scene/character/player.tscn")
## 房间实例（room_001）
var room: Node2D = null
var font: FontFile
## 流场刷新间隔（物理帧）
var updateFlowFieldDelay := 60
var updateTimer := 0
## 已生成僵尸数
var spawnedCount := 0
## 刷怪计时器（代码创建，等价于 map 场景里的 spawnTimer）
var spawnTimer: Timer


func _ready() -> void:
	MapData.selectedMapId = 0
	MapData.playerCount = 1

	room = load("res://scene/level/room_001.tscn").instantiate()
	add_child(room)
	MapData.mapSize = room.mapSize
	updateFlowField()
	font = ThemeDB.fallback_font

	# 一个玩家当追击目标（必须在僵尸之前生成，僵尸 _ready 里要找目标）
	var p: Node2D = player.instantiate()
	p.global_position = findFreeSpawn(room.playerSpawnPoint[0].global_position)
	add_child(p)

	# 定时逐个刷僵尸（照 map 的 spawnTimer 思路）
	spawnTimer = Timer.new()
	spawnTimer.wait_time = spawnInterval
	spawnTimer.timeout.connect(spawnOneZombie)
	add_child(spawnTimer)
	spawnTimer.start()


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
		add_child(z)
		spawnedCount += 1
		return


## 按所有玩家位置重算流场（照抄 map.gd 的策略：flowDirty 立即刷 + 固定间隔刷）
func updateFlowField() -> void:
	for i in get_tree().get_nodes_in_group("player"):
		var x := floori(i.global_position.x / MapData.cellSize)
		var y := floori(i.global_position.y / MapData.cellSize)
		MapData.computeFields(i.playerId, Vector2(x, y))


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


func _draw() -> void:
	if not isDebug:
		return

	var width := int(MapData.mapSize.x / MapData.cellSize)
	var height := int(MapData.mapSize.y / MapData.cellSize)

	# 网格线
	for i in range(width + 1):
		draw_line(Vector2(i * MapData.cellSize, 0),
				Vector2(i * MapData.cellSize, MapData.cellSize * height), Color.GRAY, 0.5, true)
	for i in range(height + 1):
		draw_line(Vector2(0, i * MapData.cellSize),
				Vector2(MapData.cellSize * width, i * MapData.cellSize), Color.GRAY, 0.5, true)

	# 障碍格
	for key in MapData.obstacle.keys():
		var parts = key.split("-")
		if parts.size() != 2:
			continue
		draw_rect(Rect2(int(parts[0]) * MapData.cellSize, int(parts[1]) * MapData.cellSize,
				MapData.cellSize, MapData.cellSize), Color(1, 0, 0, 0.5), true)

	# 流场箭头
	for id in MapData.flowFieldDict.keys():
		var field = MapData.flowFieldDict[id]
		if typeof(field) != TYPE_DICTIONARY:
			continue
		for x in range(width):
			for y in range(height):
				var key := "%s-%s" % [x, y]
				if not field.has(key):
					continue
				var dir: Vector2 = field[key]
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
