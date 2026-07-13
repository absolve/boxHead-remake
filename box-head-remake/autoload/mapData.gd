extends Node

const cellSize: float = 32 # 每个格子大小

#武器基本参数信息
var allWeaponData = {
	Game.weaponType.Pistol: {'damage': 1, 'wRange': 300, 'delay': 0.6, 'maxAmmoNum': 0, 'automatic': false},
	Game.weaponType.UZI: {'damage': 1, 'wRange': 400, 'delay': 0.1, 'maxAmmoNum': 100, 'automatic': true},
	Game.weaponType.Shotgun: {'damage': 2, 'wRange': 300, 'delay': 0.1, 'maxAmmoNum': 20, 'splitAngle': 30, 'automatic': false},
	Game.weaponType.Mine: {'damage': 4, 'wRange': 0, 'delay': 0, 'maxAmmoNum': 10, 'splitExplosion': 0, 'automatic': false},
	Game.weaponType.Wall: {'damage': 0, 'wRange': 0, 'delay': 0, 'maxAmmoNum': 5, 'automatic': false},
	Game.weaponType.Barrel: {'damage': 4, 'wRange': 0, 'delay': 0, 'maxAmmoNum': 10, 'splitExplosion': 0, 'automatic': false},
	Game.weaponType.Grenade: {'damage': 4, 'wRange': 0, 'delay': 1, 'maxAmmoNum': 20, 'automatic': false},
	Game.weaponType.Rocket: {'damage': 5, 'wRange': 0, 'delay': 1.2, 'maxAmmoNum': 20, 'automatic': false},
	Game.weaponType.Railgun: {'damage': 4, 'wRange': 300, 'delay': 0.5, 'maxAmmoNum': 15, 'automatic': false},
	Game.weaponType.ChargePack: {'damage': 0, 'wRange': 0, 'delay': 0, 'maxAmmoNum': 10, 'automatic': false}
}

#敌人基本参数信息
var enemyData = {
	Game.roleType.Zombie: {'speed': 20},
	Game.roleType.Devil: {'speed': 30}
}

#地图配置
var mapConfig = {'difficulty': 1, 'collision': true, 'Devils': true, 'friendlyFire': true,
				'Game speed': 1}

#当前连杀
var currKillStreak = 0
var killStreak = 0 # 连杀
var score = 0 # 分数

var weaponUnlock = [] # 武器解锁

var mapSize: Vector2 # 地图大小

#以x-y为key用来快速判断地图上物体位置
var mapTile = {}

# CAUTION 流场方向 key是x-y  value为方向
#var flowFieldDir={}
# CAUTION 流场方向 key是x-y  value为距目标点的距离
#var flowFieldDistance={}
# CAUTION 目标
#var targets=[]

#障碍物 key 为x-y value为格子坐标
var obstacle: Dictionary = {}
#流场编号 key为id  value 为流场方向
var flowFieldDict = {}

#var astarGrid: AStarGrid2D = AStarGrid2D.new()

func _ready() -> void:
	#astarGrid.cell_size = Vector2(cellSize, cellSize)
	#astarGrid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	#astarGrid.default_compute_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	#astarGrid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	#astarGrid.offset = Vector2(cellSize, cellSize) * 0.5
	pass

