extends Node2D

var active=false	#是否激活
@export var type:Game.weaponType      #类型
@export var damage=0 #伤害
@export var wRange=0 #射程
@export var delay=.0 #开火延迟
@export var offset=Vector2(40,0)
var ammoNum=0  #当前弹药量
var maxAmmoNum=0  #最大弹药量
var canShoot=false #是否可以射击
var automatic=false #连发
var detecframes=0 #检测是否与物体碰撞
var fireAngle=0

@onready var sound=$sound
@onready var timer=$Timer


func _on_timer_timeout() -> void:
	canShoot=true

func fire(_angle): 
	pass
