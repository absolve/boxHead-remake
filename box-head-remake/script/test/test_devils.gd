extends Node2D

## 恶魔/僵尸击退测试场：4 个 CPU 自动打，观察敌人会不会被打出地图
##
## 手动玩：直接运行本场景（窗口模式），按键见左下角提示
## 自动跑：godot --headless --path <proj> res://scene/test/test_devils.tscn --quit-after 45000

const PLAYER_SCENE := preload("res://scene/character/player.tscn")
const BRAIN_SCRIPT := preload("res://script/ai/cpu_brain.gd")
const DEVIL_SCENE := preload("res://scene/character/devil.tscn")
const ZOMBIE_SCENE := preload("res://scene/character/zombie.tscn")

## 初始恶魔数量
@export var devilCount: int = 6
## 初始僵尸数量
@export var zombieCount: int = 4
## headless 下自动跑多久（秒）后退出
@export var autoRunSec: float = 40.0
## 流场刷新间隔（物理帧）
const FLOW_REFRESH_FRAMES: int = 30

var room: Node = null
var label: Label = null
var cpus: Array = []
var flowTimer := 0

## 统计：敌人中心跑到地图外的次数与最大越界距离
var outEvents: int = 0
var maxOvershoot: float = 0.0
var wasInside: Dictionary = {}
var insideChecks: int = 0
var hitsTaken: int = 0
## 恶魔被打次数 / 单帧最大位移（判断击退强度）
var devilHits: int = 0
var devilMaxStep: float = 0.0
var devilLastHp: Dictionary = {}
var devilLastPos: Dictionary = {}
## 刚挨打时的位置：只在「挨打后 5 帧内」统计位移，排除互相挤压
var devilHitPos: Dictionary = {}
var devilHitFrame: Dictionary = {}
var frameCount: int = 0
var devilKnockMax: float = 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#EDE2CF"))
	MapData.selectedMapId = 0
	MapData.mapConfig.difficulty = 1

	room = load("res://scene/level/room_001.tscn").instantiate()
	add_child(room)
	MapData.mapSize = room.mapSize

	# 4 个 CPU
	for i in range(4):
		_spawnCpu(i)

	buildUI()
	spawnDevils(devilCount)
	SpawnZombies(zombieCount)

	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		_autoRun()
	else:
		captureShot()


func _spawnCpu(i: int) -> void:
	var p := PLAYER_SCENE.instantiate() as Player
	p.playerId = 3 + i
	p.isCpu = true
	var pts: Array = room.playerSpawnPoint
	var pos: Vector2 = pts[mini(i, pts.size() - 1)].global_position if pts.size() > 0 \
			else MapData.mapSize * 0.5
	p.global_position = pos
	add_child(p)
	var brain: Node = BRAIN_SCRIPT.new()
	brain.name = "CpuBrain"
	p.add_child(brain)
	cpus.append(p)


func spawnDevils(n: int) -> void:
	var center: Vector2 = MapData.mapSize * 0.5
	for i in range(n):
		var d = DEVIL_SCENE.instantiate()
		var ang: float = TAU * i / maxf(n, 1)
		d.global_position = center + Vector2(cos(ang), sin(ang)) * 170.0
		add_child(d)


func SpawnZombies(n: int) -> void:
	var center: Vector2 = MapData.mapSize * 0.5
	for i in range(n):
		var z = ZOMBIE_SCENE.instantiate()
		var ang: float = TAU * i / maxf(n, 1) + 0.5
		z.global_position = center + Vector2(cos(ang), sin(ang)) * 180.0
		z.initPos = z.global_position
		add_child(z)


func buildUI() -> void:
	var ui := CanvasLayer.new()
	ui.name = "ui"
	add_child(ui)
	label = Label.new()
	label.position = Vector2(8, 6)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	ui.add_child(label)


