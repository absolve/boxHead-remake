extends Node2D

## 地图场景主控制器
# 负责管理整个游戏关卡的逻辑：
# - 敌人波次生成和管理
# - 玩家出生和初始化
# - 分数和连杀显示
# - 补给刷新
# - 流场更新


## 飘分最低显示阈值：低于这个分数不弹 "+N"
## （连杀倍率 1 时的 100 分太频繁，不显示；倍率 ≥2 才飘）
const SCORE_POPUP_MIN: int = 200

## 敌人速度倍率（原版 CUpgrades：SpeedUp = min(1 + 等级/10, 5)）
##
## 等级 = currWave + 1（currWave 从 0 开始，进第一关时是 1）。
## 上限 5 倍：僵尸 16 -> 80 px/s，恶魔 32 -> 160 px/s。
const ENEMY_SPEED_MAX_MUL: float = 5.0


## 是否开启调试模式（显示网格和流场）
@export var isDebug: bool = true


## 房间节点
## 当前房间（运行时由 swapRoom 按 selectedMapId 创建）
var room: Node2D = null

## 僵尸场景预加载
var zombie: PackedScene = preload("res://scene/character/zombie.tscn")

var devil: PackedScene = preload("res://scene/character/devil.tscn")

## 箱子场景预加载
var box: PackedScene = preload("res://scene/item/box.tscn")

## 玩家场景预加载
var player: PackedScene = preload("res://scene/character/player.tscn")

## 字体资源
var font: FontFile

## 当前波次序号
var currWave: int = 0

## 当前波次僵尸总数
# 原版曲线：第 L 关 = 5L + 5，即 10 / 15 / 20 / 25 / 30 …（见 applyWaveQuota）
var zombieCount: int = 10

## 当前波次恶魔总数
# 原版曲线：第 1 关 0 只，之后约 floor(0.25L + 0.5)，即 0 / 1 / 1 / 1 / 1 / 2 …
var devilCount: int = 0

## 所有出生点及其分配的敌人数量
var allSpawnPoint: Array = []

## 流场更新延迟（帧数）
var updateFlowFieldDelay: int = 60

## 流场更新计时器
var updateTimer: int = 0

## 同屏僵尸上限
# 原版 Zombie_Count：min(5L + 5, 60)，即前 11 关逐关放开、之后恒定 60
var maxZombieCount: int = 10

## 同屏恶魔上限
# 原版 Devil_Count：每 4 关 +1，第 16 关封顶 5
var maxDevilCount: int = 0

## 补给刷新时间（秒）
var pickupRefreshTime: int = 20

## 固定箱子刷新点列表
var itemSpawnPoint: Array = []

## 玩家出生点列表
var playerSpawnPoint: Array = []

var zombieSound: Array = [] # 僵尸声音列表

var zombieAmbience: Array[AudioStream] = [] # 僵尸低吼候选（4 个）

var isGameOver: bool = false # 游戏结束

var awaitingResurrectionPlayer: Array = [] # 等待复活的玩家列表


## 分数显示节点
@onready var scoreNode: Label = $ui/score

## 连杀数显示节点
@onready var countNode: Label = $ui/count

## 连杀动画节点
@onready var countAniNode: AnimatedSprite2D = $ui/countAni

## 敌人生成计时器
@onready var spawnTimer: Timer = $spawnTimer

## 下一波次等待计时器
@onready var nextWaveTimer: Timer = $nextWaveTimer

## 消息提示节点
@onready var toastInfo: Control = $ui/toastInfo

## 补给刷新计时器
@onready var refreshTimer: Timer = $refreshTimer

## 僵尸声音播放计时器
@onready var soundTimer: Timer = $soundTimer

@onready var resurrectionTimer: Timer = $resurrectionTimer


