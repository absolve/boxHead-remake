extends Node2D

@onready var room = $room001
@onready var scoreNode = $ui/score
@onready var countNode = $ui/count
@onready var countAniNode = $ui/countAni
@onready var spawnTimer = $spawnTimer
@onready var nextWaveTimer = $nextWaveTimer
@onready var toastInfo = $ui/toastInfo
@export var isDebug = true

var zombie = preload("res://scene/zombie.tscn")
#@onready var enemy=$zombie
var font: FontFile
#var score=0 
var count = 0
var currWave = 0 # 当前波次
var zombieCount = 20 # 每波次加2
var devilCount = 2 # 每波次加2
var allSpawnPoint = []
var updateFlowFieldDelay = 60 # 60帧
var updateTimer = 0

func _ready() -> void:
	MapData.mapSize = room.mapSize
	#MapData.astarGrid.region = Rect2i(0, 0, room.mapSize.x, room.mapSize.y)
	#MapData.astarGrid.update()
	updateFlowField()
	font = ThemeDB.fallback_font
	startNextWave()
	Game.enemyKilled.connect(enemyKilled)
	Game.weaponUpgrade.connect(weaponUpgrade)
	Game.notice.connect(notice)
	
	
func startNextWave():
	##获取所有的敌人出生点，每个出生点分配敌人产生数量
	##如果出生点被遮挡等没有遮挡后在添加敌人
	allSpawnPoint = []
	var sp = room.zombieSpawnPoint
	var num = zombieCount / sp.size()
	for i in sp:
		allSpawnPoint.append({'obj': i, 'num': num})
	if num * sp.size() < zombieCount:
		allSpawnPoint[0].num += zombieCount - num * sp.size()
	spawnTimer.start()
	notice('+++Level %d started!+++' % (currWave + 1), Color.GREEN)
	

func addEnemy(p):
	if p.type == Game.mapSign.Zombie:
		var z = zombie.instantiate()
		z.position = p.position
		z.state = Game.enemyState.init
		z.initPos = p.position
		print(z.initPos)
		if p.dir == Game.mapSignDir.Down:
			z.velocity = Vector2.DOWN
			z.position -= Vector2(0, 20)
		elif p.dir == Game.mapSignDir.Up:
			z.velocity = Vector2.UP
			z.position += Vector2(0, 20)
		elif p.dir == Game.mapSignDir.Left:
			z.velocity = Vector2.LEFT
			z.position -= Vector2(20, 0)
		elif p.dir == Game.mapSignDir.Right:
			z.velocity = Vector2.RIGHT
			z.position += Vector2(20, 0)
		get_tree().root.add_child(z)
		
#载入关卡		
func loadLevel():
	pass


func enemyKilled(pos):
	print('enemyKilled', pos)
	MapData.addKillStreak(1)
	MapData.score += 100 * MapData.currKillStreak
	scoreNode.text = str('%14d'%MapData.score)
	countNode.text = str('x', MapData.currKillStreak)
	@warning_ignore("integer_division")
	countAniNode.speed_scale = 1 + 0.1 * (MapData.currKillStreak / 10)
	countAniNode.play("default")

func weaponUpgrade(type):
	print('weaponUpgrade', type)
	pass

#通知信息
func notice(s, color: Color = Color.WHITE):
	print('notice', s)
	toastInfo.display(s, color)

func updateFlowField():
	var players = get_tree().get_nodes_in_group("player")
	for i in players:
		var x = floori(i.global_position.x / MapData.cellSize)
		var y = floori(i.global_position.y / MapData.cellSize)
		MapData.computeFields(i.playerId, Vector2(x, y))
	

func _physics_process(_delta: float) -> void:
	if isDebug:
		queue_redraw()
	updateTimer += 1
	if updateTimer > updateFlowFieldDelay:
		updateTimer = 0
		updateFlowField()
	

