class_name Player
extends "res://script/character/character.gd"

## 玩家角色脚本
# 继承自character.gd，实现玩家的控制逻辑：
# - 移动控制（WASD或方向键）
# - 武器系统（切换、拾取、升级）
# - 受伤和死亡处理
# - 碰撞检测


## 出生无敌时长（秒）：原版 mInvincible = 200 tick（doc/04 §2.3）
const SPAWN_INVINCIBLE: float = 8.0
## 复活后无敌时长（秒）：原版 125 tick = 5 秒
const RESPAWN_INVINCIBLE: float = 5.0
## 每个玩家一套颜色（绿 / 红 / 蓝 / 黄）
## 原版 Boxhead 多人就是「同一套精灵 + 染色」，所以用色相旋转而不是独立素材。
## 玩家默认绿色 = 0x00FF00（doc/04 §2.1）；色相旋转量按绿→红/蓝/黄换算。
const PLAYER_HUE_SHIFT: Array[float] = [0.0, 0.667, 0.333, -0.167]


## 玩家ID（用于多人游戏区分）
@export var playerId: int = 1
## 是否由 CPU 控制（关卡选择里的 NPC 玩家）：true 时不读按键，交给 AI 决策
@export var isCpu: bool = false

## CPU 行为树大脑（子节点 CpuBrain 在 _ready 里认领；为空时退回下面的临时 AI）
var cpuBrain: Node = null
## 行为树写入的每帧指令（由 Idle 状态消费）
var cpuMoveDir: Vector2 = Vector2.ZERO
var cpuAimDir: Vector2 = Vector2.ZERO
## ---- CPU AI 状态（isCpu 时才用）----
## 当前锁定目标（敌人）
var cpuTarget: Node2D = null
## 索敌/换目标倒计时
var cpuRetarget: float = 0.0
## 本帧想开火
var cpuWantFire: bool = false
## 卡住检测
var cpuStuck: float = 0.0
## 绕行方向与剩余时间
var cpuDetour: Vector2 = Vector2.ZERO
var cpuDetourTime: float = 0.0
## 上一帧位置（判定是否卡住）
var cpuLastPos: Vector2 = Vector2.ZERO
## 空枪换枪冷却
var cpuSwitchCd: float = 0.0
## 自动回血的亚血量累加器（hp 是整数，不回血小数会被截断）
var regenAcc: float = 0.0
## 无敌剩余时间（秒）；>0 时免疫伤害并闪烁
var invincibleTime: float = 0.0
## 按键映射（根据玩家ID分配不同按键）
var keyMap: Dictionary = {
	'left': '', 'right': '', 'up': '', 'down': '',
	'fire': '', 'nextWeapon': '', 'prevWeapon': '',
}

## 当前使用的武器
var currWeapon: Node2D = null
## 武器列表（玩家拥有的所有武器）
var weaponList: Array = []
## 当前武器索引
var currWeaponIndex: int = 0
## 当前朝向向量
var vector: Vector2 = Vector2.RIGHT
## 不需要显示武器的动画例外列表
var aniException: Array = ['Mine', 'ChargePack', 'Wall', 'Barrel', 'Grenade']
## 形状查询参数（用于碰撞检测）
var shapeQuery: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
## 受伤计时器
var hurtTimer: float = 0
## 受伤持续时间（秒）；每次受击按击退帧数重算
var hurtDelay: float = 0.5
## 击退位移（格/帧，25Hz 结算时再 ×cellSize）
var knockbackDelta: Vector2 = Vector2.ZERO
## 剩余击退帧数
var knockbackFrames: int = 0
## 25Hz 累积器
var hurtMoveAcc: float = 0.0


## 武器背包节点（存放所有武器）
@onready var weaponBackpack: Node2D = $weaponBackpack
## 武器名称显示节点
@onready var txt: Label = $txt
## 身体碰撞体节点
@onready var body: Area2D = $body
## 身体碰撞形状节点
@onready var bodyShape: CollisionShape2D = $body/bodyShape
## 血条节点
@onready var lifeBar: Control = $lifeBar
## 死亡音效节点
@onready var deadSound: AudioStreamPlayer2D = $dead
## 拾取音效节点
@onready var pickupSound: AudioStreamPlayer2D = $pickup
## 玩家精灵节点
@onready var player: AnimationPlayer = $player
## 状态机（player.tscn 里的 StateMachine 子节点）
@onready var fsm: StateMachine = $StateMachine


