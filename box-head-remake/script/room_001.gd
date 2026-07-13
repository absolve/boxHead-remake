extends "res://script/level.gd"



func _ready() -> void:
	var nodes=get_tree().get_nodes_in_group("sign")	
	#print(nodes)
	for i in nodes:
		if i.type==Game.mapSign.Zombie:
			zombieSpawnPoint.append(i)
		elif i.type==Game.mapSign.Devil:
			devilSpawnPoint.append(i)
		elif i.type==Game.mapSign.Player:
			playerSpawnPoint.append(i)
		elif i.type==Game.mapSign.Box:
			itemSpawnPoint.append(i)
	MapData.mapSize = mapSize
	MapData.clearObstacle()
	for i in range(9):
		for y in range(2):
			MapData.addObstacle(Vector2(i,y))
			
	for i in range(11,20):
		for y in range(2):	
			MapData.addObstacle(Vector2(i,y))		
	queue_redraw()


#func _draw() -> void:
	#var width = floor(MapData.mapSize.x / MapData.cellSize)
	#var height = floor(MapData.mapSize.y / MapData.cellSize)
	#for i in range(width + 1):
		#draw_line(Vector2(i * MapData.cellSize, 0), Vector2(i * MapData.cellSize, MapData.cellSize * height), Color.GRAY, 1, true)
	#for i in range(height + 1):
		#draw_line(Vector2(0, i * MapData.cellSize), Vector2(MapData.cellSize * width, i * MapData.cellSize), Color.GRAY, 1, true)
	#draw_rect(Rect2(0,0,100,100),Color.WHITE)
