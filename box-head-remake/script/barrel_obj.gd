extends "res://script/item.gd"



func _ready():
	print(global_position)
	print(collision_layer)

func hit(_value):
	queue_free()
	
	pass
