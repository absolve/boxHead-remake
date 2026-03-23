extends Node2D

@onready var room=$room001

func _ready() -> void:
	MapData.mapSize=room.mapSize


func loadLevel():
	
	pass

func _draw() -> void:
	for i in range(27):
		draw_line(Vector2(i*MapData.cellSize,0),Vector2(i*MapData.cellSize,MapData.cellSize*26),Color.GRAY,0.5,true)
	for i in range(27):
		draw_line(Vector2(0,i*MapData.cellSize),Vector2(MapData.cellSize*26,i*MapData.cellSize),Color.GRAY,0.5,true)
