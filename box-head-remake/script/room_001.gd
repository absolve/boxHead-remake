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
		elif i.type==Game.mapSign.Item:
			itemSpawnPoint.append(i)