## 初始化
func _ready() -> void:
	# 原版玩家质量 2（CThing_Creature_Player.as:146）
	mass = 2.0
	# 设置初始状态
	state = Game.playerState.Idle

	# 配置形状查询参数
	shapeQuery.collide_with_areas = true
	shapeQuery.collision_mask = 1 + 2 + 4
	shapeQuery.exclude = [get_rid(), body.get_rid()]
	shapeQuery.shape = shape.shape

	# 初始化武器列表（默认装备手枪）
	# var temp = load("res://scene/weapon/pistol.tscn")
	# var gun = temp.instantiate()
	# gun.ownerId = body.get_rid()
	# weaponList.push_back(gun)
	# weaponBackpack.add_child(gun)

	# currWeapon = gun

	initWeapon()


	# 根据玩家ID配置按键映射
	if playerId == 1:
		keyMap.left = "p1_left"
		keyMap.right = "p1_right"
		keyMap.up = "p1_up"
		keyMap.down = "p1_down"
		keyMap.fire = 'p1_fire'
		keyMap.nextWeapon = 'p1_nextWeapon'
		keyMap.prevWeapon = 'p1_prevWeapon'
	elif playerId == 2:
		keyMap.left = "p2_left"
		keyMap.right = "p2_right"
		keyMap.up = "p2_up"
		keyMap.down = "p2_down"
		keyMap.fire = 'p2_fire'
		keyMap.nextWeapon = 'p2_nextWeapon'
		keyMap.prevWeapon = 'p2_prevWeapon'
	elif playerId == 3:
		keyMap.left = "p3_left"
		keyMap.right = "p3_right"
		keyMap.up = "p3_up"
		keyMap.down = "p3_down"
		keyMap.fire = 'p3_fire'
		keyMap.nextWeapon = 'p3_nextWeapon'
		keyMap.prevWeapon = 'p3_prevWeapon'
	elif playerId == 4:
		keyMap.left = "p4_left"
		keyMap.right = "p4_right"
		keyMap.up = "p4_up"
		keyMap.down = "p4_down"
		keyMap.fire = 'p4_fire'
		keyMap.nextWeapon = 'p4_nextWeapon'
		keyMap.prevWeapon = 'p4_prevWeapon'

	# 按玩家编号换色（绿/红/蓝/黄）
	applyPlayerColor()

	# 出生无敌 8 秒
	setInvincible(SPAWN_INVINCIBLE)

	# 开局就把血条上限和当前血量同步好（否则会停在默认的 10）
	lifeBar.maxHp = maxHp
	lifeBar.hp = hp

	# 连接武器升级信号
	Game.weaponUpgrade.connect(weaponUpgrade)

	# 播放出生闪烁动画
	player.play("flash")
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func(): player.play("RESET"))
	tween.play()

	# 启动状态机：Idle 起步，受伤/死亡/复活由 player_states/*.gd 切换
	if fsm != null:
		fsm.start(&"Idle")


# 初始化武器
func initWeapon() -> void:
	weaponList.clear()
	for i in weaponBackpack.get_children():
		weaponBackpack.remove_child(i)
	# 初始化武器列表（默认装备手枪）
	var temp = load("res://scene/weapon/pistol.tscn")
	var gun = temp.instantiate()
	gun.ownerId = body.get_rid()
	gun.damage = MapData.allWeaponData[Game.weaponType.Pistol]['damage']
	gun.maxAmmoNum = MapData.allWeaponData[Game.weaponType.Pistol]['maxAmmoNum']
	gun.automatic = MapData.allWeaponData[Game.weaponType.Pistol]['automatic']
	gun.wRange = MapData.allWeaponData[Game.weaponType.Pistol]['wRange']
	gun.delay = MapData.allWeaponData[Game.weaponType.Pistol]['delay']
	weaponList.push_back(gun)
	weaponBackpack.add_child(gun)

	currWeapon = gun
	# 设置武器名称显示
	txt.text = Game.weaponName[currWeapon.type]


func resurrection() -> void:
	initWeapon()
	# 播放出生闪烁动画
	player.play("flash")
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func(): player.play("RESET"))
	tween.play()
	isDead = false
	state = Game.playerState.Idle
	# 死亡时 hit() 关掉了本体碰撞和受击盒，复活必须恢复：
	# 否则复活后会穿墙，而且再也吃不到伤害（bodyShape 一直 disabled）
	shape.disabled = false
	bodyShape.disabled = false
	# 死亡状态里复活的，主动切回 Idle（Dead 状态自身也有兜底判断）
	if fsm != null:
		fsm.transitionTo(&"Idle")
	hp = maxHp
	# 复活后位置变了，立刻重算流场，让僵尸改追这个玩家
	MapData.flowDirty = true
	lifeBar.maxHp = maxHp
	lifeBar.hp = hp


## 武器升级处理
# 根据武器类型更新武器属性
# @param weaponType 武器类型（Game.weaponType枚举值）
func weaponUpgrade(weaponType: int) -> void:
	for i in weaponList:
		if i.type != weaponType:
			continue
		var d: Dictionary = MapData.allWeaponData[weaponType]
		i.damage = d['damage']
		i.wRange = d['wRange']
		i.delay = d['delay']
		i.automatic = d['automatic']
		i.maxAmmoNum = d['maxAmmoNum']
		# 弹药上限变了（Double / Quad / Infinite）→ 把当前弹药也补到新上限
		# 原版 DoubleAmmo 同时给 mAmmo 赋值，这里照做
		i.ammoNum = d.get('ammoNum', i.ammoNum)
		# 以下字段只有部分武器有，用 set() 避免给不存在的属性赋值
		for key in ['splitAngle', 'wideShot', 'splitExplosion', 'biggerBang', 'clusterExplode']:
			if d.has(key):
				i.set(key, d[key])
		# 弹匣已满，同步 HUD
		break


