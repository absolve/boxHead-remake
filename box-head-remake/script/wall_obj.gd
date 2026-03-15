extends "res://script/item.gd"

var hp=10
var smoke=preload("res://scene/smoke.tscn")

func hit(_value):
	hp-=_value
	if hp<=0:
		var temp=smoke.instantiate()
		temp.global_position=global_position
		get_tree().root.add_child(temp)
		queue_free()
	ani.frame=wrapi(10-hp,0,10)
	
