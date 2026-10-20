extends Node

## 地图数据管理单例
# 负责管理游戏中的全局数据，包括：
# - 武器参数配置
# - 敌人参数配置
# - 地图配置
# - 玩家分数和连杀数据
# - 流场计算和寻路数据


## 格子大小常量
# 流场和地图网格的基本单位（像素）
const cellSize: float = 32

## 当前玩家人数
var playerCount = 1


## 武器基本参数信息
# 键：武器类型（Game.weaponType）
# 值：包含武器各项属性的字典
#   damage:       伤害值
#   wRange:       射程（像素）
#   delay:        开火延迟（秒）
#   maxAmmoNum:   最大弹药量（0表示无限弹药）
#   automatic:    是否自动连射
#   splitAngle:   霰弹枪散射角度（仅Shotgun）
#   splitExplosion: 分裂爆炸数量（仅Mine/Barrel/Grenade/ChargePack）
var allWeaponData = {
	Game.weaponType.Pistol: {'damage': 1, 'wRange': 300, 'delay': 0.6, 'maxAmmoNum': 0, 'automatic': false},
	Game.weaponType.UZI: {'damage': 1, 'wRange': 400, 'delay': 0.1, 'maxAmmoNum': 100, 'automatic': true},
	Game.weaponType.Shotgun: {'damage': 2, 'wRange': 300, 'delay': 0.1, 'maxAmmoNum': 20, 'splitAngle': 30, 'automatic': false},
	Game.weaponType.Mine: {'damage': 4, 'wRange': 0, 'delay': 0, 'maxAmmoNum': 10, 'splitExplosion': 0, 'automatic': false},
	Game.weaponType.Wall: {'damage': 0, 'wRange': 0, 'delay': 0, 'maxAmmoNum': 5, 'automatic': false},
	Game.weaponType.Barrel: {'damage': 4, 'wRange': 0, 'delay': 0, 'maxAmmoNum': 10, 'splitExplosion': 0, 'automatic': false},
	Game.weaponType.Grenade: {'damage': 4, 'wRange': 0, 'delay': 1, 'maxAmmoNum': 20, 'splitExplosion': 0, 'automatic': false},
	Game.weaponType.Rocket: {'damage': 5, 'wRange': 0, 'delay': 1.2, 'maxAmmoNum': 20, 'automatic': false},
	Game.weaponType.Railgun: {'damage': 4, 'wRange': 300, 'delay': 0.5, 'maxAmmoNum': 15, 'automatic': false},
	Game.weaponType.ChargePack: {'damage': 0, 'wRange': 0, 'delay': 0, 'maxAmmoNum': 10, 'automatic': false}
}

## 敌人基本参数信息
# 键：敌人类型（Game.roleType）
# 值：包含敌人属性的字典
#   speed: 移动速度
var enemyData = {
	Game.roleType.Zombie: {'speed': 16},
	Game.roleType.Devil: {'speed': 32}
}

## 一个逻辑 tick 的秒数
# 原版 CMain.mFPS = 25（doc/04 §1.1），射速/计时都按这个换算
const TICKS_PER_SEC: float = 25.0

## 升级标识（对应原版 CUpgrades.ApplyUpgrade_Weapon 的分支）
const UP_FAST_FIRE := &"FastFire"
const UP_RAPID_FIRE := &"RapidFire"
const UP_DOUBLE_DAMAGE := &"DoubleDamage"
const UP_QUAD_DAMAGE := &"QuadDamage"
const UP_DOUBLE_AMMO := &"DoubleAmmo"
const UP_QUAD_AMMO := &"QuadAmmo"
const UP_INFINATE_AMMO := &"InfinateAmmo"
const UP_LONG_SHOT := &"LongShot"
const UP_INFINATE_RANGE := &"InfinateRange"
const UP_WIDE_SHOT := &"WideShot"
const UP_WIDER_SHOT := &"WiderShot"
const UP_BIG_BANG := &"BigBang"
const UP_BIGGER_BANG := &"BiggerBang"
const UP_CLUSTER_EXPLODE := &"ClusterExplode"