## 切换武器
# 在武器列表中循环切换当前武器
# @param next 是否切换到下一把武器（true=下一把，false=上一把）
func switchWeapon(next: bool = true) -> void:
	if weaponList.size() > 1:
		if next:
			currWeaponIndex += 1
		else:
			currWeaponIndex -= 1
		currWeaponIndex = wrapi(currWeaponIndex, 0, weaponList.size())
		currWeapon = weaponList[currWeaponIndex]
		Game.notice.emit("%s:%s" % [tr("Switch"), Game.weaponName[currWeapon.type]])


## 拾取物品
# 根据物品类型添加武器或恢复生命
# @param contentType 物品类型（Game.boxContent枚举值）
func pickItem(contentType: int) -> void:
	if contentType in [Game.boxContent.Railgun, Game.boxContent.Rocket,
		Game.boxContent.Shotgun, Game.boxContent.UZI,
		Game.boxContent.Mine, Game.boxContent.ChargePack,
		Game.boxContent.Wall, Game.boxContent.Barrel, Game.boxContent.Grenade]:
		var w = getWeapon(Game.getBoxContentWeaponType(contentType))
		if w != null:
			# 已有该武器，补充弹药
			# 注意：contentType 是 boxContent，allWeaponData 的键是 weaponType，必须先转换；
			# 而且表里只有 maxAmmoNum，没有 ammoNum
			var wt = Game.getBoxContentWeaponType(contentType)
			if wt != null and MapData.allWeaponData.has(wt):
				w.ammoNum = MapData.allWeaponData[wt]['maxAmmoNum']
		else:
			# 没有该武器，创建新武器实例
			if contentType == Game.boxContent.Railgun:
				var temp = load("res://scene/weapon/railgun.tscn")
				var railgun = temp.instantiate()
				railgun.ownerId = get_rid()
				railgun.ownerNode = self
				railgun.damage = MapData.allWeaponData.get(Game.weaponType.Railgun)['damage']
				railgun.ammoNum = MapData.allWeaponData.get(Game.weaponType.Railgun)['maxAmmoNum']
				railgun.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.Railgun)['maxAmmoNum']
				railgun.automatic = MapData.allWeaponData.get(Game.weaponType.Railgun)['automatic']
				railgun.wRange = MapData.allWeaponData.get(Game.weaponType.Railgun)['wRange']
				railgun.delay = MapData.allWeaponData.get(Game.weaponType.Railgun)['delay']
				weaponList.push_back(railgun)
				weaponBackpack.add_child(railgun)
			elif contentType == Game.boxContent.Rocket:
				var temp = load("res://scene/weapon/rocket.tscn")
				var rocket = temp.instantiate()
				rocket.ownerId = body.get_rid()
				rocket.ownerNode = self
				rocket.damage = MapData.allWeaponData.get(Game.weaponType.Rocket)['damage']
				rocket.ammoNum = MapData.allWeaponData.get(Game.weaponType.Rocket)['maxAmmoNum']
				rocket.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.Rocket)['maxAmmoNum']
				rocket.automatic = MapData.allWeaponData.get(Game.weaponType.Rocket)['automatic']
				rocket.delay = MapData.allWeaponData.get(Game.weaponType.Rocket)['delay']
				weaponList.push_back(rocket)
				weaponBackpack.add_child(rocket)
			elif contentType == Game.boxContent.Shotgun:
				var temp = load("res://scene/weapon/shotgun.tscn")
				var shotgun = temp.instantiate()
				shotgun.ownerId = body.get_rid()
				shotgun.ownerNode = self
				shotgun.damage = MapData.allWeaponData.get(Game.weaponType.Shotgun)['damage']
				shotgun.ammoNum = MapData.allWeaponData.get(Game.weaponType.Shotgun)['maxAmmoNum']
				shotgun.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.Shotgun)['maxAmmoNum']
				shotgun.automatic = MapData.allWeaponData.get(Game.weaponType.Shotgun)['automatic']
				shotgun.wRange = MapData.allWeaponData.get(Game.weaponType.Shotgun)['wRange']
				shotgun.delay = MapData.allWeaponData.get(Game.weaponType.Shotgun)['delay']
				shotgun.wideShot = int(MapData.allWeaponData.get(Game.weaponType.Shotgun).get('wideShot', 0))
				weaponList.push_back(shotgun)
				weaponBackpack.add_child(shotgun)
			elif contentType == Game.boxContent.UZI:
				var temp = load("res://scene/weapon/uzi.tscn")
				var uzi = temp.instantiate()
				uzi.ownerId = body.get_rid()
				uzi.ownerNode = self
				uzi.damage = MapData.allWeaponData.get(Game.weaponType.UZI)['damage']
				uzi.ammoNum = MapData.allWeaponData.get(Game.weaponType.UZI)['maxAmmoNum']
				uzi.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.UZI)['maxAmmoNum']
				uzi.automatic = MapData.allWeaponData.get(Game.weaponType.UZI)['automatic']
				uzi.delay = MapData.allWeaponData.get(Game.weaponType.UZI)['delay']
				uzi.wRange = MapData.allWeaponData.get(Game.weaponType.UZI)['wRange']
				weaponList.push_back(uzi)
				weaponBackpack.add_child(uzi)
			elif contentType == Game.boxContent.Mine:
				var temp = load("res://scene/weapon/mine.tscn")
				var mine = temp.instantiate()
				mine.ownerId = body.get_rid()
				mine.ownerNode = self
				mine.damage = MapData.allWeaponData.get(Game.weaponType.Mine)['damage']
				mine.ammoNum = MapData.allWeaponData.get(Game.weaponType.Mine)['maxAmmoNum']
				mine.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.Mine)['maxAmmoNum']
				# splitExplosion 在部分武器脚本里没有声明，存在才赋值，避免运行时报错
				if "splitExplosion" in mine:
					mine.splitExplosion = MapData.allWeaponData.get(Game.weaponType.Mine)['splitExplosion']
				weaponList.push_back(mine)
				weaponBackpack.add_child(mine)
			elif contentType == Game.boxContent.ChargePack:
				var temp = load("res://scene/weapon/chargePack.tscn")
				var chargePack = temp.instantiate()
				chargePack.ownerId = get_rid()
				chargePack.ownerNode = self
				chargePack.damage = MapData.allWeaponData.get(Game.weaponType.ChargePack)['damage']
				chargePack.ammoNum = MapData.allWeaponData.get(Game.weaponType.ChargePack)['maxAmmoNum']
				chargePack.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.ChargePack)['maxAmmoNum']
				# splitExplosion 在部分武器脚本里没有声明，存在才赋值，避免运行时报错
				if "splitExplosion" in chargePack:
					var packStats: Dictionary = MapData.allWeaponData.get(Game.weaponType.ChargePack)
					chargePack.splitExplosion = packStats['splitExplosion']
				weaponList.push_back(chargePack)
				weaponBackpack.add_child(chargePack)
			elif contentType == Game.boxContent.Wall:
				var temp = load("res://scene/weapon/wall.tscn")
				var wall = temp.instantiate()
				wall.ownerId = body.get_rid()
				wall.ownerNode = self
				wall.ammoNum = MapData.allWeaponData.get(Game.weaponType.Wall)['maxAmmoNum']
				wall.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.Wall)['maxAmmoNum']
				weaponList.push_back(wall)
				weaponBackpack.add_child(wall)
			elif contentType == Game.boxContent.Barrel:
				var temp = load("res://scene/weapon/barrel.tscn")
				var barrel = temp.instantiate()
				barrel.ownerId = body.get_rid()
				barrel.ownerNode = self
				barrel.damage = MapData.allWeaponData.get(Game.weaponType.Barrel)['damage']
				barrel.ammoNum = MapData.allWeaponData.get(Game.weaponType.Barrel)['maxAmmoNum']
				barrel.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.Barrel)['maxAmmoNum']
				# splitExplosion 在部分武器脚本里没有声明，存在才赋值，避免运行时报错
				if "splitExplosion" in barrel:
					barrel.splitExplosion = MapData.allWeaponData.get(Game.weaponType.Barrel)['splitExplosion']
				weaponList.push_back(barrel)
				weaponBackpack.add_child(barrel)
			elif contentType == Game.boxContent.Grenade:
				var temp = load("res://scene/weapon/grenade.tscn")
				var grenade = temp.instantiate()
				grenade.ownerId = body.get_rid()
				#grenade.excludeList = [body.get_rid()]
				grenade.ownerNode = self
				grenade.damage = MapData.allWeaponData.get(Game.weaponType.Grenade)['damage']
				grenade.ammoNum = MapData.allWeaponData.get(Game.weaponType.Grenade)['maxAmmoNum']
				grenade.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.Grenade)['maxAmmoNum']
				# splitExplosion 在部分武器脚本里没有声明，存在才赋值，避免运行时报错
				if "splitExplosion" in grenade:
					grenade.splitExplosion = MapData.allWeaponData.get(Game.weaponType.Grenade)['splitExplosion']
				weaponList.push_back(grenade)
				weaponBackpack.add_child(grenade)

	elif contentType == Game.boxContent.Life:
		# 恢复生命
		hp = maxHp

	# 播放拾取音效
	pickupSound.play()