## 初始化
func _ready() -> void:
	# 按 selectedMapId 创建房间（必须在用到 room 之前）
	swapRoom()

	RenderingServer.set_default_clear_color(Color("#EDE2CF"))
	# 设置地图大小
	MapData.mapSize = room.mapSize
	# 初始化流场
	updateFlowField()
	# 获取字体
	font = ThemeDB.fallback_font

	# 连接全局信号
	Game.enemyKilled.connect(enemyKilled)
	Game.notice.connect(notice)
	Game.playerDead.connect(playerDead)

	# 难度：原版 CUpgrades.SetDifficulty 只做两件事——跳级 + 提升起始得分倍率
	#   难度 1 BEGINNER     -> 等级 1，倍率 0
	#   难度 2 INTERMEDIATE -> 等级 10，倍率 9
	#   难度 3 EXPERT       -> 等级 20，倍率 29
	#   难度 4 NIGHTMARE    -> 等级 35，倍率 49
	applyDifficulty()

	# 按原版曲线给当前关定配额
	applyWaveQuota()

	# 设置补给刷新点和计时器
	itemSpawnPoint = room.itemSpawnPoint
	refreshTimer.wait_time = pickupRefreshTime
	refreshTimer.start()

	# 设置玩家出生点并生成玩家
	playerSpawnPoint = room.playerSpawnPoint
	for i in range(MapData.playerCount):
		var p = player.instantiate()
		# playerId 决定用哪套按键（p1_*/p2_*/p3_*/p4_*）和颜色，必须逐个指定
		p.playerId = i + 1
		p.global_position = findFreeSpawn(playerSpawnPoint[i].global_position)
		add_child.call_deferred(p)

	# 延迟3秒后开始第一波
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(startNextWave)
	tween.play()
	# 初始化僵尸声音列表
	zombieSound.append($zombieSound)
	zombieSound.append($zombieSound2)

	# 僵尸低吼候选池（原版 Creature.Zombie.Ambience.1-4，每次随机播一个）
	for i in range(1, 5):
		zombieAmbience.append(load("res://sound/%d_%d Creature.Zombie.Ambience.%d.mp3"
				% [541 + i, 541 + i, i]))
	# one_shot 定时器必须手动开第一次，否则永远不会触发
	soundTimer.start(randi() % 7 + 7)


## 按原版曲线算出第 wave 关（从 1 开始）的刷怪配额
#
# 数值来源：原版 Boxhead: 2Play Rooms 的 CUpgrades.InitLists()（见 doc/04-enemy-stats.md §7）
#   僵尸总数   = 5L + 5                     → 10 / 15 / 20 / 25 / 30 …
#   僵尸同屏   = min(5L + 5, 60)            → 前 11 关逐关放开，之后恒 60
#   恶魔总数   = L == 1 ? 0 : floor(0.25L + 0.5)      → 0 / 1 / 1 / 1 / 1 / 2 / 2 / 2 / 2 / 3 …
#   恶魔同屏   = L == 1 ? 0 : min(floor(1 + 0.3(L-2)), 5) → 0 / 1 / 1 / 1 / 1 / 2 … 第 16 关封顶 5
## 应用难度：跳级 + 起始得分倍率（原版 CUpgrades.SetDifficulty）
##
## mapConfig.difficulty 存 1..4（UI 的下标 +1），原版是 0..3，这里做一次映射。
func applyDifficulty() -> void:
	var diff: int = int(MapData.mapConfig.get("difficulty", 1))
	var startLevel := 1
	var startMult := 0
	match diff:
		2:
			startLevel = 10
			startMult = 9
		3:
			startLevel = 20
			startMult = 29
		4:
			startLevel = 35
			startMult = 49
		_:
			startLevel = 1
			startMult = 0

	currWave = startLevel - 1
	MapData.currKillStreak = startMult
	print("[%s] 难度 %d：起始等级 %d，起始倍率 %d" % [name, diff, startLevel, startMult])


func enemySpeedMul(level: int) -> float:
	return minf(1.0 + float(maxi(level, 1)) / 10.0, ENEMY_SPEED_MAX_MUL)


func waveQuota(wave: int) -> Dictionary:
	var l: int = maxi(wave, 1)
	# 恶魔：第 1 关没有，之后总数每 4 关 +1；同屏上限涨得稍快，第 16 关封顶 5
	var devilTotal: int = 0 if l <= 1 else floori(0.25 * l + 0.5)
	var devilAlive: int = 0 if l <= 1 else mini(floori(1.0 + 0.3 * (l - 2)), 5)
	return {
		'zombie': 5 * l + 5,
		'zombieAlive': mini(5 * l + 5, 60),
		'devil': devilTotal,
		'devilAlive': mini(devilAlive, devilTotal),
	}


