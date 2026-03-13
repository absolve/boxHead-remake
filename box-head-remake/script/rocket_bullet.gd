extends "res://script/item.gd"

var smoke=preload("res://scene/smoke.tscn")
var ownerId=null
var vector=Vector2.ZERO
var speed=300


func  _ready() -> void:
	ani.play("default")
	var tween=create_tween()
	tween.set_loops()
	tween.tween_interval(0.2)
	tween.tween_callback(addSmoke)
	

func addSmoke():
	var temp=smoke.instantiate()
	temp.global_position=global_position
	get_tree().root.add_child(temp)
	
	
	