## 获取指定类型的武器
# 在武器列表中查找指定类型的武器
# @param weaponType 武器类型（Game.weaponType枚举值）
# @return 找到的武器实例，未找到返回null
func getWeapon(weaponType: int) -> Node:
	for i in weaponList:
		if i.type == weaponType:
			return i
	return null


## 受伤处理
# 减少血量，处理受伤动画和击退效果
# @param damage 伤害值（int）
# @param attackPos 攻击来源位置（Vector2）
# @param recoil 击退力度（float，默认0）
func hit(damage: int, _attackPos: Vector2 = Vector2.ZERO,
		knockDir: Vector2 = Vector2.ZERO, fromExplosion: bool = false) -> void:
	# 死亡 或 无敌期间免疫伤害
	if isDead or invincible:
		return

	hp -= damage
	lifeBar.maxHp = maxHp
	lifeBar.hp = hp

	if hp <= 0:
		# 死亡处理
		state = Game.playerState.dead
		# 先切状态再做演出：若正处在 Hurt，避免本帧继续跑击退逻辑
		if fsm != null:
			fsm.transitionTo(&"Dead")
		deadSound.play()
		ani.play("fallDown_%s" % [roundi(angle / 2.0)])
		shape.disabled = true
		bodyShape.disabled = true
		isDead = true
		Game.playerDead.emit()
	else:
		# 受伤处理
		state = Game.playerState.hurt
		# 先切 Hurt 再写击退参数：重复受击时 transitionTo 会先 exit 清掉旧击退，
		# 放在后面会把刚写入的新击退清掉。
		if fsm != null:
			fsm.transitionTo(&"Hurt")
		hurtTimer = 0

		# 原版不区分前后：两种受击动画随机二选一
		# （Player_HitRear = shothit_1 / Player_HitFront = shothit_2，random(2)+1）
		if randi() % 2 == 1:
			ani.play("hitFront_%s" % [angle])
		else:
			ani.play("hitRear_%s" % [angle])

		# 应用击退：和僵尸/恶魔同一套（25Hz、每帧 ×0.65）
		if knockDir != Vector2.ZERO:
			beginKnockback(knockDir, knockbackSpeed(damage, fromExplosion))
			hurtDelay = hurtTimeFrom(knockbackFrames)
		else:
			knockbackDelta = Vector2.ZERO
			knockbackFrames = 0
			velocity = Vector2.ZERO