## 把当前波次的配额写进 zombieCount / devilCount / maxZombieCount / maxDevilCount
func applyWaveQuota() -> void:
	var q := waveQuota(currWave + 1)
	zombieCount = q.zombie
	maxZombieCount = q.zombieAlive
	devilCount = q.devil
	maxDevilCount = q.devilAlive


## 开始下一波敌人刷新
# 分配出生点和敌人数量，启动生成计时器
func startNextWave() -> void:
	SoundUtil.playStartLevel()

	# 获取所有敌人出生点，平均分配敌人数量
	allSpawnPoint = []
	var sp = room.zombieSpawnPoint
	if sp.size() <= 0:
		# 房间没摆僵尸出生点：跳过本波，避免除零
		push_warning("startNextWave: room.zombieSpawnPoint 为空，跳过第 %d 波" % (currWave + 1))
		nextWaveTimer.start()
		return
	var num: int = zombieCount / sp.size()
	for i in sp:
		allSpawnPoint.append({'obj': i, 'num': num})

	# 处理余数，将多余敌人分配到第一个出生点
	if num * sp.size() < zombieCount:
		allSpawnPoint[0].num += zombieCount - num * sp.size()

	# 恶魔：按 devilCount 分配到恶魔出生点（原版 Devil_Count）
	if devilCount > 0 and room.devilSpawnPoint.size() > 0:
		var dsp: Array = room.devilSpawnPoint
		var dnum: int = maxi(devilCount / dsp.size(), 1)
		for i in dsp:
			allSpawnPoint.append({'obj': i, 'num': dnum})
		print("[%s] 本波恶魔 %d 只，出生点 %d 个" % [name, devilCount, dsp.size()])

	# 启动生成计时器
	spawnTimer.start()

	# 显示波次开始提示
	notice('+++Level %d +++' % (currWave + 1), Color.GREEN)


## 添加敌人到场景
# 根据出生点信息创建敌人实例
# @param p 出生点信息（包含type和dir属性）
func addEnemy(p: Node2D) -> void:
	if p.type == Game.mapSign.Zombie:
		var z = zombie.instantiate()
		z.position = p.position
		z.state = Game.enemyState.init
		z.initPos = p.position
		# 按关卡提速（基数是场景里配置的速度，最高 5 倍）
		z.speed = z.speed * enemySpeedMul(currWave + 1)

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

		get_tree().current_scene.add_child(z)
	elif p.type == Game.mapSign.Devil:
		var d = devil.instantiate()
		d.position = p.position
		# Devil 没有 initPos（那是僵尸进场所需），只用 state 控制初始状态
		if "state" in d:
			d.state = Game.enemyState.init
		# 按关卡提速（最高 5 倍）
		if "speed" in d:
			d.speed = d.speed * enemySpeedMul(currWave + 1)
		# 和僵尸一样按出生点方向设置初速与偏移
		if p.dir == Game.mapSignDir.Down:
			d.velocity = Vector2.DOWN
			d.position -= Vector2(0, 20)
		elif p.dir == Game.mapSignDir.Up:
			d.velocity = Vector2.UP
			d.position += Vector2(0, 20)
		elif p.dir == Game.mapSignDir.Left:
			d.velocity = Vector2.LEFT
			d.position -= Vector2(20, 0)
		elif p.dir == Game.mapSignDir.Right:
			d.velocity = Vector2.RIGHT
			d.position += Vector2(20, 0)
		get_tree().current_scene.add_child(d)


## 载入关卡（预留接口）
func loadLevel() -> void:
	pass


