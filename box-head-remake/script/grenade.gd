extends "res://script/weapon.gd"

var grenadeObj=preload("res://scene/grenade_obj.tscn")

var speedIncrement=20	#发射速度增加
var speed=60
var maxSpeed=2500
var minSpeed=60
var height=25


func _ready():
	
	pass


func fire(_v):
	if ammoNum<=0:
		return
	#if canShoot:
	ammoNum-=1
	print(_v)
	vector=_v
	#canShoot=false
	#timer.start(delay)	
	var temp=grenadeObj.instantiate()
	temp.vector=vector.normalized()
	temp.speed=speed
	temp.global_position=global_position-Vector2(0,height)
	temp.collision_mask=collisionMask
	temp.ownerId=ownerId
	speed=minSpeed
	get_tree().root.add_child(temp)


func increase():
	speed+=speedIncrement
	speed=min(speed,maxSpeed)
	