## 玩家自身碰撞体的半宽高（矩形取 size/2，圆形按内接正方形近似）
## 由击退速度算出每帧位移（格/帧）与持续帧数（每帧 ×0.65）
func beginKnockback(dir: Vector2, _speed: float) -> void:
	knockbackDelta = dir.normalized() * _speed / MapData.TICKS_PER_SEC / MapData.cellSize
	knockbackFrames = 0
	hurtMoveAcc = 0.0
	var l: float = knockbackDelta.length()
	while l >= 0.01:
		knockbackFrames += 1
		l *= 0.65


func shapeExtents() -> Vector2:
	var s = shape.shape
	if s is CircleShape2D:
		return Vector2.ONE * (s as CircleShape2D).radius * 0.8
	if s is RectangleShape2D:
		return (s as RectangleShape2D).size * 0.5
	return Vector2(12, 12)


## 目标位置是否踩进了障碍格（原版油桶/墙把整格标成 mCollide_Object）
##
## 原版墙和油桶不是“圆形碰撞”，而是把所在格子标记为不可通行，
## 所以两个相邻的油桶中间不会留下缝隙。
func blockedByCell(pos: Vector2) -> bool:
	var r: float = playerRadius()
	for dx in [-r, 0.0, r]:
		for dy in [-r, 0.0, r]:
			if MapData.isObstacle(MapData.worldToCell(pos + Vector2(dx, dy))):
				return true
	return false


## 玩家碰撞半径（圆形取 radius，矩形取宽高的一半里较小的）
func playerRadius() -> float:
	var s = shape.shape
	if s is CircleShape2D:
		return (s as CircleShape2D).radius
	if s is RectangleShape2D:
		var sz: Vector2 = (s as RectangleShape2D).size * 0.5
		return minf(sz.x, sz.y)
	return 12.0


## 计算圆形（玩家）与某个障碍物之间的最小推出向量
##
## 返回 Vector2.ZERO 表示没有重叠；否则把这个向量加到玩家位置上就能分开。
## 同时支持圆形障碍（油桶/墙）和矩形障碍（墙体碰撞盒）。
func penetration(center: Vector2, radius: float, collider: Node2D) -> Vector2:
	var sh = collider.get_node_or_null("shape")
	if sh == null or sh.shape == null:
		return Vector2.ZERO
	var s = sh.shape
	var origin: Vector2 = (sh as Node2D).global_position

	if s is CircleShape2D:
		var otherR: float = (s as CircleShape2D).radius
		var d: Vector2 = center - origin
		var dist: float = d.length()
		var minDist: float = radius + otherR
		if dist >= minDist:
			return Vector2.ZERO
		if dist < 0.001:
			return Vector2.RIGHT * minDist
		return d.normalized() * (minDist - dist)

	if s is RectangleShape2D:
		var half: Vector2 = (s as RectangleShape2D).size * 0.5
		var rel: Vector2 = center - origin
		var nearest: Vector2 = Vector2(
			clampf(rel.x, -half.x, half.x),
			clampf(rel.y, -half.y, half.y))
		var diff: Vector2 = rel - nearest
		var dist2: float = diff.length()
		if dist2 >= radius:
			return Vector2.ZERO
		if dist2 < 0.001:
			return Vector2.RIGHT * radius
		return diff.normalized() * (radius - dist2)

	return Vector2.ZERO