## 敌人被击杀处理
# 更新分数和连杀数，播放连杀动画
# @param pos 被击杀敌人的位置（Vector2）
func enemyKilled(pos: Vector2, baseScore: int = 100) -> void:
	# 增加连杀数
	MapData.addKillStreak(1)
	# 计算分数：基础分（僵尸 100 / 恶魔 1000）× 当前连杀倍率
	var gained: int = baseScore * maxi(MapData.currKillStreak, 1)
	MapData.score += gained

	# 死亡点飘分（原版 CHud.AddScore）
	spawnScorePopup(pos, gained)

	# 更新UI显示
	scoreNode.text = str('%d' % MapData.score).pad_zeros(14)
	countNode.text = str('x', MapData.currKillStreak)

	# 根据连杀数调整动画速度
	@warning_ignore("integer_division")
	countAniNode.speed_scale = 1 + 0.1 * (MapData.currKillStreak / 10)
	countAniNode.play("default")

	if MapData.currKillStreak > 0  and  MapData.currKillStreak%MapData.killRewardBox == 0:
		var boxs = get_tree().get_nodes_in_group("box")
		var flag = true
		var tempPos = Vector2(int(pos.x / MapData.cellSize), int(pos.y / MapData.cellSize))
		for i in boxs:
			if tempPos.is_equal_approx(Vector2(int(i.global_position.x / MapData.cellSize),
					int(i.global_position.x / MapData.cellSize))):
				flag = true
				break
		if not flag:
			var temp = box.instantiate()
			temp.global_position = tempPos * MapData.cellSize + MapData.cellSize / 2
			temp.expiredTime = 15
			add_child(temp)


## 显示消息通知
# 在屏幕底部显示一条带颜色的提示消息
# @param s 消息文本（String）
# @param color 消息颜色（Color，默认珊瑚色）
func notice(s: String, color: Color = Color.CORAL) -> void:
	toastInfo.display(s, color)


## 更新流场
# 多源单场（doc/future-improvements.md 方案 A）：
# 所有存活玩家一起当 BFS 种子，整张图只维护一张"指向最近玩家"的场。
func updateFlowField() -> void:
	var alive: Array = []
	var seeds: Array = []
	for i in get_tree().get_nodes_in_group("player"):
		# 死亡玩家不能当种子，否则僵尸会追着尸体走
		if i == null or not is_instance_valid(i) or i.isDead or i.hp <= 0:
			continue
		alive.append(i)
		seeds.append(MapData.worldToCell(i.global_position))

	# 旧实现：每个玩家各跑一次全量 BFS（保留作对照）
	# for i in alive:
	# 	var x = floori(i.global_position.x / MapData.cellSize)
	# 	var y = floori(i.global_position.y / MapData.cellSize)
	# 	MapData.computeFields(i.playerId, Vector2(x, y))

	# seeds 为空（全灭）时，computeFieldMulti 会清空场，僵尸走"无方向"分支
	MapData.computeFieldMulti(seeds)


# 玩家死亡处理
func playerDead() -> void:
	var players = get_tree().get_nodes_in_group("player")
	var num = 0
	for i in players:
		if i.isDead:
			awaitingResurrectionPlayer.append(i)
			num += 1
	MapData.flowDirty = true    # 死亡玩家要从流场种子中移除
	if num == MapData.playerCount:
		isGameOver = true
		print(tr("Game Over"))
		var tween = create_tween()
		tween.tween_interval(5.0)
		tween.tween_callback(func():
			SceneTransition.changeScene("res://scene/ui/gameover.tscn")
		)
		tween.play()
	else:
		resurrectionTimer.start()


## 连杀动画结束回调
# 递减连杀计数，最小减到1
func _on_count_ani_animation_finished() -> void:
	if MapData.currKillStreak - 1 >= 1:
		MapData.currKillStreak -= 1
		countNode.text = str('x', MapData.currKillStreak)

		@warning_ignore("integer_division")
		countAniNode.speed_scale = 1 + 0.1 * (MapData.currKillStreak / 10)

		if MapData.currKillStreak >= 0:
			countAniNode.play("default")


## 生成计时器超时回调
# 检查每个出生点，如果没有被阻挡且还有剩余敌人，生成一个敌人
# 同屏数量达到本波上限（maxZombieCount）时先不刷，等场上有空位再继续
func _on_spawn_timer_timeout() -> void:
	# 同屏上限：原版 Zombie_Count，避免一次性把整波都倒进场上
	if aliveEnemies(Game.mapSign.Zombie) >= maxZombieCount:
		spawnTimer.start()
		return

	for i in allSpawnPoint:
		if not i.obj.hasBlock()  and  i.num > 0:
			if aliveEnemies(Game.mapSign.Zombie) >= maxZombieCount:
				break
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
		# 所有敌人已消灭，进入下一波（数量按原版曲线重算）
		currWave += 1
		applyWaveQuota()
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
		if not i.hasBlock():
			var b = box.instantiate()
			b.global_position = i.global_position
			get_tree().current_scene.add_child(b)