#计算流场  id为玩家id 个玩家生成一个单独的流场
func computeFields(id, _target: Vector2 = Vector2.INF):
	var distanceField = {}
	var cellX = int(mapSize.x / cellSize)
	var cellY = int(mapSize.y / cellSize)
	#初始化每个格子的距离
	for x in range(cellX):
		for y in range(cellY):
			distanceField["%s-%s" % [x, y]] = INF
	# 8方向搜索
	var dirs = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),
		Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]
	distanceField["%s-%s" % [int(_target.x), int(_target.y)]] = 0 # 目标点距离为0
	var t: Array[Vector2] = []
	t.append(_target)
	while t.size() > 0:
		var p = t.pop_front()
		for i in dirs: # 获取邻居格子
			var pos: Vector2 = p + i
			if pos.x < 0 || pos.y < 0 || pos.x >= cellX || pos.y >= cellY:
				continue
			if obstacle.has("%s-%s" % [int(pos.x), int(pos.y)]):
				continue
			if distanceField["%s-%s" % [int(pos.x), int(pos.y)]] == INF:
				distanceField["%s-%s" % [int(pos.x), int(pos.y)]] = distanceField["%s-%s" % [int(p.x), int(p.y)]] + 1
				if i.x != 0 || i.y != 0: # 对角线加0.5
					distanceField["%s-%s" % [int(pos.x), int(pos.y)]] += 0.5
				t.append(pos)
				
	#计算流场方向
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
			#根据id 设置流场方向
			if flowFieldDict.has(id):
				flowFieldDict[id]["%s-%s" % [int(pos.x), int(pos.y)]] = bestDir
			else:
				flowFieldDict[id] = {}
				
				
#获取流场方向 
func getFlowDir(pos: Vector2, id):
	var x = floori(pos.x / cellSize)
	var y = floori(pos.y / cellSize)
	if flowFieldDict.has(id) && flowFieldDict[id].has("%s-%s" % [x, y]):
		return flowFieldDict[id]["%s-%s" % [x, y]]
	else:
		return Vector2.ZERO

#添加障碍物
func addObstacle(pos: Vector2):
	if !obstacle.has("%s-%s" % [int(pos.x), int(pos.y)]):
		obstacle["%s-%s" % [int(pos.x), int(pos.y)]] = pos


func clearObstacle():
	obstacle.clear()

func clearMapTile():
	pass


func checkHasMapItem(pos: Vector2):
	print(pos)
	var x = floori(pos.x / cellSize)
	var y = floori(pos.y / cellSize)
	print(x, '-', y)
	var flag = false
	if mapTile.has("%s-%s" % [x, y]):
		var temp = mapTile["%s-%s" % [x, y]]
		print(temp)
		if is_instance_id_valid(temp):
			flag = true
	return flag

func addMapItem(pos: Vector2, id: int):
	var x = floori(pos.x / cellSize)
	var y = floori(pos.y / cellSize)
	mapTile["%s-%s" % [x, y]] = id

## 查找路径
#func findPath(start: Vector2, end: Vector2):
	#var s = Vector2(floori(start.x / cellSize), floori(start.y / cellSize))
	#var e = Vector2(floori(end.x / cellSize), floori(end.y / cellSize))
	#return astarGrid.get_point_path(s, e)

#重置配置
func resetMapConfig():
	mapConfig = {'difficulty': 1, 'collision': true, 'Devils': true, 'friendlyFire': true,
				'gameSpeed': 1}

func addKillStreak(val):
	currKillStreak += val
	if currKillStreak > killStreak:
		killStreak = currKillStreak
		countKillStreak()

