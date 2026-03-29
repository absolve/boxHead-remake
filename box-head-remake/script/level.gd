extends Node2D

var playerSpawnPoint:Array[Vector2]=[]
var zombieSpawnPoint:Array[Vector2]=[]
var devilSpawnPoint:Array[Vector2]=[]
@export var mapSize:Vector2=Vector2(640,480)


func _ready() -> void:
	#RenderingServer.set_default_clear_color('#ebdcc7')
	pass
	