func _on_sound_timer_timeout() -> void:
	# 续上下一次（7~13 秒）
	soundTimer.start(randi() % 7 + 7)

	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty() or zombieAmbience.is_empty():
		return

	# 每次随机挑一个不同的低吼
	var p = $zombieSound
	p.stream = zombieAmbience[randi() % zombieAmbience.size()]
	# 2D 音效：放到某个随机僵尸身上，有方位感
	if p is Node2D:
		p.global_position = enemies[randi() % enemies.size()].global_position
	p.play()


func _on_resurrection_timer_timeout() -> void:
	if isGameOver:
		return

	var alivePlayers := []
	for p in get_tree().get_nodes_in_group("player"):
		if not p.isDead:
			alivePlayers.append(p)

	for i in awaitingResurrectionPlayer:
		i.resurrection()
		var pos: Vector2 = pickRespawnPos(i, alivePlayers)
		i.global_position = pos
		i.velocity = Vector2.ZERO
		# 复活无敌：原版合作模式 5 秒（CThing_Creature_Player.as:295）
		i.setInvincible(i.RESPAWN_INVINCIBLE)

	awaitingResurrectionPlayer.clear()


## 选择复活点（方案 C）
##
## 1. 优先：存活玩家 3 格范围内的空闲格（和队友靠在一起）
## 2. 其次：当前相机可走区域内随机一个空闲格
## 3. 兜底：从配置的出生点螺旋找空格
func pickRespawnPos(dead_player: Node2D, alivePlayers: Array) -> Vector2:
	var occupied := {}
	for p in get_tree().get_nodes_in_group("player"):
		if p == dead_player or p.isDead:
			continue
		occupied[MapData.worldToCell(p.global_position)] = true

	# 1. 存活玩家附近 3 格
	if not alivePlayers.is_empty():
		var cands: Array[Vector2i] = []
		for ap in alivePlayers:
			var base: Vector2i = MapData.worldToCell(ap.global_position)
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if dx == 0 and dy == 0:
						continue
					var c: Vector2i = base + Vector2i(dx, dy)
					if MapData.isObstacle(c) or occupied.has(c):
						continue
					cands.append(c)
		if not cands.is_empty():
			return MapData.cellCenter(cands[randi() % cands.size()])

	# 2. 相机可走区域内随机空格
	var rect: Rect2 = MapData.getPlayRect()
	var c0: Vector2i = MapData.worldToCell(rect.position)
	var c1: Vector2i = MapData.worldToCell(rect.end)
	var cells: Array[Vector2i] = []
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			var c: Vector2i = Vector2i(x, y)
			if MapData.isObstacle(c) or occupied.has(c):
				continue
			cells.append(c)
	if not cells.is_empty():
		return MapData.cellCenter(cells[randi() % cells.size()])

	# 3. 兜底
	return findFreeSpawn(playerSpawnPoint[dead_player.playerId].global_position)


## 把地图 id 解析成房间场景路径
## id 0 = 默认 room_001；id>=2 = room_00NN（四位补零）
func resolveRoomPath(id: int) -> String:
	if id <= 0:
		return "res://scene/level/room_001.tscn"
	var path := "res://scene/level/room_%04d.tscn" % id
	return path if ResourceLoader.exists(path) else "res://scene/level/room_001.tscn"


## 按 MapData.selectedMapId 创建（或替换）房间
func swapRoom() -> void:
	var want := resolveRoomPath(MapData.selectedMapId)
	if room != null and is_instance_valid(room) and room.scene_file_path == want:
		return

	var old = room
	if old != null and is_instance_valid(old):
		remove_child(old)
		old.queue_free()

	var packed = load(want)
	if packed == null:
		push_warning("地图加载失败: %s" % want)
		return
	room = packed.instantiate()
	room.name = "room001"
	add_child(room)
	print("[map] 加载地图 %s" % want)