func _draw() -> void:
	var width = floor(MapData.mapSize.x / MapData.cellSize)
	var height = floor(MapData.mapSize.y / MapData.cellSize)
	for i in range(width + 1):
		draw_line(Vector2(i * MapData.cellSize, 0), Vector2(i * MapData.cellSize, MapData.cellSize * height), Color.GRAY, 0.5, true)
	for i in range(height + 1):
		draw_line(Vector2(0, i * MapData.cellSize), Vector2(MapData.cellSize * width, i * MapData.cellSize), Color.GRAY, 0.5, true)

	# draw obstacle cells
	for key in MapData.obstacle.keys():
		var parts = key.split("-")
		if parts.size() != 2:
			continue
		var ox = int(parts[0])
		var oy = int(parts[1])
		draw_rect(Rect2(ox * MapData.cellSize, oy * MapData.cellSize, MapData.cellSize, MapData.cellSize),
		 Color(1, 0, 0, 0.15), false, 1.0)

	# draw map tile items
	for key in MapData.mapTile.keys():
		var parts = key.split("-")
		if parts.size() != 2:
			continue
		var tx = int(parts[0])
		var ty = int(parts[1])
		draw_rect(Rect2(tx * MapData.cellSize, ty * MapData.cellSize, MapData.cellSize, MapData.cellSize),
		 Color(0, 0, 1, 0.12), false, 1.0)

	# draw flow field arrows for each player flow field
	for id in MapData.flowFieldDict.keys():
		var field = MapData.flowFieldDict[id]
		if typeof(field) != TYPE_DICTIONARY:
			continue
		var color = Color(0, 1, 0, 0.8) 
		if id != 1:
			color= Color(1, 0.7, 0, 0.8)
		for x in range(width):
			for y in range(height):
				var key = "%s-%s" % [x, y]
				if not field.has(key):
					continue
				var dir = field[key]
				if dir == Vector2.ZERO:
					continue
				var center = Vector2(x * MapData.cellSize + MapData.cellSize * 0.5, y * MapData.cellSize + MapData.cellSize * 0.5)
				var arrow_len = MapData.cellSize * 0.35
				var tip = center + dir.normalized() * arrow_len
				draw_line(center, tip, color, 1.2, true)
				var left = tip + dir.normalized().rotated(-PI * 0.2) * (MapData.cellSize * 0.12)
				var right = tip + dir.normalized().rotated(PI * 0.2) * (MapData.cellSize * 0.12)
				draw_line(tip, left, color, 1.2, true)
				draw_line(tip, right, color, 1.2, true)

	var x = floor(get_local_mouse_position().x)
	var y = floor(get_local_mouse_position().y)
	draw_string(font, get_local_mouse_position(), "%s-%s" % [x, y],
	HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
	draw_string(font, get_local_mouse_position() + Vector2(20, 20), "%s-%s" % [floori(x / MapData.cellSize), floori(y / MapData.cellSize)],
	HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)


func _on_count_ani_animation_finished() -> void:
	if MapData.currKillStreak - 1 >= 0:
		MapData.currKillStreak -= 1
		countNode.text = str('x', MapData.currKillStreak)
		@warning_ignore("integer_division")
		countAniNode.speed_scale = 1 + 0.1 * (MapData.currKillStreak / 10)
		if MapData.currKillStreak >= 0:
			countAniNode.play("default")
	

func _on_spawn_timer_timeout() -> void:
	for i in allSpawnPoint:
		if !i.obj.hasBlock() && i.num > 0:
			addEnemy(i.obj)
			i.num -= 1
			await get_tree().create_timer(1).timeout
	#是否敌人都生成完毕
	var finalNum = 0
	for i in allSpawnPoint:
		finalNum += i.num
	if finalNum != 0:
		spawnTimer.start()
	else:
		nextWaveTimer.start()


func _on_next_wave_timer_timeout() -> void:
	#开始判断是否所有敌人都被消灭
	var e = get_tree().get_nodes_in_group("enemy")
	if e.size() > 0:
		nextWaveTimer.start()
	else:
		currWave += 1
		zombieCount += 2
		devilCount += 2
		notice('+++Level %d started!+++' % (currWave + 1), Color.GREEN)
		startNextWave()
	


func _on_button_pressed() -> void:
	toastInfo.display('11111111111', Color.RED)
	pass # Replace with function body.
