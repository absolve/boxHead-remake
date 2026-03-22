extends "res://script/item.gd"

@export var damage=0 #伤害
var explosionType=Game.explosionType.normal
var excludeObj=[]		#排除对象的列表
var collisionMask=1+2  #检测对象默认是玩家和敌人


func _ready() -> void:
	if explosionType==Game.explosionType.normal:
		ani.play("0")
	elif explosionType==Game.explosionType.air:
		ani.play("1")
	SfxManage.playExplosion()
	await ani.animation_finished
	queue_free()


func _physics_process(_delta: float) -> void:
	
	pass
