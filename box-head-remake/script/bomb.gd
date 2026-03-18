extends Node2D

var explosion=preload("res://scene/explosion.tscn")
@onready var ani=$ani
var vector:Vector2  #方向
var distance=40  #距离

func _ready() -> void:
	var tween= create_tween()
	#tween.tween_property(ani, "position", Vector2(randf_range(-100,100),randf_range(-20, 20)), 1)
	tween.tween_property(self,"position",global_position+vector*distance+
						Vector2(randf_range(-10,10),randf_range(-10,10)),0.6)\
						.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	#tween.tween_property(ani, "position:y", 0, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(addExplosion)
	


func addExplosion():
	var temp = explosion.instantiate()
	temp.global_position= global_position
	print(temp.global_position)
	get_tree().root.add_child(temp)
	queue_free()
