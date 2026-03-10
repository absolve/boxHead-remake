extends "res://script/weapon.gd"

@onready var ani=$ani
@onready var player=$player

var bulletNum=4

func _ready():
	offsetDir[0]=Vector2(45,3)
	offsetDir[1]=Vector2(20,20)
	offsetDir[2]=Vector2(-10,20)
	offsetDir[3]=Vector2(-38,10)
	offsetDir[4]=Vector2(-40,-20)
	offsetDir[5]=Vector2(-18,-45)
	offsetDir[6]=Vector2(20,-40)
	offsetDir[7]=Vector2(40,-20)


func fire(v):
	if canShoot:
		print('shoot')


func _draw() -> void:
	if detecframes>0:
		pass