## 地图配置
# 存储游戏难度和规则设置
#   difficulty:     难度等级（1-4）
#   collision:      是否启用碰撞检测
#   Devils:         是否生成恶魔敌人
#   friendlyFire:   是否启用友军伤害
#   Game speed:     游戏速度倍率
var mapConfig = {'difficulty': 1, 'collision': true, 'Devils': true, 'friendlyFire': true,
				'gameSpeed': 1}

## 当前连杀数（显示用）
var currKillStreak = 0
## 累计连杀数（记录最高值）
var killStreak = 0
## 当前分数
var score = 0
## 已解锁武器列表
var weaponUnlock = []

## 武器原始数值快照（原版绝对值）
# 升级永远从这里重算，不做增量叠加 —— 对应原版 mOriginalStats（doc/03 §7.1）
var weaponBaseStats = {}
## 每把武器已获得的升级：{weaponType: {升级标识: true}}
var weaponUpgrades = {}
## 倍率 -> 升级项列表（doc/03 §8.1）
var upgradeTable = {}
## 当前地图大小
var mapSize: Vector2
## 已选地图 id（对应 Game.mapId[].id；0 = 默认 room_001）
var selectedMapId: int = 0
## 地图格子占用记录
# 键："x-y"格式的格子坐标字符串
# 值：占用该格子的物体实例ID
var mapTile = {}
## 障碍物集合
# 键："x-y"格式的格子坐标字符串
# 值：障碍物位置（Vector2）
var obstacle: Dictionary = {}
## 流场字典（多玩家支持）
# 键：玩家ID（int）
# 值：流场方向字典，键为"x-y"格式的格子坐标，值为方向向量（Vector2）
var flowFieldDict = {}
## 流场是否需要立刻重算
# 增删障碍时置位；map.gd 每物理帧检查，置位就重算并清零
var flowDirty: bool = true
## 障碍版本号（每次增删 +1，便于调试/断言）
var obstacleVersion: int = 0
var killRewardBox=30 #击杀数是当前数的倍数就有补给箱

## 8 邻域（含对角），顺序无关紧要
const NEIGHBOR_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

## 初始化
func _ready() -> void:
	# 武器数值表必须在这里初始化：
	# 下面 var allWeaponData 的初始值已经是历史残留（旧的 1 伤害 / 300 射程），
	# 不调用 resetAllWeaponData() 的话，整套原版数值 + 升级表都不会生效。
	resetAllWeaponData()


# ---------------------------------------------------------------- 格子与障碍

## 格子坐标 → 字典键
func cellKey(cell: Vector2i) -> String:
	return "%s-%s" % [cell.x, cell.y]


## 世界坐标 → 格子坐标
func worldToCell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / cellSize), floori(pos.y / cellSize))


## 格子坐标 → 该格中心的世界坐标（放置物对齐用）
func cellCenter(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * cellSize + cellSize * 0.5, cell.y * cellSize + cellSize * 0.5)


## 该格是否是障碍
## 物理层位掩码（对应 project.godot 的 2d_physics/layer_*）
const LAYER_PLAYER := 1
const LAYER_ENEMY := 2
const LAYER_ITEM := 4
const LAYER_WALL := 8

## 僵尸占用的格子：cellKey -> Zombie
##
## 用来避免多只僵尸挤在同一格：canStep 会避开这些格，
## 让它们排队/绕行，而不是一路硬推到重叠。
var zombieCells: Dictionary = {}


## 登记某个格子被哪只僵尸占用
func setZombieCell(cell: Vector2i, z: Node) -> void:
	zombieCells[cellKey(cell)] = z


## 注销占用（只有当占用者确实是它时才删）
func clearZombieCell(cell: Vector2i, z: Node) -> void:
	var k := cellKey(cell)
	if zombieCells.get(k) == z:
		zombieCells.erase(k)


## 取某格上的僵尸（没有则 null）
func getZombieAt(cell: Vector2i) -> Node:
	return zombieCells.get(cellKey(cell))


func isObstacle(cell: Vector2i) -> bool:
	return obstacle.has(cellKey(cell))


