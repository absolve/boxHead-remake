extends Node2D

## CPU 玩家测试场景
##
## 加载一个房间 + 1 个人类玩家（可操作）+ N 个 CPU 玩家（带 Beehave 行为树）。
## 用来单独验证感知 / 走位 / 选枪 / 策略 / 受伤撤退 / 救援，不影响正式关卡。
##
## 按键：
##   1 / 2     减少 / 增加一个 CPU（0~3 个）
##   Z / X     在身边刷一只僵尸 / 恶魔
##   C         清空敌人
##   F         切换友军伤害（观察 CPU 是否会停火）
##   T         轮换所有 CPU 的主策略（突进 → 防守 → 跟随 → 放风筝）
##   P         暂停 / 恢复所有 CPU 行为树
##   R         把 CPU 拉回出生点
##   空格      人类玩家无敌开关（默认开）

const PLAYER_SCENE := preload("res://scene/character/player.tscn")
const ZOMBIE_SCENE := preload("res://scene/character/zombie.tscn")
const DEVIL_SCENE := preload("res://scene/character/devil.tscn")
const BRAIN_SCRIPT := preload("res://script/ai/cpu_brain.gd")
## 玩家流场的刷新间隔（物理帧）：僵尸寻路 + CPU 归队都靠它
const FLOW_REFRESH_FRAMES: int = 30

@export var cpuCount: int = 1
## 测试用敌人移速（原版僵尸 16 太慢，看不清）
@export var enemySpeed: float = 60.0

var room: Node2D = null
var human: Player = null
var cpus: Array = []
var label: Label = null
var font: FontFile
var treesPaused := false
var humanInvincible := true
var _flowTimer := 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#EDE2CF"))
	MapData.playerCount = 1
	MapData.selectedMapId = 0

	room = load("res://scene/level/room_001.tscn").instantiate()
	add_child(room)
	MapData.mapSize = room.mapSize
	font = ThemeDB.fallback_font

	human = _spawnPlayer(1, false, spawnPos(0))
	_setHumanInvincible(true)
	for i in cpuCount:
		spawnCpu(i)
	buildUI()


func spawnPos(slot: int) -> Vector2:
	var pts: Array = room.playerSpawnPoint
	if pts.is_empty():
		return MapData.mapSize * 0.5
	return pts[mini(slot, pts.size() - 1)].global_position


func _spawnPlayer(pid: int, cpu: bool, pos: Vector2) -> Player:
	var p := PLAYER_SCENE.instantiate() as Player
	p.playerId = pid
	p.isCpu = cpu
	p.global_position = pos
	add_child(p)
	return p


func spawnCpu(i: int) -> void:
	var p := _spawnPlayer(3 + i, true, spawnPos(1 + i))
	var brain: Node = BRAIN_SCRIPT.new()
	brain.name = "CpuBrain"
	p.add_child(brain)
	cpus.append(p)


func despawnCpu() -> void:
	if cpus.is_empty():
		return
	var p = cpus.pop_back()
	if is_instance_valid(p):
		p.queue_free()


func _setHumanInvincible(on: bool) -> void:
	humanInvincible = on
	human.invincible = on
	human.invincibleTime = 0.0
	human.ani.modulate.a = 1.0


func buildUI() -> void:
	var ui: CanvasLayer = $ui
	label = Label.new()
	label.position = Vector2(8, 6)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	ui.add_child(label)


## 僵尸寻路 + CPU 归队都依赖玩家流场；测试场景没有 map.gd，自己刷
func _physics_process(_delta: float) -> void:
	_flowTimer += 1
	if _flowTimer < FLOW_REFRESH_FRAMES and not MapData.flowDirty:
		return
	_flowTimer = 0
	MapData.flowDirty = false
	var seeds: Array = []
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and not p.isDead:
			seeds.append(MapData.worldToCell(p.global_position))
	MapData.computeFieldMulti(seeds)


func _process(_delta: float) -> void:
	if label != null:
		label.text = "\n".join([
			"CPU %d 个   友伤：%s   行为树：%s   人类无敌：%s" % [
				cpus.size(), "开" if MapData.friendlyFireOn() else "关",
				"暂停" if treesPaused else "运行", "开" if humanInvincible else "关"],
			"敌人 %d 只  FPS %d   %s" % [
				get_tree().get_nodes_in_group("enemy").size(),
				Engine.get_frames_per_second(), _strategySummary()],
			"[1/2]CPU [Z]僵尸 [X]恶魔 [C]清空 [F]友伤 [T]策略 [G]发枪 [H]掉血 [P]暂停 [R]复位 [空格]无敌",
		])
	queue_redraw()


func _strategySummary() -> String:
	var parts: Array = []
	for c in cpus:
		if not is_instance_valid(c):
			continue
		var b := c.cpuBrain as CpuBrain
		if b == null:
			continue
		var t: Node2D = b.target
		var dist := -1.0
		if t != null and is_instance_valid(t):
			dist = c.global_position.distance_to(t.global_position)
		var act = b.tree.get_running_action() if b.tree != null else null
		var actText: String = "-" if act == null else String(act.name)
		var ovb := 0
		var ova := 0
		if b.area != null:
			ovb = b.area.get_overlapping_bodies().size()
			ova = b.area.get_overlapping_areas().size()
		parts.append("CPU%d %s[%s] hp%d d%.0f ov%d/%d%s" % [
			c.playerId, b.strategyName(), actText, c.hp, dist, ovb, ova,
			" 开火" if c.cpuWantFire else ""])
	return "  ".join(parts)