#计算连杀数
func countKillStreak():
	match killStreak:
		3: # Pistol+: Fast Fire
			allWeaponData[Game.weaponType.Pistol].delay = 0.3
			Game.weaponUpgrade.emit(Game.weaponType.Pistol)
			Game.notice.emit(tr("Pistol+: Fast Fire"))
		5: # New Weapon: UZI (Key 2)
			weaponUnlock.append(Game.weaponType.UZI)
			Game.notice.emit(tr("New Weapon: UZI"))
		8: # Pistol+: Double Damage
			allWeaponData[Game.weaponType.Pistol].damage *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Pistol)
			Game.notice.emit(tr("Pistol+: Double Damage"))
		10: # New Weapon: Shotgun
			weaponUnlock.append(Game.weaponType.UZI)
			Game.notice.emit(tr("New Weapon: Shotgun"))
		13: # UZI+: Rapid Fire
			allWeaponData[Game.weaponType.Pistol].delay = 0.1
			Game.weaponUpgrade.emit(Game.weaponType.UZI)
			Game.notice.emit(tr("UZI+: Rapid Fire"))
		15: # New Wepon: Barrel
			weaponUnlock.append(Game.weaponType.Barrel)
			Game.notice.emit(tr("New Wepon: Barrel"))
		17: # UZI+: Double Ammo
			allWeaponData[Game.weaponType.UZI].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.UZI)
			Game.notice.emit(tr("UZI+: Double Ammo"))
		18: # Shotgun+: Fast Fire
			allWeaponData[Game.weaponType.Shotgun].delay = 0.3
			allWeaponData[Game.weaponType.Shotgun].automatic = true
			Game.weaponUpgrade.emit(Game.weaponType.Shotgun)
			Game.notice.emit(tr("Shotgun+: Fast Fire"))
		20: # New Weapon: Grenade
			weaponUnlock.append(Game.weaponType.Grenade)
			Game.notice.emit(tr("New Weapon: Grenade"))
		21: # Shotgun+: Double Ammo
			allWeaponData[Game.weaponType.Shotgun].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Shotgun)
			Game.notice.emit(tr("Shotgun+: Double Ammo"))
		23: # UZI+: Long Shot
			allWeaponData[Game.weaponType.UZI].wRange *= 2
			Game.weaponUpgrade.emit(Game.weaponType.UZI)
			Game.notice.emit(tr("UZI+: Long Shot"))
		26: # Barrel+: Double Ammo
			allWeaponData[Game.weaponType.Barrel].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Barrel)
			Game.notice.emit(tr("Barrel+: Double Ammo"))
		30: # New Weapon: Fake walls
			weaponUnlock.append(Game.weaponType.Wall)
			Game.notice.emit(tr("New Weapon: Fake walls"))
		31: # Shotgun+: Wide Shot
			allWeaponData[Game.weaponType.Shotgun].splitAngle *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Shotgun)
			Game.notice.emit(tr("Shotgun+: Wide Shot"))
		32: # Barrel+: Big Bang
			pass
		33: # Grenade+: Cluster Explode
			pass
		35: # Shotgun+: Long Shot
			allWeaponData[Game.weaponType.Shotgun].wRange = 600
			Game.weaponUpgrade.emit(Game.weaponType.Shotgun)
			Game.notice.emit(tr("Shotgun+: Long Shot"))
		36: # Barrel+: Quad Ammo
			allWeaponData[Game.weaponType.Barrel].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.Barrel)
			Game.notice.emit(tr("Barrel+: Quad Ammo"))
		37: # Fake Wall+: Double Ammo
			allWeaponData[Game.weaponType.Wall].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Wall)
			Game.notice.emit(tr("Fake Wall+: Double Ammo"))
		39: # UZI+: Quad Ammo
			allWeaponData[Game.weaponType.UZI].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.UZI)
			Game.notice.emit(tr("UZI+: Quad Ammo"))
		40: # New Weapon: Claymore
			weaponUnlock.append(Game.weaponType.Mine)
			Game.notice.emit(tr("New Weapon: Claymore"))
		41: # Shotgun+: Quad Ammo
			allWeaponData[Game.weaponType.Shotgun].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.Shotgun)
			Game.notice.emit(tr("Shotgun+: Quad Ammo"))
		42: # Grenade+: Double Ammo
			allWeaponData[Game.weaponType.Grenade].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Grenade)
			Game.notice.emit(tr("Grenade+: Double Ammo"))
		43: # Shotgun+: Rapid Fire
			allWeaponData[Game.weaponType.Shotgun].delay = 0.3
			Game.weaponUpgrade.emit(Game.weaponType.Shotgun)
			Game.notice.emit(tr("Shotgun+: Rapid Fire"))
		44: # Barrel+: Bigger Bang
			pass
		45: # Grenade+: Big Bang
			pass
		47: # Claymore+: Cluster Explode
			pass
		48: # UZI+: Double Damager
			allWeaponData[Game.weaponType.UZI].damage *= 2
			Game.weaponUpgrade.emit(Game.weaponType.UZI)
			Game.notice.emit(tr("UZI+: Double Damager"))
		50: # New Weapon: Rocket
			weaponUnlock.append(Game.weaponType.Rocket)
			Game.notice.emit(tr("New Weapon: Rocket"))
		51: # Shotgun+: Wider Shot
			pass
		52: # Grenade+: Quad Ammo
			allWeaponData[Game.weaponType.Grenade].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.Grenade)
			Game.notice.emit(tr("Grenade+: Quad Ammo"))
		53: # Fake Wall+: Quad Ammo
			allWeaponData[Game.weaponType.Wall].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.Wall)
			Game.notice.emit(tr("Fake Wall+: Quad Ammo"))
		54: # Claymore+: Double Ammo
			allWeaponData[Game.weaponType.Mine].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Mine)
			Game.notice.emit(tr("Claymore+: Double Ammo"))
		55: # New Weapon: Chargepack
			weaponUnlock.append(Game.weaponType.ChargePack)
			Game.notice.emit(tr("New Weapon: Chargepack"))
		56: # Shotgun+: Double Damage
			allWeaponData[Game.weaponType.Shotgun].damage *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Shotgun)
			Game.notice.emit(tr("Shotgun+: Double Damage"))
		57: # Grenade+: Bigger Bang
			pass
		58: # Claymore+: Big Bang
			pass
		59: # Rocket+: Fast Fire
			allWeaponData[Game.weaponType.Rocket].delay = 0.3
			Game.weaponUpgrade.emit(Game.weaponType.Rocket)
			Game.notice.emit(tr("Rocket+: Fast Fire"))
		61: # UZI+: Infinate Range
			pass
		62: # Claymore+: Bigger Bang
			pass
		63: # Charge Pack+: Cluster Explode
			pass
		64: # Claymore+: Quad Ammo
			allWeaponData[Game.weaponType.Mine].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.Mine)
			Game.notice.emit(tr("Claymore+: Quad Ammo"))
		66: # Rocket+: Double Ammo
			allWeaponData[Game.weaponType.Rocket].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Rocket)
			Game.notice.emit(tr("Rocket+: Double Ammo"))
		68: # Charge Pack+: Double Ammo
			allWeaponData[Game.weaponType.ChargePack].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.ChargePack)
			Game.notice.emit(tr("Charge Pack+: Double Ammo"))
		70: # New Weapon: Railgun
			weaponUnlock.append(Game.weaponType.Railgun)
			Game.notice.emit(tr("New Weapon: Railgun"))
		72: # Rocket+: Big Bang
			pass
		74: # Charge Pack+: Big Bang
			pass
		76: # Charge Pack+: Quad Ammo
			allWeaponData[Game.weaponType.ChargePack].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.ChargePack)
			Game.notice.emit(tr("Charge Pack+: Quad Ammo"))
		78: # Railgun+: Fast Fire
			pass
		80: # Railgun+: Double Ammo
			allWeaponData[Game.weaponType.Railgun].maxAmmoNum *= 2
			Game.weaponUpgrade.emit(Game.weaponType.Railgun)
			Game.notice.emit(tr("Railgun+: Double Ammo"))
		85: # Rocket+: Quad Ammo
			allWeaponData[Game.weaponType.Rocket].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.Rocket)
			Game.notice.emit(tr("Rocket+: Quad Ammo"))
		90: # UZI+: Quad Damage
			allWeaponData[Game.weaponType.UZI].damage *= 2
			Game.weaponUpgrade.emit(Game.weaponType.UZI)
			Game.notice.emit(tr("UZI+: Quad Damage"))
		95: # Charge Pack+: Bigger Bang
			pass
		100: # Railgun+: Rapid Fire
			pass
		105: # Rocket+: Bigger Bang
			pass
		110: # Railgun+: Quad Ammo
			allWeaponData[Game.weaponType.Railgun].maxAmmoNum *= 4
			Game.weaponUpgrade.emit(Game.weaponType.Railgun)
			Game.notice.emit(tr("Railgun+: Quad Ammo"))
		120: # Rocket+: Rapid Fire
			pass
		125: # Railgun+: Long Shot
			pass