## 添加障碍（格子坐标）
# 放置油桶 / 喷墙时调用，让流场绕开它
func addObstacleAt(cell: Vector2i) -> void:
	var key := cellKey(cell)
	if obstacle.has(key):
		return
	obstacle[key] = Vector2(cell)
	obstacleVersion += 1
	flowDirty = true


## 移除障碍（格子坐标）
# 油桶爆炸 / 墙被打碎时调用
func removeObstacleAt(cell: Vector2i) -> void:
	var key := cellKey(cell)
	if not obstacle.has(key):
		return
	obstacle.erase(key)
	obstacleVersion += 1
	flowDirty = true


## 兼容旧接口：房间脚本按"格子坐标"传 Vector2
func addObstacle(pos: Vector2) -> void:
	addObstacleAt(Vector2i(int(pos.x), int(pos.y)))


## 兼容旧接口：按格子坐标移除
func removeObstacle(pos: Vector2) -> void:
	removeObstacleAt(Vector2i(int(pos.x), int(pos.y)))


## 清空所有障碍物
func clearObstacle():
	obstacle.clear()
	obstacleVersion += 1
	flowDirty = true


## 清空地图格子占用记录
func clearMapTile():
	pass


# ---------------------------------------------------------------- 流场

## 计算流场
# 以 target 格为源做 BFS 得到距离场，再为每格选"指向距离最小邻居"的方向。
# 相比旧实现修了四个问题：
#   1) 障碍判定错取成"当前格"而不是"邻居格"；
#   2) 对角代价条件写成 i.x != 0 || i.y != 0，恒为真（等于没生效）；
#   3) flowFieldDict[id] 只在新键时创建，导致第一个格子的方向丢失；
#   4) 重算时不清旧键，障碍消失后旧方向会残留。
# 另外新增"斜向不允许穿墙角"。
func computeFields(id, target: Vector2 = Vector2.INF) -> void:
	var cellX := int(mapSize.x / cellSize)
	var cellY := int(mapSize.y / cellSize)
	if cellX <= 0 or cellY <= 0:
		return

	var start := Vector2i(-1, -1)
	if target != Vector2.INF:
		start = Vector2i(clampi(int(target.x), 0, cellX - 1), clampi(int(target.y), 0, cellY - 1))

	if start.x < 0:
		# 没有有效目标（例如还没生成玩家）：整张流场置零
		flowFieldDict[id] = {}
		return

	# ---- BFS 距离场（8 邻域，单位步长）
	var dist: Dictionary = {}
	dist[cellKey(start)] = 0
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		var d: int = dist[cellKey(p)]
		for i in NEIGHBOR_DIRS:
			var n: Vector2i = p + i
			if n.x < 0 or n.y < 0 or n.x >= cellX or n.y >= cellY:
				continue
			if obstacle.has(cellKey(n)):
				continue
			if i.x != 0 and i.y != 0:
				# 斜向不允许从两个障碍的夹角里穿过去
				if obstacle.has(cellKey(Vector2i(p.x + i.x, p.y))) \
						or obstacle.has(cellKey(Vector2i(p.x, p.y + i.y))):
					continue
			if dist.has(cellKey(n)):
				continue
			dist[cellKey(n)] = d + 1
			queue.append(n)

	# ---- 方向场：每格指向距离最小的邻居
	var field := {}
	for x in range(cellX):
		for y in range(cellY):
			var pos := Vector2i(x, y)
			var key := cellKey(pos)
			if pos == start or obstacle.has(key):
				field[key] = Vector2.ZERO
				continue

			var best := Vector2.ZERO
			var bestCost := INF
			for i in NEIGHBOR_DIRS:
				var n: Vector2i = pos + i
				if n.x < 0 or n.y < 0 or n.x >= cellX or n.y >= cellY:
					continue
				if obstacle.has(cellKey(n)):
					continue
				if i.x != 0 and i.y != 0:
					if obstacle.has(cellKey(Vector2i(pos.x + i.x, pos.y))) \
							or obstacle.has(cellKey(Vector2i(pos.x, pos.y + i.y))):
						continue
				if not dist.has(cellKey(n)):
					continue
				# 距离相同优先走四方向，避免走成锯齿
				var cost: int = int(dist[cellKey(n)]) * 2
				if i.x != 0 and i.y != 0:
					cost += 1
				if cost < bestCost:
					bestCost = cost
					best = Vector2(i)
			field[key] = best

	flowFieldDict[id] = field