func _draw() -> void:
	if font == null:
		return
	for c in cpus:
		if not is_instance_valid(c):
			continue
		var b := c.cpuBrain as CpuBrain
		if b == null:
			continue
		# 感知范围
		draw_arc(c.global_position, b.senseRadius, 0.0, TAU, 48, Color(0, 0.55, 1, 0.22), 1.0)
		# 缰绳范围（防守/跟随/放风筝）
		if b.leashCells() > 0:
			draw_arc(b.leashAnchor(), float(b.leashCells()) * MapData.cellSize,
					0.0, TAU, 40, Color(0.95, 0.8, 0.1, 0.18), 1.0)
		# 目标连线
		var t: Node2D = b.target
		if t != null and is_instance_valid(t):
			draw_line(c.global_position, t.global_position, Color(1, 0.3, 0.2, 0.55), 1.0)
		# 移动意图
		if c.cpuMoveDir.length() > 0.01:
			draw_line(c.global_position, c.global_position + c.cpuMoveDir.normalized() * 32.0,
					Color(0.1, 0.85, 0.25, 0.9), 2.0)
		# 火球威胁
		for h in b.hazards:
			if is_instance_valid(h):
				draw_line(c.global_position, h.global_position, Color(1, 0.8, 0, 0.5), 1.0)
		draw_string(font, c.global_position + Vector2(-18, -42),
				"CPU%d %s %s" % [c.playerId, b.strategyName(), Game.weaponName[c.currWeapon.type]],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.1, 0.1, 0.1))


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_1:
			if cpus.size() > 0:
				despawnCpu()
		KEY_2:
			if cpus.size() < 3:
				spawnCpu(cpus.size())
		KEY_Z:
			spawnEnemy(ZOMBIE_SCENE)
		KEY_X:
			spawnEnemy(DEVIL_SCENE)
		KEY_C:
			for e in get_tree().get_nodes_in_group("enemy"):
				e.queue_free()
		KEY_F:
			MapData.mapConfig.friendlyFire = not MapData.friendlyFireOn()
		KEY_T:
			cycleStrategy()
		KEY_G:
			grantWeapons()
		KEY_P:
			treesPaused = not treesPaused
			for c in cpus:
				if is_instance_valid(c) and c.cpuBrain != null:
					(c.cpuBrain as CpuBrain).tree.enabled = not treesPaused
		KEY_R:
			for i in cpus.size():
				if is_instance_valid(cpus[i]):
					cpus[i].global_position = spawnPos(1 + i)
		KEY_SPACE:
			_setHumanInvincible(not humanInvincible)
		KEY_H:
			# 把人类血量压到 35% 以下，观察救援分支
			human.hp = 60
			print("[test_cpu] 人类 HP = 60（测试救援）")


## 手动轮换策略（同时把"性格"设成它，免得 15 秒后被评分改回去）
func cycleStrategy() -> void:
	for c in cpus:
		if not is_instance_valid(c):
			continue
		var b := c.cpuBrain as CpuBrain
		if b == null:
			continue
		b.strategy = (b.strategy + 1) % 4
		b.personality = b.strategy
		b.strategySinceMs = Time.get_ticks_msec()
		b.anchorPos = c.global_position
		# 20 秒内不让"无敌人自动巡逻"把手动策略改回去
		b.manualUntilMs = Time.get_ticks_msec() + 20000


## 给所有 CPU 发全套枪械（测试换枪用）
func grantWeapons() -> void:
	for c in cpus:
		if not is_instance_valid(c):
			continue
		for content in [Game.boxContent.UZI, Game.boxContent.Shotgun,
				Game.boxContent.Railgun, Game.boxContent.Rocket]:
			c.pickItem(content)
	print("[test_cpu] 已给 CPU 发放 UZI / Shotgun / Railgun / Rocket")


## 在人类身边 8 格内找个空格刷怪
func spawnEnemy(scene: PackedScene) -> void:
	var base: Vector2i = MapData.worldToCell(human.global_position)
	for attempt in 40:
		var c := base + Vector2i(randi_range(-8, 8), randi_range(-8, 8))
		if MapData.isObstacle(c):
			continue
		var e: Node2D = scene.instantiate()
		var spawn: Vector2 = MapData.cellCenter(c)
		var dir: Vector2 = (human.global_position - spawn).normalized()
		# 和 map.gd 一致：从出生点外侧 20px 走进来
		e.global_position = spawn - dir * 20.0
		e.velocity = dir
		if "initPos" in e:
			e.set("initPos", spawn)
		if "state" in e:
			e.set("state", Game.enemyState.init)
		if "speed" in e:
			e.set("speed", enemySpeed)
		add_child(e)
		return
	push_warning("test_cpu: 附近找不到空格刷怪")


func _exit_tree() -> void:
	MapData.playerCount = 4
