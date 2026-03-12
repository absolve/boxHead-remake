extends Node2D

var explosion=preload("res://scene/explosion.tscn")
@onready var ani=$ani

func _ready() -> void:
	var tween= create_tween()
	tween.tween_property(ani, "position:y", -10, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(ani, "position:y", 0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(addExplosion)
	


func addExplosion():
	var temp = explosion.instantiate()
	temp.global_position=  global_position
	get_tree().root.add_child(temp)
	queue_free()
