extends "res://script/item.gd"

@export var damage=0 #伤害
var explosionType=Game.explosionType.normal
var excludeObj=[]		#排除对象的列表
#var collisionMask=4+16+32  #检测对象默认是玩家和敌人


func _ready() -> void:
	if explosionType==Game.explosionType.normal:
		ani.play("0")
	elif explosionType==Game.explosionType.air:
		ani.play("1")
	SfxManage.playExplosion()
	await ani.animation_finished
	queue_free()


func _physics_process(_delta: float) -> void:
	var r=get_overlapping_areas()
	if r:
		for i in r:
			if i.get("type") && i.type in [Game.itemType.Barrel,
								Game.itemType.Wall]:
				if !excludeObj.has(i.get_rid()):
					i.hit(damage)	
					excludeObj.append(i.get_rid())
			elif i.owner.type&&i.owner.type in [Game.roleType.Player,
				Game.roleType.Zombie,Game.roleType.Devil]:
				if !excludeObj.has(i.get_rid()):
					i.owner.hit(damage,global_position,0)
					excludeObj.append(i.get_rid())	
	