#重置武器数据
func resetAllWeaponData():
	allWeaponData = {
		Game.weaponType.Pistol: {'damage': 1, 'wRange': 300, 'delay': 0.6, 'maxAmmoNum': 0, 'automatic': false},
		Game.weaponType.UZI: {'damage': 1, 'wRange': 400, 'delay': 0.1, 'maxAmmoNum': 100, 'automatic': true},
		Game.weaponType.Shotgun: {'damage': 2, 'wRange': 300, 'delay': 0.1, 'maxAmmoNum': 20, 'splitAngle': 30, 'automatic': false},
		Game.weaponType.Mine: {'damage': 4, 'wRange': 0, 'delay': 0, 'maxAmmoNum': 10, 'splitExplosion': 0, 'automatic': false},
		Game.weaponType.Wall: {'damage': 0, 'wRange': 0, 'delay': 0, 'maxAmmoNum': 5, 'automatic': false},
		Game.weaponType.Barrel: {'damage': 4, 'wRange': 0, 'delay': 0, 'maxAmmoNum': 10, 'splitExplosion': 0, 'automatic': false},
		Game.weaponType.Grenade: {'damage': 4, 'wRange': 0, 'delay': 1, 'maxAmmoNum': 20, 'automatic': false},
		Game.weaponType.Rocket: {'damage': 5, 'wRange': 0, 'delay': 1.2, 'maxAmmoNum': 20, 'automatic': false},
		Game.weaponType.Railgun: {'damage': 4, 'wRange': 300, 'delay': 0.5, 'maxAmmoNum': 15, 'automatic': false},
		Game.weaponType.ChargePack: {'damage': 0, 'wRange': 0, 'delay': 0, 'maxAmmoNum': 10, 'automatic': false}
	}


