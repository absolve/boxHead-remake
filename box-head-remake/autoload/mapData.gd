extends Node

const cellSize:float=30 #每个格子大小

var allWeaponData={
	
}

var mapSize:Vector2  #地图大小

#以x-y为key用来快速判断地图上物体位置
var mapTile={}

var astarGrid:AStarGrid2D= AStarGrid2D.new()

func _ready() -> void:
	astarGrid.cell_size=Vector2(cellSize,cellSize)
	astarGrid.default_estimate_heuristic=AStarGrid2D.HEURISTIC_CHEBYSHEV 
	astarGrid.default_compute_heuristic=AStarGrid2D.HEURISTIC_CHEBYSHEV 
	astarGrid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ALWAYS
	astarGrid.offset = Vector2(cellSize,cellSize) * 0.5


func clearMapTile():
	pass


func checkHasMapItem(pos:Vector2):
	print(pos)
	var x=floori(pos.x/cellSize) 
	var y= floori(pos.y/cellSize) 
	print(x,'-',y)
	var flag=false
	if mapTile.has("%s-%s"%[x,y]):
		var temp=mapTile["%s-%s"%[x,y]]
		print(temp)
		if is_instance_id_valid(temp):
			flag=true
	return flag

func addMapItem(pos:Vector2,id:int):
	var x=floori(pos.x/cellSize) 
	var y= floori(pos.y/cellSize) 
	mapTile["%s-%s"%[x,y]]=id

#查找路径
func findPath(start:Vector2,end:Vector2):
	var s=Vector2(floori(start.x/cellSize),floori(start.y/cellSize))
	var e=Vector2(floori(end.x/cellSize),floori(end.y/cellSize))
	return	astarGrid.get_point_path(s,e)


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
