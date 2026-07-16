extends Node2D

## 地图场景主控制器
# 负责管理整个游戏关卡的逻辑：
# - 敌人波次生成和管理
# - 玩家出生和初始化
# - 分数和连杀显示
# - 补给刷新
# - 流场更新


## 房间节点
@onready var room = $room001

## 分数显示节点
@onready var scoreNode = $ui/score

## 连杀数显示节点
@onready var countNode = $ui/count

## 连杀动画节点
@onready var countAniNode = $ui/countAni

## 敌人生成计时器
@onready var spawnTimer = $spawnTimer

## 下一波次等待计时器
@onready var nextWaveTimer = $nextWaveTimer

## 消息提示节点
@onready var toastInfo = $ui/toastInfo

## 补给刷新计时器
@onready var refreshTimer = $refreshTimer

## 是否开启调试模式（显示网格和流场）
@export var isDebug = true


## 僵尸场景预加载
var zombie = preload("res://scene/zombie.tscn")

## 箱子场景预加载
var box = preload("res://scene/box.tscn")

## 玩家场景预加载
var player = preload("res://scene/player.tscn")

## 字体资源
var font: FontFile
## 当前波次序号
var currWave = 0
## 当前波次僵尸数量（每波+2）
var zombieCount = 2
## 当前波次恶魔数量（每波+2）
var devilCount = 2
## 所有出生点及其分配的敌人数量
var allSpawnPoint = []
## 流场更新延迟（帧数）
var updateFlowFieldDelay = 60
## 流场更新计时器
var updateTimer = 0
## 最大僵尸数量限制（基于地图大小计算）
var maxZombieCount = 0
## 最大恶魔数量限制（基于地图大小计算）
var maxDevilCount = 0
## 补给刷新时间（秒）
var pickupRefreshTime = 20
## 固定箱子刷新点列表
var itemSpawnPoint = []
## 玩家出生点列表
var playerSpawnPoint = []


## 初始化
func _ready() -> void:
	# 设置地图大小
	MapData.mapSize = room.mapSize
	# 初始化流场
	updateFlowField()
	# 获取字体
	font = ThemeDB.fallback_font
	
	# 连接全局信号
	Game.enemyKilled.connect(enemyKilled)
	Game.notice.connect(notice)
	
	# 计算最大敌人数量
	maxZombieCount = int(MapData.mapSize.x * MapData.mapSize.y / MapData.cellSize)
	maxDevilCount = int(maxZombieCount / 5.0)
	
	# 设置补给刷新点和计时器
	itemSpawnPoint = room.itemSpawnPoint
	refreshTimer.wait_time = pickupRefreshTime
	refreshTimer.start()
	
	# 设置玩家出生点并生成玩家
	playerSpawnPoint = room.playerSpawnPoint
	for i in range(MapData.playerCount):
		var p = player.instantiate()
		p.global_position = playerSpawnPoint[i].global_position
		get_tree().root.call_deferred("add_child", p)
	
	# 延迟3秒后开始第一波
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(startNextWave)
	tween.play()


## 开始下一波敌人刷新
# 分配出生点和敌人数量，启动生成计时器
func startNextWave():
	SoundUtil.playStartLevel()
	
	# 获取所有敌人出生点，平均分配敌人数量
	allSpawnPoint = []
	var sp = room.zombieSpawnPoint
	var num = zombieCount / sp.size()
	for i in sp:
		allSpawnPoint.append({'obj': i, 'num': num})
	
	# 处理余数，将多余敌人分配到第一个出生点
	if num * sp.size() < zombieCount:
		allSpawnPoint[0].num += zombieCount - num * sp.size()
	
	# 启动生成计时器
	spawnTimer.start()
	
	# 显示波次开始提示
	notice('+++Level %d started!+++' % (currWave + 1), Color.GREEN)


## 添加敌人到场景
# 根据出生点信息创建敌人实例
# @param p 出生点信息（包含type和dir属性）
func addEnemy(p):
	if p.type == Game.mapSign.Zombie:
		var z = zombie.instantiate()
		z.position = p.position
		z.state = Game.enemyState.init
		z.initPos = p.position
		
		# 根据出生点方向设置初始速度和位置偏移
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


## 载入关卡（预留接口）
func loadLevel():
	pass


## 敌人被击杀处理
# 更新分数和连杀数，播放连杀动画
# @param pos 被击杀敌人的位置（Vector2）
func enemyKilled(_pos):
	# 增加连杀数
	MapData.addKillStreak(1)
	# 计算分数（基础分100 * 当前连杀倍数）
	MapData.score += 100 * MapData.currKillStreak
	
	# 更新UI显示
	scoreNode.text = str('%14d' % MapData.score)
	countNode.text = str('x', MapData.currKillStreak)
	
	# 根据连杀数调整动画速度
	@warning_ignore("integer_division")
	countAniNode.speed_scale = 1 + 0.1 * (MapData.currKillStreak / 10)
	countAniNode.play("default")


## 显示消息通知
# 在屏幕底部显示一条带颜色的提示消息
# @param s 消息文本（String）
# @param color 消息颜色（Color，默认珊瑚色）
func notice(s, color: Color = Color.CORAL):
	toastInfo.display(s, color)


## 更新流场
# 根据所有玩家的位置重新计算流场
func updateFlowField():
	var players = get_tree().get_nodes_in_group("player")
	for i in players:
		var x = floori(i.global_position.x / MapData.cellSize)
		var y = floori(i.global_position.y / MapData.cellSize)
		MapData.computeFields(i.playerId, Vector2(x, y))


