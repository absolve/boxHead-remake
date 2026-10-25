extends Node2D

## 武器测试场景
##
## 用途：一次拿到全部武器，对着靶子测试手感/伤害/特效；
##      界面右侧的按钮（场景里已摆好）可以增删僵尸/恶魔、逐个解锁武器。
## 操作：
##   WASD 移动，鼠标瞄准，左键开火
##   E / Q 切换武器（玩家自身的按键）
##   R 重置靶子，空格 切换无敌


## 全部武器（Game.boxContent 里可拾取的种类）
const ALL_WEAPONS: Array = [
	Game.boxContent.Railgun,
	Game.boxContent.Rocket,
	Game.boxContent.Shotgun,
	Game.boxContent.UZI,
	Game.boxContent.Mine,
	Game.boxContent.ChargePack,
	Game.boxContent.Wall,
	Game.boxContent.Barrel,
	Game.boxContent.Grenade,
]

## 解锁按钮 → 武器类型
const UNLOCK_BUTTONS: Dictionary = {
	"btnRailgun": Game.boxContent.Railgun,
	"btnRocket": Game.boxContent.Rocket,
	"btnShotgun": Game.boxContent.Shotgun,
	"btnUZI": Game.boxContent.UZI,
	"btnMine": Game.boxContent.Mine,
	"btnChargePack": Game.boxContent.ChargePack,
	"btnWall": Game.boxContent.Wall,
	"btnBarrel": Game.boxContent.Barrel,
	"btnGrenade": Game.boxContent.Grenade,
}


## 靶子数量
@export var targetCount: int = 6

## 靶子血量（调大方便反复打）
@export var targetHp: int = 5000


var player: Character

var targets: Array = []


@onready var label: Label = $ui/label

@onready var panel: VBoxContainer = $ui/panel


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#EDE2CF"))
	MapData.selectedMapId = 0
	MapData.playerCount = 1

	var room = load("res://scene/level/room_001.tscn").instantiate()
	add_child(room)
	await get_tree().process_frame

	player = load("res://scene/character/player.tscn").instantiate()
	player.playerId = 1
	player.global_position = MapData.mapSize * 0.5 + Vector2(0, 80)
	add_child(player)
	await get_tree().process_frame

	player.invincible = true
	player.invincibleTime = 0.0
	player.ani.modulate.a = 1.0

	# 一次给全部武器（走玩家自己的拾取逻辑，保证属性/弹药都正确）
	for w in ALL_WEAPONS:
		player.pickItem(w)

	connectButtons()
	#spawnTargets()
	updateLabel()
	print("[test_weapons] 已给全部武器，靶子 %d 个" % targetCount)


## 连接场景里摆好的按钮
func connectButtons() -> void:
	$ui/panel/btnAddZombie.pressed.connect(func() -> void: spawnEnemy("zombie"))
	$ui/panel/btnRemoveZombie.pressed.connect(func() -> void: removeEnemy("zombie"))
	$ui/panel/btnAddDevil.pressed.connect(func() -> void: spawnEnemy("devil"))
	$ui/panel/btnRemoveDevil.pressed.connect(func() -> void: removeEnemy("devil"))
	$ui/panel/btnClear.pressed.connect(clearEnemies)
	$ui/panel/btnReset.pressed.connect(spawnTargets)
	$ui/panel/btnInvincible.pressed.connect(toggleInvincible)

	for btn_name in UNLOCK_BUTTONS:
		var w: int = int(UNLOCK_BUTTONS[btn_name])
		var node := panel.get_node_or_null(btn_name)
		if node is Button:
			(node as Button).pressed.connect(func() -> void: unlockWeapon(w))


## 生成一只僵尸或恶魔
func spawnEnemy(kind: String) -> void:
	var scenePath := "res://scene/character/zombie.tscn"
	if kind == "devil":
		scenePath = "res://scene/character/devil.tscn"
	var e = load(scenePath).instantiate()
	var ang := randf() * TAU
	e.global_position = player.global_position + Vector2(cos(ang), sin(ang)) * 110.0
	if kind != "devil":
		e.hp = targetHp
		e.maxHp = targetHp
	add_child(e)
	targets.append(e)


## 移除最后一只该类型的敌人
func removeEnemy(kind: String) -> void:
	for i in range(targets.size() - 1, -1, -1):
		var e = targets[i]
		if not is_instance_valid(e):
			targets.remove_at(i)
			continue
		var isDevil: bool = e is Devil
		if (kind == "devil") == isDevil:
			e.queue_free()
			targets.remove_at(i)
			return


## 清空所有敌人
func clearEnemies() -> void:
	for e in targets:
		if is_instance_valid(e):
			e.queue_free()
	targets.clear()


## 解锁一把武器（已解锁则补满弹药）
func unlockWeapon(w: int) -> void:
	player.pickItem(w)


func toggleInvincible() -> void:
	player.invincible = not player.invincible
	player.invincibleTime = 0.0
	player.ani.modulate.a = 1.0


## 在房间上方摆一排靶子
func spawnTargets() -> void:
	for t in targets:
		if is_instance_valid(t):
			t.queue_free()
	targets.clear()

	var y: float = MapData.mapSize.y * 0.35
	var total: float = targetCount * 96.0
	var x0: float = (MapData.mapSize.x - total) * 0.5
	for i in range(targetCount):
		var z = load("res://scene/character/zombie.tscn").instantiate()
		z.global_position = Vector2(x0 + i * 96.0 + 48.0, y)
		z.hp = targetHp
		z.maxHp = targetHp
		add_child(z)
		targets.append(z)


func updateLabel() -> void:
	if player == null or label == null:
		return
	var wname := "?"
	var ammo := ""
	if player.weaponList.size() > 0 and player.currWeapon != null:
		wname = str(player.currWeapon.name)
		ammo = " 弹药 %d/%d" % [player.currWeapon.ammoNum, player.currWeapon.maxAmmoNum]
	var zc := 0
	var dc := 0
	for e in targets:
		if not is_instance_valid(e):
			continue
		if e is Devil:
			dc += 1
		else:
			zc += 1
	label.text = "武器: %s%s  僵尸%d 恶魔%d  [E/Q 切换] [左键开火] [R 重置] [空格 无敌=%s]" % [
		wname, ammo, zc, dc, str(player.invincible)]


func _process(_delta: float) -> void:
	updateLabel()
	if Input.is_action_just_pressed("ui_accept"):
		toggleInvincible()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_R:
			spawnTargets()