## 找一个没被障碍占住的出生位置
## 生成的房间里有出生点会压在墙块上，直接按原坐标生成会让玩家/敌人卡在墙里
func findFreeSpawn(pos: Vector2) -> Vector2:
	var cell: Vector2i = MapData.worldToCell(pos)
	if not MapData.isObstacle(cell):
		return pos

	var cs: int = int(MapData.cellSize)
	var grid := Vector2i(int(MapData.mapSize.x / cs), int(MapData.mapSize.y / cs))

	# 由内向外一圈圈找最近的空格
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


## 飘分：在死亡位置生成 "+N"，飞向顶部总分并淡出
## 对应原版 CHud.AddScore（CHud.as:242-252）：每帧朝总分控件移动并逐渐透明
func spawnScorePopup(worldPos: Vector2, amount: int) -> void:
	# 低于阈值不飘（原版连杀倍率 1 时的 100 分太频繁，不显示）
	if amount < SCORE_POPUP_MIN:
		return
	var label := Label.new()
	label.text = "+%d" % amount
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.55))
	label.z_index = 100
	# 世界坐标 → 屏幕坐标
	label.position = get_viewport().get_canvas_transform() * worldPos
	$ui.add_child(label)

	var target: Vector2 = scoreNode.get_global_rect().get_center()
	var dist: float = label.position.distance_to(target)
	var dur: float = clampf(dist / 320.0, 0.25, 1.2)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position", target, dur)
	tw.tween_property(label, "modulate:a", 0.0, dur).set_delay(dur * 0.45)
	tw.chain().tween_callback(label.queue_free)


## 统计场上某一类敌人数量（zombie / devil 分别限流）
func aliveEnemies(kind: int) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == null or not is_instance_valid(e):
			continue
		if kind == Game.mapSign.Devil and e is Devil:
			n += 1
		elif kind == Game.mapSign.Zombie and not (e is Devil):
			n += 1
	return n


## 物理帧更新
func _physics_process(_delta: float) -> void:
	# 调试模式下重绘
	if isDebug:
		queue_redraw()

	# 障碍有增删（玩家放了油桶/喷了墙、或它们被打碎）→ 立刻重算，不等轮询
	if MapData.flowDirty:
		MapData.flowDirty = false
		updateTimer = 0
		updateFlowField()
		return

	# 玩家一直在动，仍按固定间隔刷新（流场源点是玩家所在格）
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
			draw_line(
					Vector2(i * MapData.cellSize, 0),
					Vector2(i * MapData.cellSize, MapData.cellSize * height),
					Color.GRAY, 0.5, true)
		for i in range(height + 1):
			draw_line(
					Vector2(0, i * MapData.cellSize),
					Vector2(MapData.cellSize * width, i * MapData.cellSize),
					Color.GRAY, 0.5, true)

		# 绘制障碍物格子（红色半透明）
		for key in MapData.obstacle.keys():
			var parts = key.split("-")
			if parts.size() != 2:
				continue
			var ox = int(parts[0])
			var oy = int(parts[1])
			draw_rect(
					Rect2(ox * MapData.cellSize, oy * MapData.cellSize,
							MapData.cellSize, MapData.cellSize),
					Color(1, 0, 0, 0.5), true)

		# 绘制流场箭头（黑色）
		for id in MapData.flowFieldDict.keys():
			var field = MapData.flowFieldDict[id]
			if typeof(field) != TYPE_DICTIONARY:
				continue
			# 多源单场的键是 "multi"（字符串），旧的每玩家场是数字 id，
			# 直接和 1 比较会报 String/int 类型错误
			var color = Color(0, 0, 0, 0.85)
			if str(id) != "1" and str(id) != "multi":
				color = Color(0, 0, 0, 0.45)

			for x in range(width):
				for y in range(height):
					var key = "%s-%s" % [x, y]
					if not field.has(key):
						continue
					var dir = field[key]
					if dir == Vector2.ZERO:
						continue

					# 绘制箭头
					var center = Vector2(
							x * MapData.cellSize + MapData.cellSize * 0.5,
							y * MapData.cellSize + MapData.cellSize * 0.5)
					var arrowLen = MapData.cellSize * 0.35
					var tip = center + dir.normalized() * arrowLen
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
		draw_string(font, get_local_mouse_position() + Vector2(20, 20),
				"%s-%s" % [floori(x / MapData.cellSize), floori(y / MapData.cellSize)],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHEAT)