'''
3	Pistol+: Fast Fire
5	New Weapon: UZI (Key 2)
8	Pistol+: Double Damage
10	New Weapon: Shotgun (Key 3)
13	UZI+: Rapid Fire
15	New Wepon: Barrel (Key 4)
17	UZI+: Double Ammo
18	Shotgun+: Fast Fire
20	New Weapon: Grenade (Key 5)
21	Shotgun+: Double Ammo
23	UZI+: Long Shot
26	Barrel+: Double Ammo
30	New Weapon: Fake walls (Key 6)
31	Shotgun+: Wide Shot
32	Barrel+: Big Bang
33	Grenade+: Cluster Explode
35	Shotgun+: Long Shot
36	Barrel+: Quad Ammo
37	Fake Wall+: Double Ammo
39	UZI+: Quad Ammo
40	New Weapon: Claymore (Key 7)
41	Shotgun+: Quad Ammo
42	Grenade+: Double Ammo
43	Shotgun+: Rapid Fire
44	Barrel+: Bigger Bang
45	Grenade+: Big Bang
47	Claymore+: Cluster Explode
48	UZI+: Double Damager
50	New Weapon: Rocket (Key 8)
51	Shotgun+: Wider Shot
52	Grenade+: Quad Ammo
53	Fake Wall+: Quad Ammo
54	Claymore+: Double Ammo
55	New Weapon: Chargepack (Key 9)
56	Shotgun+: Double Damage
57	Grenade+: Bigger Bang
58	Claymore+: Big Bang
59	Rocket+: Fast Fire
61	UZI+: Infinate Range
62	Claymore+: Bigger Bang
63	Charge Pack+: Cluster Explode
64	Claymore+: Quad Ammo
66	Rocket+: Double Ammo
68	Charge Pack+: Double Ammo
70	New Weapon: Railgun (Key 0)
72	Rocket+: Big Bang
74	Charge Pack+: Big Bang
76	Charge Pack+: Quad Ammo
78	Railgun+: Fast Fire
80	Railgun+: Double Ammo
85	Rocket+: Quad Ammo
90	UZI+: Quad Damage
95	Charge Pack+: Bigger Bang
100	Railgun+: Rapid Fire
105	Rocket+: Bigger Bang
110	Railgun+: Quad Ammo
120	Rocket+: Rapid Fire
125	Railgun+: Long Shot
'''