## 区域障碍物碰撞处理
# 把玩家（圆）从障碍物里推出来，返回实际允许的位移
# @param displacement 期望的位移向量（Vector2）
func resolveAreaBlockers(displacement: Vector2) -> Vector2:
	var center: Vector2 = body.global_position
	var radius: float = playerRadius()

	# 起始位置已经在障碍里：允许离开，避免卡死
	shapeQuery.transform = Transform2D(0.0, center)
	for h in get_world_2d().direct_space_state.intersect_shape(shapeQuery, 8):
		if penetration(center, radius, h.collider) != Vector2.ZERO:
			return displacement

	# 目标位置：最多迭代 3 次把重叠推开
	var target: Vector2 = center + displacement
	for i in range(3):
		var moved := false
		shapeQuery.transform = Transform2D(0.0, target)
		for h in get_world_2d().direct_space_state.intersect_shape(shapeQuery, 8):
			var pen: Vector2 = penetration(target, radius, h.collider)
			if pen != Vector2.ZERO:
				target += pen
				moved = true
		if not moved:
			break

	return target - center


## 给身体精灵套一个换色材质（每人一份独立实例）
func applyPlayerColor() -> void:
	var shader = load("res://shader/player_tint.gdshader")
	if shader == null or ani == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var hueIndex: int = absi(playerId - 1) % PLAYER_HUE_SHIFT.size()
	mat.set_shader_parameter("hue_shift", PLAYER_HUE_SHIFT[hueIndex])
	ani.material = mat


## 设置无敌（秒）：>0 时免疫伤害并闪烁
func setInvincible(seconds: float) -> void:
	invincibleTime = maxf(seconds, 0.0)
	invincible = invincibleTime > 0.0
	if not invincible and ani != null:
		ani.modulate.a = 1.0


## 物理帧更新：与状态无关的公共逻辑
##
## 状态相关行为由 StateMachine 子节点分发：
##   Idle → updateIdle / Hurt → updateHurt / Dead → updateDead
## StateMachine 是子节点，它的 _physics_process 在本函数之后执行。
func _physics_process(delta: float) -> void:
	updateCommon(delta)

	# 场景没挂状态机时退回 Idle 行为，避免角色完全不动。
	if fsm == null:
		updateIdle(delta)

	updateBoundsAndZ()


## 与状态无关的每帧处理：无敌计时/闪烁、自动回血、HUD 同步
func updateCommon(delta: float) -> void:
	# 无敌计时 + 闪烁
	if invincibleTime > 0.0:
		invincibleTime -= delta
		if ani != null:
			ani.modulate.a = 0.35 if int(invincibleTime * 10.0) % 2 == 0 else 1.0
		if invincibleTime <= 0.0:
			invincibleTime = 0.0
			invincible = false
			if ani != null:
				ani.modulate.a = 1.0

	# 原版玩家常驻自动回血：每 tick 回 maxHp/(25*30)，即 30 秒回满（doc/04 §2.2）
	# 没有脱战延迟，只要 0 < hp < maxHp 就持续生效
	if hp > 0 and hp < maxHp:
		regenAcc += maxHp / 30.0 * delta
		if regenAcc >= 1.0:
			var heal := int(regenAcc)
			regenAcc -= heal
			hp = mini(hp + heal, maxHp)
			lifeBar.maxHp = maxHp
	lifeBar.hp = hp


## 限制玩家在地图边界内，并按 Y 坐标设置 Z 轴顺序（2.5D）
func updateBoundsAndZ() -> void:
	# 按「相机可视范围」钳取，而不是整张地图：
	# 地图比相机大时，相机被夹在边缘 32px 内，玩家走到更外面就会出画。
	var play: Rect2 = MapData.getPlayRect()
	position.x = clampf(position.x, play.position.x + bodySize.x / 2, play.end.x - bodySize.x / 2)
	position.y = clampf(position.y, play.position.y + bodySize.y / 2, play.end.y - bodySize.y / 2)

	# 根据Y坐标设置Z轴顺序（实现2.5D视觉效果）
	z_index = floori(global_position.y / MapData.cellSize) + 1


## ---- 状态钩子（供 player_states/*.gd 调用）----

func onIdleEnter() -> void:
	# 与 FSM 同步旧的 state 枚举（其它代码仍在读它）
	state = Game.playerState.Idle


func onIdleExit() -> void:
	pass


func onHurtEnter() -> void:
	state = Game.playerState.hurt


func onHurtExit() -> void:
	# 离开 Hurt 时清掉击退与硬直；下一次受击由 hit() 重新写入
	hurtTimer = 0.0
	hurtMoveAcc = 0.0
	knockbackDelta = Vector2.ZERO
	knockbackFrames = 0


func onDeadEnter() -> void:
	state = Game.playerState.dead


