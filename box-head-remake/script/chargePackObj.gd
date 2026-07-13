extends "res://script/item.gd"


@onready var sound = $sound
@export var damage = 0 # 伤害

var delay = 1
var tween: Tween = null
# var playerId=1
var splitExplosion = 0 # 分裂成小爆炸
var splitRadius = 30 # 分裂半径

var explosion = preload("res://scene/explosion.tscn")
var grenadeObj = preload("res://scene/grenade_obj.tscn")

func _ready() -> void:
	Game.weaponUpgrade.connect(weaponUpgrade)

func weaponUpgrade(_type):
	if _type == Game.weaponType.ChargePack:
		splitExplosion= MapData.allWeaponData._type['splitExplosion']
		damage= MapData.allWeaponData.type['damage']
		

#添加爆炸
func addExplosion():
	var temp = explosion.instantiate()
	temp.global_position = global_position
	temp.damage = damage
	get_tree().root.add_child(temp)
	#　如果分裂成多个小炸弹
	if splitExplosion > 0:
		for i in range(splitExplosion):
			var t = grenadeObj.instantiate()
			t.global_position = global_position-Vector2(0, 32)
			t.damage = damage
			var angle = Vector2.RIGHT.rotated(2*PI/splitExplosion *i)
			t.vector = angle.normalized()
			t.speed = 50
			get_tree().root.add_child(t)
	queue_free()
