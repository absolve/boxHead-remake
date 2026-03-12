extends "res://script/item.gd"

var explosion=preload("res://scene/explosion.tscn")

func _ready():
	print(global_position)
	print(("type"))
	

func hit(_value):
	var temp=explosion.instantiate()
	temp.global_position=global_position
	get_tree().root.add_child(temp)
	queue_free()
