extends "res://script/weapon.gd"

var mineObj=preload("res://scene/mine_obj.tscn")


func fire(_v):
	if ammoNum<=0:
		return
	var pos=global_position
	if !MapData.checkHasMapItem(pos):
		var temp=mineObj.instantiate()
		temp.global_position=Vector2(floori(pos.x/MapData.cellSize)*MapData.cellSize,\
				floori(pos.y/MapData.cellSize)*MapData.cellSize)+\
				Vector2(MapData.cellSize/2,MapData.cellSize/2)
		temp.z_index=floori(pos.y/MapData.cellSize)	
		get_tree().root.add_child(temp)
		MapData.addMapItem(pos,temp.get_instance_id())
		sound.play()
		ammoNum-=1