## 获取流场方向
# 根据当前位置和玩家ID获取流场指引的移动方向
# @param pos 当前世界坐标位置（Vector2）
# @param id 玩家ID（int）
# @return 流场方向向量（Vector2），无数据时返回ZERO
func getFlowDir(pos: Vector2, id) -> Vector2:
	var key := cellKey(worldToCell(pos))
	if flowFieldDict.has(id):
		var field = flowFieldDict[id]
		if field.has(key):
			return field[key]
	return Vector2.ZERO


## 检查指定位置是否有地图物品
# @param pos 世界坐标位置（Vector2）
# @return 是否有物品占用该格子（bool）
func checkHasMapItem(pos: Vector2):
	var x = floori(pos.x / cellSize)
	var y = floori(pos.y / cellSize)
	var flag = false
	if mapTile.has("%s-%s" % [x, y]):
		var temp = mapTile["%s-%s" % [x, y]]
		if is_instance_id_valid(temp):
			flag = true
	return flag


## 添加地图物品占用记录
# @param pos 世界坐标位置（Vector2）
# @param id 物品实例ID（int）
func addMapItem(pos: Vector2, id: int):
	var x = floori(pos.x / cellSize)
	var y = floori(pos.y / cellSize)
	mapTile["%s-%s" % [x, y]] = id


## 添加连杀数
# @param val 增加的连杀数（int）
func addKillStreak(val):
	currKillStreak += val
	if currKillStreak > killStreak:
		killStreak = currKillStreak
		countKillStreak()


## 计算连杀奖励
# 倍率逐 1 递增，只在"恰好等于某一档"时发放，且每项只发一次
# 出处：__Packages/World/CUpgrades.as:403-460（doc/03 §8.1）
func countKillStreak():
	for item in upgradeTable.get(killStreak, []):
		if item.has('unlock'):
			unlockWeapon(item.unlock, item.text)
		else:
			applyUpgrade(item.w, item.up, item.text)


## 解锁一把新武器
func unlockWeapon(type, text: String) -> void:
	if not weaponUnlock.has(type):
		weaponUnlock.append(type)
	Game.notice.emit(tr(text))


## 发放一次升级（每项只发一次，之后从原始值重算）
# @param type    目标武器（Game.weaponType）
# @param upgrade 升级标识（见 UP_* 常量）
# @param text    HUD 提示文本
func applyUpgrade(type, upgrade, text: String) -> void:
	if not weaponBaseStats.has(type):
		return
	if weaponUpgrades[type].has(upgrade):
		return
	weaponUpgrades[type][upgrade] = true
	recomputeWeapon(type)
	Game.weaponUpgrade.emit(type)
	Game.notice.emit(tr(text))


