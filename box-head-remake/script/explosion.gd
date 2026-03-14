extends "res://script/item.gd"

@export var damage=0 #伤害
var excludeObj=[]		#排除对象的列表
var collisionMask=1+2  #检测对象默认是玩家和敌人


func _ready() -> void:
	ani.play("default")
	SfxManage.playExplosion()
	await ani.animation_finished
	queue_free()


func _physics_process(_delta: float) -> void:
	
	pass
