extends Node2D

var playerSpawnPoint:Array=[]  #玩家出生点
var zombieSpawnPoint:Array=[]  #僵尸出生点
var devilSpawnPoint:Array=[]	#恶魔出生点
var itemSpawnPoint:Array=[] #物品刷新点
@export var mapSize:Vector2=Vector2(640,480)
@export var debug=false


func _ready() -> void:
	#RenderingServer.set_default_clear_color('#ebdcc7')
	pass
	


	
func _draw() -> void:
	var width = floori(MapData.mapSize.x / MapData.cellSize)
	var height = floori(MapData.mapSize.y / MapData.cellSize)
	for i in range(width + 1):
		draw_line(Vector2(i * MapData.cellSize, 0), Vector2(i * MapData.cellSize, MapData.cellSize * height), Color.WHITE, 1, true)
	for i in range(height + 1):
		draw_line(Vector2(0, i * MapData.cellSize), Vector2(MapData.cellSize * width, i * MapData.cellSize), Color.WHITE, 1, true)
