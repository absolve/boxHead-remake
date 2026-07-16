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
	Game.roleType.Zombie: {'speed': 20},
	Game.roleType.Devil: {'speed': 30}
}

## 地图配置
# 存储游戏难度和规则设置
#   difficulty:     难度等级（1-4）
#   collision:      是否启用碰撞检测
#   Devils:         是否生成恶魔敌人
#   friendlyFire:   是否启用友军伤害
#   Game speed:     游戏速度倍率
var mapConfig = {'difficulty': 1, 'collision': true, 'Devils': true, 'friendlyFire': true,
				'Game speed': 1}


## 当前连杀数（显示用）
var currKillStreak = 0

## 累计连杀数（记录最高值）
var killStreak = 0

## 当前分数
var score = 0

## 已解锁武器列表
var weaponUnlock = []

## 当前地图大小
var mapSize: Vector2

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


## 初始化
func _ready() -> void:
	pass


## 计算流场
# 为指定玩家ID生成从所有格子指向目标点的流场方向
# 使用广度优先搜索计算距离场，再根据距离场计算方向场
# @param id 玩家ID（用于区分多玩家的流场）
# @param _target 目标格子坐标（Vector2，默认为INF）
func computeFields(id, _target: Vector2 = Vector2.INF):
	var distanceField = {}
	var cellX = int(mapSize.x / cellSize)
	var cellY = int(mapSize.y / cellSize)
	
	# 初始化每个格子的距离为无穷大
	for x in range(cellX):
		for y in range(cellY):
			distanceField["%s-%s" % [x, y]] = INF
	
	# 8方向搜索方向数组
	var dirs = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),
		Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]
	
	# 目标点距离设为0
	distanceField["%s-%s" % [int(_target.x), int(_target.y)]] = 0
	var t: Array[Vector2] = []
	t.append(_target)
	
	# BFS广度优先搜索计算距离场
	while t.size() > 0:
		var p = t.pop_front()
		for i in dirs:
			var pos: Vector2 = p + i
			# 边界检查
			if pos.x < 0 || pos.y < 0 || pos.x >= cellX || pos.y >= cellY:
				continue
			# 障碍物检查
			if obstacle.has("%s-%s" % [int(pos.x), int(pos.y)]):
				continue
			# 如果该格子尚未访问
			if distanceField["%s-%s" % [int(pos.x), int(pos.y)]] == INF:
				distanceField["%s-%s" % [int(pos.x), int(pos.y)]] = distanceField["%s-%s" % [int(p.x), int(p.y)]] + 1
				# 对角线移动额外增加0.5距离代价
				if i.x != 0 || i.y != 0:
					distanceField["%s-%s" % [int(pos.x), int(pos.y)]] += 0.5
				t.append(pos)
	
	# 根据距离场计算流场方向（每个格子指向距离目标最近的邻居）
	for x in range(cellX):
		for y in range(cellY):
			var mindistance = INF
			var bestDir = Vector2.ZERO
			var pos = Vector2(x, y)
			for i in dirs:
				var n = pos + i
				if n.x < 0 || n.y < 0 || n.x >= cellX || n.y >= cellY:
					continue
				if obstacle.has("%s-%s" % [int(pos.x), int(pos.y)]):
					continue
				if distanceField["%s-%s" % [int(n.x), int(n.y)]] < mindistance:
					mindistance = distanceField["%s-%s" % [int(n.x), int(n.y)]]
					bestDir = i
			# 根据玩家ID存储流场方向
			if flowFieldDict.has(id):
				flowFieldDict[id]["%s-%s" % [int(pos.x), int(pos.y)]] = bestDir
			else:
				flowFieldDict[id] = {}


## 获取流场方向
# 根据当前位置和玩家ID获取流场指引的移动方向
# @param pos 当前世界坐标位置（Vector2）
# @param id 玩家ID（int）
# @return 流场方向向量（Vector2），无数据时返回ZERO
func getFlowDir(pos: Vector2, id):
	var x = floori(pos.x / cellSize)
	var y = floori(pos.y / cellSize)
	if flowFieldDict.has(id) && flowFieldDict[id].has("%s-%s" % [x, y]):
		return flowFieldDict[id]["%s-%s" % [x, y]]
	else:
		return Vector2.ZERO