## 从原始值重算某把武器的当前数值（幂等，可反复调用）
func recomputeWeapon(type) -> void:
	if not weaponBaseStats.has(type):
		return

	var base: Dictionary = weaponBaseStats[type]
	var up: Dictionary = weaponUpgrades[type]
	var s: Dictionary = base.duplicate(true)

	# --- 伤害：Double ×2 / Quad ×4（原版还有 Fatal ×10，解锁表里没有）
	if up.has(UP_DOUBLE_DAMAGE):
		s.damage *= 2
	if up.has(UP_QUAD_DAMAGE):
		s.damage *= 4

	# --- 射速：FastFire 只改成"按住连发"；RapidFire 再把间隔压到 round(max(帧/4, 2))
	if up.has(UP_FAST_FIRE):
		s.automatic = true
	if up.has(UP_RAPID_FIRE):
		var frames: float = roundf(maxf(base.delay * TICKS_PER_SEC / 4.0, 2.0))
		s.delay = frames / TICKS_PER_SEC
		s.automatic = true

	# --- 弹药：Double ×2 / Quad ×4 / Infinite
	if up.has(UP_DOUBLE_AMMO):
		s.maxAmmoNum *= 2
		s.ammoNum *= 2
	if up.has(UP_QUAD_AMMO):
		s.maxAmmoNum *= 4
		s.ammoNum *= 4
	if up.has(UP_INFINATE_AMMO):
		s.maxAmmoNum = 999999
		s.ammoNum = 999999

	# --- 射程：LongShot ×1.5 / InfinateRange 100 格
	# 只有 Pistol / UZI / Shotgun / Railgun 原版有 mRange，其余不要凭空空填
	if base.get('wRange', 0) > 0:
		if up.has(UP_LONG_SHOT):
			s.wRange = int(base.wRange * 1.5)
		if up.has(UP_INFINATE_RANGE):
			s.wRange = 100 * int(cellSize)

	# --- 霰弹散射角
	# 原版 mWideShot 只写不读、升级实际无效（doc/03 §7.5）；
	# 这里按"散射真的变宽"补全，属于新增设计，不是还原
	if base.has('splitAngle'):
		if up.has(UP_WIDE_SHOT):
			s.splitAngle = base.splitAngle * 1.5
		if up.has(UP_WIDER_SHOT):
			s.splitAngle = base.splitAngle * 2.0

	# --- 爆炸物的子爆炸 / 分裂弹
	if base.has('biggerBang'):
		if up.has(UP_BIG_BANG):
			s.biggerBang = 1
		if up.has(UP_BIGGER_BANG):
			s.biggerBang = 2
	if base.has('clusterExplode'):
		s.clusterExplode = 1 if up.has(UP_CLUSTER_EXPLODE) else 0

	allWeaponData[type] = s


## 重算全部武器（初始化用）
func recomputeAllWeapons() -> void:
	for type in weaponBaseStats:
		recomputeWeapon(type)


## 重置武器数据到初始状态
# 数值全部取原版绝对值（doc/03 §2），单位换算见 doc/04 §1.1：
#   射速 mFireRate(帧) -> delay(秒) = 帧 / 25
#   射程 mRange(格)   -> wRange(像素) = 格 * 32
#   弹药 mTotalAmmo   -> maxAmmoNum（Pistol 的 999999 无限用 0 表示）
func resetAllWeaponData():
	var W := Game.weaponType
	weaponBaseStats = {
		# 手枪：8 帧 / 26 伤害 / 8 格 / 无限弹药
		W.Pistol: {'damage': 26, 'wRange': 256, 'delay': 0.32, 'maxAmmoNum': 0,
				'ammoNum': 0, 'automatic': false},
		# UZI：4 帧 / 35 伤害 / 100 发 / 8 格 / 按住连发
		W.UZI: {'damage': 35, 'wRange': 256, 'delay': 0.16, 'maxAmmoNum': 100,
				'ammoNum': 100, 'automatic': true},
		# 霰弹枪：12 帧 / 51 伤害 / 20 发 / 7 格
		W.Shotgun: {'damage': 51, 'wRange': 224, 'delay': 0.48, 'maxAmmoNum': 20,
				'ammoNum': 20, 'splitAngle': 30.0, 'automatic': false},
		# 地雷：100 伤害 / 10 个
		W.Mine: {'damage': 100, 'wRange': 0, 'delay': 0.04, 'maxAmmoNum': 10,
				'ammoNum': 10, 'splitExplosion': 0, 'clusterExplode': 0,
				'biggerBang': 0, 'automatic': false},
		# 假墙：原版 Fire 不传伤害，只用来挡路
		W.Wall: {'damage': 0, 'wRange': 0, 'delay': 0.04, 'maxAmmoNum': 5,
				'ammoNum': 5, 'automatic': false},
		# 油桶：150 伤害 / 10 个
		W.Barrel: {'damage': 150, 'wRange': 0, 'delay': 0.04, 'maxAmmoNum': 10,
				'ammoNum': 10, 'splitExplosion': 0, 'clusterExplode': 0,
				'biggerBang': 0, 'automatic': false},
		# 手雷：12 帧 / 150 伤害 / 20 个 / 投掷 6 格
		W.Grenade: {'damage': 150, 'wRange': 192, 'delay': 0.48, 'maxAmmoNum': 20,
				'ammoNum': 20, 'splitExplosion': 0, 'clusterExplode': 0,
				'biggerBang': 0, 'automatic': false},
		# 火箭：12 帧 / 250 伤害 / 20 个
		W.Rocket: {'damage': 250, 'wRange': 0, 'delay': 0.48, 'maxAmmoNum': 20,
				'ammoNum': 20, 'clusterExplode': 0, 'biggerBang': 0, 'automatic': false},
		# 电磁炮：5 帧 / 100 伤害 / 15 发 / 10 格
		W.Railgun: {'damage': 100, 'wRange': 320, 'delay': 0.20, 'maxAmmoNum': 15,
				'ammoNum': 15, 'automatic': false},
		# 充电包：150 伤害 / 10 个
		W.ChargePack: {'damage': 150, 'wRange': 0, 'delay': 0.04, 'maxAmmoNum': 10,
				'ammoNum': 10, 'splitExplosion': 0, 'clusterExplode': 0,
				'biggerBang': 0, 'automatic': false},
	}

	weaponUpgrades = {}
	for type in weaponBaseStats:
		weaponUpgrades[type] = {}

	buildUpgradeTable()
	recomputeAllWeapons()