## Idle：移动 / 瞄准 / 开火 / 切武器
func updateIdle(delta: float) -> void:
	currAni = "stand"

	# 获取输入方向（CPU：有行为树就消费它的意图，没有则退回临时 AI）
	var inputDir: Vector2
	if isCpu:
		if cpuBrain != null:
			if cpuAimDir != Vector2.ZERO:
				vector = cpuAimDir
			inputDir = cpuMoveDir
		else:
			inputDir = cpuUpdateAi(delta)
	else:
		inputDir = Input.get_vector(keyMap.left, keyMap.right, keyMap.up, keyMap.down)
	if inputDir.length() != 0:
		if not isCpu:
			vector = inputDir
		angle = round(vector.angle() / (PI / 4))
		angle = wrapi(int(angle), 0, 8)
		currAni = "walk"

	# 对角线移动时归一化速度
	if not inputDir.is_normalized():
		inputDir = inputDir.normalized()
	velocity = inputDir * speed

	# 根据武器类型播放对应动画
	if aniException.has(Game.weaponName[currWeapon.type]):
		ani.play(currAni + "_%s" % 1 + "_%s" % angle + "_%s" % 'other')
	else:
		ani.play(currAni + "_%s" % 1 + "_%s" % angle + "_%s" % Game.weaponName[currWeapon.type])

	# 更新武器弹药显示
	# CPU 不显示武器名（同屏 4 人时全是字，挡视线）
	txt.visible = not isCpu
	if isCpu:
		pass
	elif currWeapon.maxAmmoNum == 0:
		txt.text = Game.weaponName[currWeapon.type]
	else:
		txt.text = '%s:%s' % [Game.weaponName[currWeapon.type], currWeapon.ammoNum]

	# 根据弹药量改变文字颜色
	if currWeapon.maxAmmoNum != 0:
		if currWeapon.ammoNum <= 0:
			txt.modulate = Color(1.0, 0.25, 0.25, 0.85)
		else:
			# 暖白偏黄，配黑描边在浅色地面/深色地面都看得清
			txt.modulate = Color(1.0, 0.95, 0.75, 0.85)
	else:
		txt.modulate = Color(1.0, 0.95, 0.75, 0.85)

	# 处理射击输入（CPU 由 AI 决定是否开火；武器自身有冷却）
	if isCpu:
		if cpuWantFire:
			currWeapon.fire(vector)
	else:
		if Input.is_action_pressed(keyMap.fire):
			if currWeapon.type == Game.weaponType.Grenade:
				currWeapon.increase(delta)
			else:
				if currWeapon.automatic:
					currWeapon.fire(vector)
				elif Input.is_action_just_pressed(keyMap.fire):
					currWeapon.fire(vector)

		# 手榴弹释放时扔出
		if Input.is_action_just_released(keyMap.fire):
			if currWeapon.type == Game.weaponType.Grenade:
				currWeapon.fire(vector)

		# 处理武器切换输入
		if Input.is_action_just_pressed(keyMap.nextWeapon):
			switchWeapon()
		if Input.is_action_just_pressed(keyMap.prevWeapon):
			switchWeapon(false)

	# 移动并处理碰撞
	var displacement = velocity * delta
	if displacement != Vector2.ZERO:
		# 格子级阻挡：整体走不通就分轴尝试（原版 Collide_Map 的滑行语义）
		# 注意：如果自己脚下已经是障碍格（比如刚在脚下放了油桶），
		# 就允许自由离开，否则会被自己放的物体卡死。
		var center: Vector2 = body.global_position
		if not blockedByCell(center) and blockedByCell(center + displacement):
			if not blockedByCell(center + Vector2(displacement.x, 0)):
				displacement.y = 0
			elif not blockedByCell(center + Vector2(0, displacement.y)):
				displacement.x = 0
			else:
				displacement = Vector2.ZERO
		displacement = resolveAreaBlockers(displacement)
	move_and_collide(displacement)


