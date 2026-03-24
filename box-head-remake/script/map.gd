extends Node2D

@onready var room=$room001

func _ready() -> void:
	MapData.mapSize=room.mapSize


func loadLevel():
	
	pass

func _draw() -> void:
	var width=floor(MapData.mapSize.x/MapData.cellSize)
	var height=floor(MapData.mapSize.y/MapData.cellSize)
	for i in range(width+1):
		draw_line(Vector2(i*MapData.cellSize,0),Vector2(i*MapData.cellSize,MapData.cellSize*height),Color.GRAY,0.5,true)
	for i in range(height+1):
		draw_line(Vector2(0,i*MapData.cellSize),Vector2(MapData.cellSize*width,i*MapData.cellSize),Color.GRAY,0.5,true)
