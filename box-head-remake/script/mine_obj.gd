extends "res://script/item.gd"

var  delay=1
var tween:Tween=null

@onready var sound=$sound
@export var damage=0 #伤害
var splitNum=0  #分裂成小爆炸
var splitRadius=80 #分裂半径

func _ready() -> void:
	pass


func _on_body_entered(_body: Node2D) -> void:
	if tween==null:
		sound.play()
		tween=create_tween()
		tween.tween_property(ani,"speed_scale",4,0)
		tween.tween_interval(delay)
		tween.tween_callback(queue_free)