## 添加障碍物
# 将指定格子标记为障碍物，影响流场计算和路径寻路
# @param pos 格子坐标（Vector2，整数坐标）
func addObstacle(pos: Vector2):
	if !obstacle.has("%s-%s" % [int(pos.x), int(pos.y)]):
		obstacle["%s-%s" % [int(pos.x), int(pos.y)]] = pos


## 清空所有障碍物
func clearObstacle():
	obstacle.clear()


## 清空地图格子占用记录
func clearMapTile():
	pass


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
# 根据当前连杀数触发对应的武器升级或新武器解锁
func countKillStreak():
	match killStreak:
		3: # Pistol+: Fast Fire - 手枪射速提升
			allWeaponData[Game.weaponType.Pistol].delay = 0.3
			Game.weaponUpgrade.emit(Game.weaponType.Pistol)
			Game.notice.emit(tr("Pistol+: Fast Fire"))
		5: # New Weapon: UZI - 解锁UZI
			weaponUnlock.append(Game.weaponType.UZI)
			Game.notice.emit(tr("New Weapon: UZI"))
		8: # Pistol+: Double Damage - 手枪伤害翻倍
			allWeaponData[Game.weaponType.Pistol].damage *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Pistol)
			Game.notice.emit(tr("Pistol+: Double Damage"))
		10: # New Weapon: Shotgun - 解锁霰弹枪
			weaponUnlock.append(Game.weaponType.UZI)
			Game.notice.emit(tr("New Weapon: Shotgun"))
		13: # UZI+: Rapid Fire - UZI射速提升
			allWeaponData[Game.weaponType.Pistol].delay = 0.1
			Game.weaponUpgrade.emit(Game.weaponType.UZI)
			Game.notice.emit(tr("UZI+: Rapid Fire"))
		15: # New Wepon: Barrel - 解锁油桶
			weaponUnlock.append(Game.weaponType.Barrel)
			Game.notice.emit(tr("New Wepon: Barrel"))
		17: # UZI+: Double Ammo - UZI弹药翻倍
			allWeaponData[Game.weaponType.UZI].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.UZI)
			Game.notice.emit(tr("UZI+: Double Ammo"))
		18: # Shotgun+: Fast Fire - 霰弹枪射速提升
			allWeaponData[Game.weaponType.Shotgun].delay = 0.3
			allWeaponData[Game.weaponType.Shotgun].automatic = true
			Game.weaponUpgrade.emit(Game.weaponType.Shotgun)
			Game.notice.emit(tr("Shotgun+: Fast Fire"))
		20: # New Weapon: Grenade - 解锁手榴弹
			weaponUnlock.append(Game.weaponType.Grenade)
			Game.notice.emit(tr("New Weapon: Grenade"))
		21: # Shotgun+: Double Ammo - 霰弹枪弹药翻倍
			allWeaponData[Game.weaponType.Shotgun].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Shotgun)
			Game.notice.emit(tr("Shotgun+: Double Ammo"))
		23: # UZI+: Long Shot - UZI射程翻倍
			allWeaponData[Game.weaponType.UZI].wRange *= 2
			Game.weaponUpgrade.emit(Game.weaponType.UZI)
			Game.notice.emit(tr("UZI+: Long Shot"))
		26: # Barrel+: Double Ammo - 油桶弹药翻倍
			allWeaponData[Game.weaponType.Barrel].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Barrel)
			Game.notice.emit(tr("Barrel+: Double Ammo"))
		30: # New Weapon: Fake walls - 解锁墙壁
			weaponUnlock.append(Game.weaponType.Wall)
			Game.notice.emit(tr("New Weapon: Fake walls"))
		31: # Shotgun+: Wide Shot - 霰弹枪散射角度翻倍
			allWeaponData[Game.weaponType.Shotgun].splitAngle *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Shotgun)
			Game.notice.emit(tr("Shotgun+: Wide Shot"))
		32: # Barrel+: Big Bang - 油桶大爆炸（未实现）
			pass
		33: # Grenade+: Cluster Explode - 手榴弹分裂爆炸（未实现）
			pass
		35: # Shotgun+: Long Shot - 霰弹枪射程提升
			allWeaponData[Game.weaponType.Shotgun].wRange = 600
			Game.weaponUpgrade.emit(Game.weaponType.Shotgun)
			Game.notice.emit(tr("Shotgun+: Long Shot"))
		36: # Barrel+: Quad Ammo - 油桶弹药4倍
			allWeaponData[Game.weaponType.Barrel].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.Barrel)
			Game.notice.emit(tr("Barrel+: Quad Ammo"))
		37: # Fake Wall+: Double Ammo - 墙壁弹药翻倍
			allWeaponData[Game.weaponType.Wall].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Wall)
			Game.notice.emit(tr("Fake Wall+: Double Ammo"))
		39: # UZI+: Quad Ammo - UZI弹药4倍
			allWeaponData[Game.weaponType.UZI].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.UZI)
			Game.notice.emit(tr("UZI+: Quad Ammo"))
		40: # New Weapon: Claymore - 解锁地雷
			weaponUnlock.append(Game.weaponType.Mine)
			Game.notice.emit(tr("New Weapon: Claymore"))
		41: # Shotgun+: Quad Ammo - 霰弹枪弹药4倍
			allWeaponData[Game.weaponType.Shotgun].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.Shotgun)
			Game.notice.emit(tr("Shotgun+: Quad Ammo"))
		42: # Grenade+: Double Ammo - 手榴弹弹药翻倍
			allWeaponData[Game.weaponType.Grenade].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Grenade)
			Game.notice.emit(tr("Grenade+: Double Ammo"))
		43: # Shotgun+: Rapid Fire - 霰弹枪快速射击
			allWeaponData[Game.weaponType.Shotgun].delay = 0.3
			Game.weaponUpgrade.emit(Game.weaponType.Shotgun)
			Game.notice.emit(tr("Shotgun+: Rapid Fire"))
		44: # Barrel+: Bigger Bang - 油桶更大爆炸（未实现）
			pass
		45: # Grenade+: Big Bang - 手榴弹大爆炸（未实现）
			pass
		47: # Claymore+: Cluster Explode - 地雷分裂爆炸（未实现）
			pass
		48: # UZI+: Double Damager - UZI伤害翻倍
			allWeaponData[Game.weaponType.UZI].damage *= 2
			Game.weaponUpgrade.emit(Game.weaponType.UZI)
			Game.notice.emit(tr("UZI+: Double Damager"))
		50: # New Weapon: Rocket - 解锁火箭发射器
			weaponUnlock.append(Game.weaponType.Rocket)
			Game.notice.emit(tr("New Weapon: Rocket"))
		51: # Shotgun+: Wider Shot - 霰弹枪更广散射（未实现）
			pass
		52: # Grenade+: Quad Ammo - 手榴弹弹药4倍
			allWeaponData[Game.weaponType.Grenade].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.Grenade)
			Game.notice.emit(tr("Grenade+: Quad Ammo"))
		53: # Fake Wall+: Quad Ammo - 墙壁弹药4倍
			allWeaponData[Game.weaponType.Wall].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.Wall)
			Game.notice.emit(tr("Fake Wall+: Quad Ammo"))
		54: # Claymore+: Double Ammo - 地雷弹药翻倍
			allWeaponData[Game.weaponType.Mine].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Mine)
			Game.notice.emit(tr("Claymore+: Double Ammo"))
		55: # New Weapon: Chargepack - 解锁充电包
			weaponUnlock.append(Game.weaponType.ChargePack)
			Game.notice.emit(tr("New Weapon: Chargepack"))
		56: # Shotgun+: Double Damage - 霰弹枪伤害翻倍
			allWeaponData[Game.weaponType.Shotgun].damage *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Shotgun)
			Game.notice.emit(tr("Shotgun+: Double Damage"))
		57: # Grenade+: Bigger Bang - 手榴弹更大爆炸（未实现）
			pass
		58: # Claymore+: Big Bang - 地雷大爆炸（未实现）
			pass
		59: # Rocket+: Fast Fire - 火箭发射器射速提升
			allWeaponData[Game.weaponType.Rocket].delay = 0.3
			Game.weaponUpgrade.emit(Game.weaponType.Rocket)
			Game.notice.emit(tr("Rocket+: Fast Fire"))
		61: # UZI+: Infinate Range - UZI无限射程（未实现）
			pass
		62: # Claymore+: Bigger Bang - 地雷更大爆炸（未实现）
			pass
		63: # Charge Pack+: Cluster Explode - 充电包分裂爆炸（未实现）
			pass
		64: # Claymore+: Quad Ammo - 地雷弹药4倍
			allWeaponData[Game.weaponType.Mine].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.Mine)
			Game.notice.emit(tr("Claymore+: Quad Ammo"))
		66: # Rocket+: Double Ammo - 火箭发射器弹药翻倍
			allWeaponData[Game.weaponType.Rocket].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Rocket)
			Game.notice.emit(tr("Rocket+: Double Ammo"))
		68: # Charge Pack+: Double Ammo - 充电包弹药翻倍
			allWeaponData[Game.weaponType.ChargePack].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.ChargePack)
			Game.notice.emit(tr("Charge Pack+: Double Ammo"))
		70: # New Weapon: Railgun - 解锁轨道炮
			weaponUnlock.append(Game.weaponType.Railgun)
			Game.notice.emit(tr("New Weapon: Railgun"))
		72: # Rocket+: Big Bang - 火箭大爆炸（未实现）
			pass
		74: # Charge Pack+: Big Bang - 充电包大爆炸（未实现）
			pass
		76: # Charge Pack+: Quad Ammo - 充电包弹药4倍
			allWeaponData[Game.weaponType.ChargePack].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.ChargePack)
			Game.notice.emit(tr("Charge Pack+: Quad Ammo"))
		78: # Railgun+: Fast Fire - 轨道炮射速提升（未实现）
			pass
		80: # Railgun+: Double Ammo - 轨道炮弹药翻倍
			allWeaponData[Game.weaponType.Railgun].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Railgun)
			Game.notice.emit(tr("Railgun+: Double Ammo"))
		85: # Rocket+: Quad Ammo - 火箭发射器弹药4倍
			allWeaponData[Game.weaponType.Rocket].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.Rocket)
			Game.notice.emit(tr("Rocket+: Quad Ammo"))
		90: # UZI+: Quad Damage - UZI伤害4倍
			allWeaponData[Game.weaponType.UZI].damage *= 2
			Game.weaponUpgrade.emit(Game.weaponType.UZI)
			Game.notice.emit(tr("UZI+: Quad Damage"))
		95: # Charge Pack+: Bigger Bang - 充电包更大爆炸（未实现）
			pass
		100: # Railgun+: Rapid Fire - 轨道炮快速射击（未实现）
			pass
		105: # Rocket+: Bigger Bang - 火箭更大爆炸（未实现）
			pass
		110: # Railgun+: Quad Ammo - 轨道炮弹药4倍
			allWeaponData[Game.weaponType.Railgun].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.Railgun)
			Game.notice.emit(tr("Railgun+: Quad Ammo"))
		120: # Rocket+: Rapid Fire - 火箭快速射击（未实现）
			pass
		125: # Railgun+: Long Shot - 轨道炮长射程（未实现）
			pass


## 重置武器数据到初始状态
func resetAllWeaponData():
	allWeaponData = {
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


## 重置地图配置到初始状态
func resetMapConfig():
	mapConfig = {'difficulty': 1, 'collision': true, 'Devils': true, 'friendlyFire': true,
				'gameSpeed': 1}
