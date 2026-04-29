extends Node

const cellSize: float = 30 # 每个格子大小

#武器基本参数信息
var allWeaponData = {
	Game.weaponType.Pistol:{'damage':1,'wRange':300,'delay':0.6,'maxAmmoNum':0,'automatic':false},
	Game.weaponType.UZI:{'damage':1,'wRange':400,'delay':0.1,'maxAmmoNum':50,'automatic':true},
	Game.weaponType.Shotgun:{'damage':2,'wRange':300,'delay':0.1,'maxAmmoNum':15,'splitAngle':30,'automatic':false},
	Game.weaponType.Mine:{'damage':4,'wRange':0,'delay':0,'maxAmmoNum':10,'automatic':false},
	Game.weaponType.Wall:{'damage':0,'wRange':0,'delay':0,'maxAmmoNum':10,'automatic':false},
	Game.weaponType.Barrel:{'damage':4,'wRange':0,'delay':0,'maxAmmoNum':10,'automatic':false},
	Game.weaponType.Grenade:{'damage':4,'wRange':0,'delay':1,'maxAmmoNum':15,'automatic':false},
	Game.weaponType.Rocket:{'damage':10,'wRange':0,'delay':1.2,'maxAmmoNum':15,'automatic':false},
	Game.weaponType.Railgun:{'damage':5,'wRange':300,'delay':0.5,'maxAmmoNum':20,'automatic':false},
	Game.weaponType.ChargePack:{'damage':0,'wRange':0,'delay':0,'maxAmmoNum':10,'automatic':false}
}
#敌人基本参数信息
var enemyData={
	Game.roleType.Zombie:{},
	Game.roleType.Devil:{}
}

#地图配置
var mapConfig={'difficulty':1,'collision':true,'Devils':true,'friendlyFire':true,
				'Game speed':1}

var currKillStreak=0  #当前连杀
var killStreak=0  #连杀

var mapSize: Vector2 # 地图大小

#以x-y为key用来快速判断地图上物体位置
var mapTile = {}

var astarGrid: AStarGrid2D = AStarGrid2D.new()

func _ready() -> void:
	astarGrid.cell_size = Vector2(cellSize, cellSize)
	astarGrid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	astarGrid.default_compute_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	astarGrid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	astarGrid.offset = Vector2(cellSize, cellSize) * 0.5


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
func findPath(start: Vector2, end: Vector2):
	var s = Vector2(floori(start.x / cellSize), floori(start.y / cellSize))
	var e = Vector2(floori(end.x / cellSize), floori(end.y / cellSize))
	return astarGrid.get_point_path(s, e)

#重置配置
func resetMapConfig():
	mapConfig={'difficulty':1,'collision':true,'Devils':true,'friendlyFire':true,
				'gameSpeed':1}

#计算连杀数
func countKillStreak():
	match killStreak:
		3: # Pistol+: Fast Fire
			allWeaponData[Game.weaponType.Pistol].delay=0.3
			Game.weaponUpgrade.emit(Game.weaponType.Pistol)
			Game.notice.emit(tr("Pistol+: Fast Fire"))
		5:
			pass
		8:
			pass
		10:
			pass
		13:
			pass
		15:
			pass
		17:
			pass
		18:
			pass
		20:
			pass
		21:
			pass
		23:
			pass
		26:
			pass
		30:
			pass
		31:
			pass
		32:
			pass
		33:
			pass
		35:
			pass
		36:
			pass
		37:
			pass
		39:
			pass
		40:
			pass
		41:
			pass
		42:
			pass
		43:
			pass
		44:
			pass
		45:
			pass	
		47:
			pass	
		48:
			pass
		50:
			pass
		51:
			pass			
		52:
			pass
		53:
			pass
		54:
			pass		
		55:
			pass
		56:
			pass
		57:
			pass
		58:
			pass
		59:
			pass
		61:
			pass
		62:
			pass
		63:
			pass
		64:
			pass
		66:
			pass				
		68:
			pass
		70:
			pass
		72:
			pass
		74:
			pass
		76:
			pass
		78:
			pass
		80:
			pass
		85:
			pass
		90:
			pass								
		95:
			pass
		100:
			pass
		105:
			pass
		110:
			pass	
		120:
			pass			
		125:
			pass


																																	
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