## 构建倍率 -> 升级项的掉落表
# 出处：__Packages/World/CUpgrades.as:403-460（doc/03 §8.1），顺序与原版一致
func buildUpgradeTable() -> void:
	var W := Game.weaponType
	var t := {}

	var up := func(m: int, w, upName, text: String) -> void:
		if not t.has(m):
			t[m] = []
		t[m].append({'w': w, 'up': upName, 'text': text})

	var unlock := func(m: int, w, text: String) -> void:
		if not t.has(m):
			t[m] = []
		t[m].append({'unlock': w, 'text': text})

	up.call(3, W.Pistol, UP_FAST_FIRE, 'Pistol+: Fast Fire')
	unlock.call(5, W.UZI, 'New Weapon: UZI')
	up.call(8, W.Pistol, UP_DOUBLE_DAMAGE, 'Pistol+: Double Damage')
	unlock.call(10, W.Shotgun, 'New Weapon: Shotgun')
	up.call(13, W.UZI, UP_RAPID_FIRE, 'UZI+: Rapid Fire')
	unlock.call(15, W.Barrel, 'New Weapon: Barrel')
	up.call(17, W.UZI, UP_DOUBLE_AMMO, 'UZI+: Double Ammo')
	up.call(18, W.Shotgun, UP_FAST_FIRE, 'Shotgun+: Fast Fire')
	unlock.call(20, W.Grenade, 'New Weapon: Grenade')
	up.call(21, W.Shotgun, UP_DOUBLE_AMMO, 'Shotgun+: Double Ammo')
	up.call(23, W.UZI, UP_LONG_SHOT, 'UZI+: Long Shot')
	up.call(26, W.Barrel, UP_DOUBLE_AMMO, 'Barrel+: Double Ammo')
	unlock.call(30, W.Wall, 'New Weapon: Fake walls')
	up.call(31, W.Shotgun, UP_WIDE_SHOT, 'Shotgun+: Wide Shot')
	up.call(32, W.Barrel, UP_BIG_BANG, 'Barrel+: Big Bang')
	up.call(33, W.Grenade, UP_CLUSTER_EXPLODE, 'Grenade+: Cluster Explode')
	up.call(35, W.Shotgun, UP_LONG_SHOT, 'Shotgun+: Long Shot')
	up.call(36, W.Barrel, UP_QUAD_AMMO, 'Barrel+: Quad Ammo')
	up.call(37, W.Wall, UP_DOUBLE_AMMO, 'Fake Wall+: Double Ammo')
	up.call(39, W.UZI, UP_QUAD_AMMO, 'UZI+: Quad Ammo')
	unlock.call(40, W.Mine, 'New Weapon: Claymore')
	up.call(41, W.Shotgun, UP_QUAD_AMMO, 'Shotgun+: Quad Ammo')
	up.call(42, W.Grenade, UP_DOUBLE_AMMO, 'Grenade+: Double Ammo')
	up.call(43, W.Shotgun, UP_RAPID_FIRE, 'Shotgun+: Rapid Fire')
	up.call(44, W.Barrel, UP_BIGGER_BANG, 'Barrel+: Bigger Bang')
	up.call(45, W.Grenade, UP_BIG_BANG, 'Grenade+: Big Bang')
	up.call(47, W.Mine, UP_CLUSTER_EXPLODE, 'Claymore+: Cluster Explode')
	up.call(48, W.UZI, UP_DOUBLE_DAMAGE, 'UZI+: Double Damage')
	unlock.call(50, W.Rocket, 'New Weapon: Rocket')
	up.call(51, W.Shotgun, UP_WIDER_SHOT, 'Shotgun+: Wider Shot')
	up.call(52, W.Grenade, UP_QUAD_AMMO, 'Grenade+: Quad Ammo')
	up.call(53, W.Wall, UP_QUAD_AMMO, 'Fake Wall+: Quad Ammo')
	up.call(54, W.Mine, UP_DOUBLE_AMMO, 'Claymore+: Double Ammo')
	unlock.call(55, W.ChargePack, 'New Weapon: Chargepack')
	up.call(56, W.Shotgun, UP_DOUBLE_DAMAGE, 'Shotgun+: Double Damage')
	up.call(57, W.Grenade, UP_BIGGER_BANG, 'Grenade+: Bigger Bang')
	up.call(58, W.Mine, UP_BIG_BANG, 'Claymore+: Big Bang')
	up.call(59, W.Rocket, UP_FAST_FIRE, 'Rocket+: Fast Fire')
	up.call(61, W.UZI, UP_INFINATE_RANGE, 'UZI+: Infinate Range')
	up.call(62, W.Mine, UP_BIGGER_BANG, 'Claymore+: Bigger Bang')
	up.call(63, W.ChargePack, UP_CLUSTER_EXPLODE, 'Charge Pack+: Cluster Explode')
	up.call(64, W.Mine, UP_QUAD_AMMO, 'Claymore+: Quad Ammo')
	up.call(66, W.Rocket, UP_DOUBLE_AMMO, 'Rocket+: Double Ammo')
	up.call(68, W.ChargePack, UP_DOUBLE_AMMO, 'Charge Pack+: Double Ammo')
	unlock.call(70, W.Railgun, 'New Weapon: Railgun')
	up.call(72, W.Rocket, UP_BIG_BANG, 'Rocket+: Big Bang')
	up.call(74, W.ChargePack, UP_BIG_BANG, 'Charge Pack+: Big Bang')
	up.call(76, W.ChargePack, UP_QUAD_AMMO, 'Charge Pack+: Quad Ammo')
	up.call(78, W.Railgun, UP_FAST_FIRE, 'Railgun+: Fast Fire')
	up.call(80, W.Railgun, UP_DOUBLE_AMMO, 'Railgun+: Double Ammo')
	up.call(85, W.Rocket, UP_QUAD_AMMO, 'Rocket+: Quad Ammo')
	up.call(90, W.UZI, UP_QUAD_DAMAGE, 'UZI+: Quad Damage')
	up.call(95, W.ChargePack, UP_BIGGER_BANG, 'Charge Pack+: Bigger Bang')
	up.call(100, W.Railgun, UP_RAPID_FIRE, 'Railgun+: Rapid Fire')
	up.call(105, W.Rocket, UP_BIGGER_BANG, 'Rocket+: Bigger Bang')
	up.call(110, W.Railgun, UP_QUAD_AMMO, 'Railgun+: Quad Ammo')
	up.call(120, W.Rocket, UP_RAPID_FIRE, 'Rocket+: Rapid Fire')
	up.call(125, W.Railgun, UP_LONG_SHOT, 'Railgun+: Long Shot')

	upgradeTable = t


## 重置地图配置到初始状态
func resetMapConfig():
	mapConfig = {'difficulty': 1, 'collision': true, 'Devils': true, 'friendlyFire': true,
				'gameSpeed': 1}
