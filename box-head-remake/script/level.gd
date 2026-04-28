extends Node2D

var playerSpawnPoint:Array[Vector2]=[]  #玩家出生点
var zombieSpawnPoint:Array[Vector2]=[]  #僵尸出生点
var devilSpawnPoint:Array[Vector2]=[]	#恶魔出生点
var itemSpawnPoint:Array[Vector2]=[] #物品刷新点
@export var mapSize:Vector2=Vector2(640,480)
@export var debug=false


func _ready() -> void:
	#RenderingServer.set_default_clear_color('#ebdcc7')
	pass
	


	
func _draw() -> void:
	var width = floor(MapData.mapSize.x / MapData.cellSize)
	var height = floor(MapData.mapSize.y / MapData.cellSize)
	for i in range(width + 1):
		draw_line(Vector2(i * MapData.cellSize, 0), Vector2(i * MapData.cellSize, MapData.cellSize * height), Color.GRAY, 0.5, true)
	for i in range(height + 1):
		draw_line(Vector2(0, i * MapData.cellSize), Vector2(MapData.cellSize * width, i * MapData.cellSize), Color.GRAY, 0.5, true)
