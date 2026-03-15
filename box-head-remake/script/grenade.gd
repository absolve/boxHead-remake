extends "res://script/weapon.gd"

var grenadeObj=preload("res://scene/grenade_obj.tscn")


var speedIncrement=0
var speed=50

func _ready():
	
	pass


func fire(_v):
	if ammoNum<=0:
		return
	if canShoot:
		vector=_v
		canShoot=false
		timer.start(delay)	