## 物理帧更新
func _physics_process(_delta: float) -> void:
	# 调试模式下重绘
	if isDebug:
		queue_redraw()
	
	# 更新流场计时器
	updateTimer += 1
	if updateTimer > updateFlowFieldDelay:
		updateTimer = 0
		updateFlowField()


## 绘制调试信息
# 仅在调试模式下显示网格、障碍物和流场箭头
func _draw() -> void:
	if isDebug:
		var width = floor(MapData.mapSize.x / MapData.cellSize)
		var height = floor(MapData.mapSize.y / MapData.cellSize)
		
		# 绘制网格线
		for i in range(width + 1):
			draw_line(Vector2(i * MapData.cellSize, 0), Vector2(i * MapData.cellSize, MapData.cellSize * height), Color.GRAY, 0.5, true)
		for i in range(height + 1):
			draw_line(Vector2(0, i * MapData.cellSize), Vector2(MapData.cellSize * width, i * MapData.cellSize), Color.GRAY, 0.5, true)

		# 绘制障碍物格子（红色半透明）
		for key in MapData.obstacle.keys():
			var parts = key.split("-")
			if parts.size() != 2:
				continue
			var ox = int(parts[0])
			var oy = int(parts[1])
			draw_rect(Rect2(ox * MapData.cellSize, oy * MapData.cellSize, MapData.cellSize, MapData.cellSize),
			 Color(1, 0, 0, 0.5), true)

		# 绘制流场箭头（每个玩家一个颜色）
		for id in MapData.flowFieldDict.keys():
			var field = MapData.flowFieldDict[id]
			if typeof(field) != TYPE_DICTIONARY:
				continue
			var color = Color(0, 1, 0, 0.8)
			if id != 1:
				color = Color(1, 0.7, 0, 0.8)
			
			for x in range(width):
				for y in range(height):
					var key = "%s-%s" % [x, y]
					if not field.has(key):
						continue
					var dir = field[key]
					if dir == Vector2.ZERO:
						continue
					
					# 绘制箭头
					var center = Vector2(x * MapData.cellSize + MapData.cellSize * 0.5, y * MapData.cellSize + MapData.cellSize * 0.5)
					var arrow_len = MapData.cellSize * 0.35
					var tip = center + dir.normalized() * arrow_len
					draw_line(center, tip, color, 1.2, true)
					
					# 绘制箭头两侧的短线条
					var left = tip + dir.normalized().rotated(-PI * 0.2) * (MapData.cellSize * 0.12)
					var right = tip + dir.normalized().rotated(PI * 0.2) * (MapData.cellSize * 0.12)
					draw_line(tip, left, color, 1.2, true)
					draw_line(tip, right, color, 1.2, true)

		# 绘制鼠标位置信息
		var x = floor(get_local_mouse_position().x)
		var y = floor(get_local_mouse_position().y)
		draw_string(font, get_local_mouse_position(), "%s-%s" % [x, y],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		draw_string(font, get_local_mouse_position() + Vector2(20, 20), "%s-%s" % [floori(x / MapData.cellSize), floori(y / MapData.cellSize)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHEAT)


## 连杀动画结束回调
# 递减连杀计数，直到归零
func _on_count_ani_animation_finished() -> void:
	if MapData.currKillStreak - 1 >= 0:
		MapData.currKillStreak -= 1
		countNode.text = str('x', MapData.currKillStreak)
		
		@warning_ignore("integer_division")
		countAniNode.speed_scale = 1 + 0.1 * (MapData.currKillStreak / 10)
		
		if MapData.currKillStreak >= 0:
			countAniNode.play("default")


## 生成计时器超时回调
# 检查每个出生点，如果没有被阻挡且还有剩余敌人，生成一个敌人
func _on_spawn_timer_timeout() -> void:
	for i in allSpawnPoint:
		if !i.obj.hasBlock() && i.num > 0:
			addEnemy(i.obj)
			i.num -= 1
			await get_tree().create_timer(1).timeout
	
	# 检查是否所有敌人都已生成
	var finalNum = 0
	for i in allSpawnPoint:
		finalNum += i.num
	
	if finalNum != 0:
		# 还有敌人未生成，继续生成
		spawnTimer.start()
	else:
		# 所有敌人已生成，开始等待下一波
		nextWaveTimer.start()


## 下一波等待计时器超时回调
# 检查是否所有敌人都被消灭，如果是则开始下一波
func _on_next_wave_timer_timeout() -> void:
	var e = get_tree().get_nodes_in_group("enemy")
	if e.size() > 0:
		# 还有敌人存活，继续等待
		nextWaveTimer.start()
	else:
		# 所有敌人已消灭，进入下一波
		currWave += 1
		zombieCount += 2
		zombieCount = min(zombieCount, maxZombieCount)
		devilCount += 2
		devilCount = min(devilCount, maxDevilCount)
		startNextWave()


## 按钮点击回调（测试用）
func _on_button_pressed() -> void:
	toastInfo.display('11111111111', Color.RED)
	pass


## 补给刷新计时器超时回调
# 在所有未被占用的补给点生成箱子
func _on_refresh_timer_timeout() -> void:
	refreshTimer.start()
	for i in itemSpawnPoint:
		if !i.hasBlock():
			var b = box.instantiate()
			b.global_position = i.global_position
			get_tree().root.add_child(b)