## 流场刷新（测试场景没有 map.gd）
func _physics_process(_delta: float) -> void:
	flowTimer += 1
	if flowTimer < FLOW_REFRESH_FRAMES and not MapData.flowDirty:
		_checkBounds()
		return
	flowTimer = 0
	MapData.flowDirty = false
	var seeds: Array = []
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and not p.isDead:
			seeds.append(MapData.worldToCell(p.global_position))
	MapData.computeFieldMulti(seeds)
	_checkBounds()


## 每帧检查：敌人是否在地图外（被击退出去）
func _checkBounds() -> void:
	insideChecks += 1
	frameCount += 1
	var mapRect := Rect2(Vector2.ZERO, MapData.mapSize)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or bool(e.get("isDead")):
			continue
		var pos: Vector2 = e.global_position
		var inside := mapRect.has_point(pos)
		var id: int = e.get_instance_id()

		# 恶魔专项：统计挨打次数与单帧位移（击退强度）
		if e.get("type") == Game.roleType.Devil:
			var hpNow: int = e.hp
			if devilLastHp.has(id) and hpNow < int(devilLastHp[id]):
				devilHits += 1
				devilHitPos[id] = pos
				devilHitFrame[id] = frameCount
			devilLastHp[id] = hpNow
			# 只统计挨打后 5 帧内的位移 = 纯击退位移
			if devilHitPos.has(id) and frameCount - int(devilHitFrame[id]) <= 5:
				devilKnockMax = maxf(devilKnockMax, pos.distance_to(devilHitPos[id]))
			if devilLastPos.has(id):
				devilMaxStep = maxf(devilMaxStep,
					pos.distance_to(devilLastPos[id]))
			devilLastPos[id] = pos
		if inside:
			wasInside[id] = true
		elif wasInside.get(id, false):
			# 从"在地图内"变成"在地图外"：记一次被打出去
			outEvents += 1
			var over := 0.0
			over = maxf(over, -pos.x)
			over = maxf(over, pos.x - MapData.mapSize.x)
			over = maxf(over, -pos.y)
			over = maxf(over, pos.y - MapData.mapSize.y)
			maxOvershoot = maxf(maxOvershoot, over)
			wasInside[id] = false


func _process(_delta: float) -> void:
	if label == null:
		return
	var devils := 0
	var zombies := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			if e.get("type") == Game.roleType.Devil:
				devils += 1
			else:
				zombies += 1
	var weapons: Array = []
	for c in cpus:
		if is_instance_valid(c):
			weapons.append((c as Player).weaponList.size())
	label.text = "\n".join([
		"4 CPU  vs  %d 恶魔 + %d 僵尸（击退出界 %d 次，最大越界 %.1f px）" % [
			devils, zombies, outEvents, maxOvershoot],
		"CPU 武器数：%s   FPS：%d" % [str(weapons), Engine.get_frames_per_second()],
		"[1..6]加恶魔 [Z]加僵尸 [C]清空敌人 [R]重开",
	])


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match key:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			spawnDevils(1)
		KEY_Z:
			SpawnZombies(1)
		KEY_C:
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e):
					e.queue_free()
		KEY_R:
			get_tree().reload_current_scene()


## 窗口模式：等几秒截一张图，方便看效果
func captureShot() -> void:
	await get_tree().create_timer(6.0).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join("../_local/qa_shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("14_devils.png")
	img.save_png(path)
	print("QAK|SHOT|%s" % path)


## headless：跑一段时间后输出统计
func _autoRun() -> void:
	await get_tree().create_timer(autoRunSec).timeout
	print("QAK|RESULT|敌人出界次数=%d 最大越界=%.1fpx 检查帧=%d" % [
		outEvents, maxOvershoot, insideChecks])
	print("QAK|RESULT|恶魔挨打 %d 次，挨打后最大击退位移 %.1fpx（质量 5 → 应 <=10px）" % [
		devilHits, devilKnockMax])
	print("QAK|RESULT|剩余敌人=%d CPU 武器数=%s" % [
		get_tree().get_nodes_in_group("enemy").size(),
		str(cpus.map(func(c): return (c as Player).weaponList.size() if is_instance_valid(c) else -1))])
	get_tree().quit()
