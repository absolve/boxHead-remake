extends Node2D

@onready var room=$room001
var font:FontFile

@onready var enemy=$zombie

func _ready() -> void:
	MapData.mapSize=room.mapSize
	MapData.astarGrid.region=Rect2i(0,0,room.mapSize.x,room.mapSize.y)
	MapData.astarGrid.update()
	font = ThemeDB.fallback_font

func loadLevel():
	
	pass

func _physics_process(_delta: float) -> void:
	
	queue_redraw()



func _draw() -> void:
	var width=floor(MapData.mapSize.x/MapData.cellSize)
	var height=floor(MapData.mapSize.y/MapData.cellSize)
	for i in range(width+1):
		draw_line(Vector2(i*MapData.cellSize,0),Vector2(i*MapData.cellSize,MapData.cellSize*height),Color.GRAY,0.5,true)
	for i in range(height+1):
		draw_line(Vector2(0,i*MapData.cellSize),Vector2(MapData.cellSize*width,i*MapData.cellSize),Color.GRAY,0.5,true)
	var x=floor(get_local_mouse_position().x)
	var y=floor(get_local_mouse_position().y)
	draw_string(font,get_local_mouse_position(),"%s-%s"%[x,y], 
	HORIZONTAL_ALIGNMENT_LEFT, -1,16,Color.BLACK)
	draw_string(font,get_local_mouse_position()+Vector2(20,20),"%s-%s"%[floori(x/MapData.cellSize),floori(y/MapData.cellSize)], 
	HORIZONTAL_ALIGNMENT_LEFT, -1,16,Color.BLACK)
	
	if enemy.path.size()>0:
		var _path=enemy.path
		var last_point = _path[0]
		for index in range(1, len(_path)):
			var current_point = _path[index]
			draw_line(last_point, current_point, Color.BLACK, 2, true)
			draw_circle(current_point,  5.0, Color.BLACK)
			last_point = current_point
		
		
