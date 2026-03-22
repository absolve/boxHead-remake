extends Node

const cellSize:float=40 #每个格子大小

var allWeaponData={
	
}

var mapSize:Vector2  #地图大小

#以x-y为key用来快速判断地图上物体位置
var mapTile={}


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
