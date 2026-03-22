extends "res://script/item.gd"

var explosion=preload("res://scene/explosion.tscn")
var splitNum=4  #分裂成小爆炸
var splitRadius=30 #分裂半径

func _ready():
	print(global_position)
	print(("type"))
	

func hit(_value):
	var temp=explosion.instantiate()
	temp.global_position=global_position
	get_tree().root.add_child(temp)
	queue_free()
	if splitNum>0:
		var new=load("res://scene/grenade_obj.tscn")
		for i in range(splitNum):
			var b=new.instantiate()
			b.global_position=global_position
			b.vector=Vector2.RIGHT.rotated(i*(2*PI/splitNum)+0.4)
			b.speed=100
			get_tree().root.add_child(b)
	
		