## ---- CPU AI ----
##
## 简易行为：索敌 → 保持武器射程的 60% → 朝向目标开火；
## 没有敌人时跟着最近的人类队友。卡住 0.6 秒就侧向绕行 0.5 秒。
## 返回本帧的移动方向；同时写 vector（瞄准，供开火/动画用）与 cpuWantFire。
func cpuUpdateAi(delta: float) -> Vector2:
	cpuSwitchCd -= delta
	cpuDetourTime -= delta
	cpuRetarget -= delta

	if cpuRetarget <= 0.0 or cpuTarget == null or not is_instance_valid(cpuTarget) \
			or cpuTarget.get("isDead") == true:
		cpuRetarget = 0.3
		cpuTarget = cpuNearest("enemy")

	# CPU 只用枪械：手里是地雷/油桶/墙壁这类放置物，或枪没子弹了，就换一把
	if cpuSwitchCd <= 0.0 and (not cpuIsGun(currWeapon.type)
			or (currWeapon.maxAmmoNum > 0 and currWeapon.ammoNum <= 0)):
		cpuSwitchWeapon()
		cpuSwitchCd = 0.5

	var move := Vector2.ZERO
	var aim := Vector2.ZERO
	cpuWantFire = false

	if cpuTarget != null:
		var to: Vector2 = cpuTarget.global_position - global_position
		var dist: float = to.length()
		aim = to / maxf(dist, 0.001)
		var rangePx: float = maxf(float(currWeapon.wRange), 48.0)
		var want: float = rangePx * 0.6
		if dist > want + 24.0:
			move = aim
		elif dist < want - 32.0:
			move = -aim
		else:
			# 射程内左右游走，避免站着挨打 / 挡队友枪线
			var side := 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 2.0) < 1.0 else -1.0
			move = aim.orthogonal() * side
		cpuWantFire = dist <= rangePx and not cpuAllyInLine(aim, dist)
	else:
		# 没敌人：跟紧最近的人类队友
		var ally := cpuNearest("player", true)
		if ally != null:
			var to: Vector2 = ally.global_position - global_position
			if to.length() > 72.0:
				move = to.normalized()
			aim = move

	# 卡住检测：想走却 0.6 秒没挪动 → 侧向绕行
	if move != Vector2.ZERO:
		if global_position.distance_to(cpuLastPos) < 2.0:
			cpuStuck += delta
			if cpuStuck > 0.6 and cpuDetourTime <= 0.0:
				cpuDetour = move.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
				cpuDetourTime = 0.5
				cpuStuck = 0.0
		else:
			cpuStuck = 0.0
		if cpuDetourTime > 0.0:
			move = cpuDetour
	cpuLastPos = global_position

	if aim == Vector2.ZERO:
		aim = move
	if aim != Vector2.ZERO:
		vector = aim
	return move


## 行为树请求换枪：当前枪还在冷却时先不换，避免打断射击动画
func cpuRequestWeapon(wtype: int) -> void:
	if currWeapon != null and currWeapon.type == wtype:
		return
	if currWeapon != null and not currWeapon.canShoot:
		return
	for i in weaponList.size():
		if weaponList[i].type == wtype:
			currWeaponIndex = i
			currWeapon = weaponList[i]
			return


## CPU 换枪：只换枪械，且优先还有弹药（或无限弹药）的那把
func cpuSwitchWeapon() -> void:
	var n := weaponList.size()
	for i in range(1, n):
		var idx := (currWeaponIndex + i) % n
		var w = weaponList[idx]
		if not cpuIsGun(w.type):
			continue
		if w.maxAmmoNum > 0 and w.ammoNum <= 0:
			continue
		currWeaponIndex = idx
		currWeapon = w
		return


## 放置/投掷类武器（地雷、油桶、墙、炸药包、手榴弹）不交给 CPU
func cpuIsGun(_type: int) -> bool:
	return _type in [Game.weaponType.Pistol, Game.weaponType.Railgun, Game.weaponType.Rocket,
			Game.weaponType.Shotgun, Game.weaponType.UZI]


## 瞄准方向上有没有更近的队友（避免 CPU 打自己人）
func cpuAllyInLine(aim: Vector2, targetDist: float = 1e9) -> bool:
	for n in get_tree().get_nodes_in_group("player"):
		if n == self or not is_instance_valid(n) or n.get("isDead") == true:
			continue
		var to: Vector2 = n.global_position - global_position
		# 只算"挡在目标前面、且离射线足够近"的队友（垂直距离 < 24px）
		if to.dot(aim) <= 0.0 or to.dot(aim) > targetDist - 24.0:
			continue
		if absf(to.cross(aim)) < 24.0:
			return true
	return false


## 找最近的节点（group 内）；humansOnly 时跳过 CPU 玩家
func cpuNearest(groupName: String, humansOnly: bool = false) -> Node2D:
	var best: Node2D = null
	var bestD := INF
	for n in get_tree().get_nodes_in_group(groupName):
		if n == self or not is_instance_valid(n):
			continue
		if n.get("isDead") == true:
			continue
		if humansOnly and bool(n.get("isCpu")):
			continue
		var d: float = global_position.distance_squared_to(n.global_position)
		if d < bestD:
			bestD = d
			best = n
	return best


## Hurt：按 25Hz 应用击退（原版每 1/25 秒位移一次并 ×0.65）；播完由状态脚本切回 Idle
func updateHurt(delta: float) -> void:
	hurtTimer += delta
	hurtMoveAcc += delta
	var hudStep: float = 1.0 / MapData.TICKS_PER_SEC
	while hurtMoveAcc >= hudStep and knockbackFrames > 0 and knockbackDelta.length() > 0.01:
		hurtMoveAcc -= hudStep
		knockbackFrames -= 1
		var step: Vector2 = knockbackDelta * MapData.cellSize
		if not blockedByCell(body.global_position + step):
			move_and_collide(step)
		knockbackDelta *= 0.65


## Dead：倒地演出期间不响应输入，等 resurrection() 复活
func updateDead(_delta: float) -> void:
	# 死亡状态：无操作
	pass


## 受伤硬直是否结束（Hurt 状态用它决定何时回 Idle）
func hurtFinished() -> bool:
	return hurtTimer > hurtDelay and knockbackFrames <= 0
