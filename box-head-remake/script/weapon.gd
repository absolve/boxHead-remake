extends Node2D

var active=false	#是否激活
@export var type:Game.weaponType      #类型
@export var damage=0 #伤害
@export var wRange=0 #射程
@export var delay=.0 #开火延迟
var ammoNum=0  #当前弹药量
var maxAmmoNum=0  #最大弹药量
var canShoot=true #是否可以射击
var automatic=false #连发
var detecframes=0 #检测是否与物体碰撞
var vector:Vector2=Vector2.RIGHT
var offsetDir={0:Vector2.ZERO,1:Vector2.ZERO,2:Vector2.ZERO,
				3:Vector2.ZERO,4:Vector2.ZERO,5:Vector2.ZERO,
				6:Vector2.ZERO,7:Vector2.ZERO}


@onready var sound=$sound
@onready var timer=$Timer


func _on_timer_timeout() -> void:
	canShoot=true

func fire(_angle): 
	pass
