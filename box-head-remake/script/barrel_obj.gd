extends "res://script/item.gd"


@export var damage=0 #伤害
var explosion=preload("res://scene/explosion.tscn")
#var splitNum=4  #分裂成小爆炸
#var splitRadius=30 #分裂半径
var startExploding=false  #是否被击中爆炸
var splitExplosion=0  #分裂爆炸

func _ready():
	print(global_position)
	print(("type"))
	

func hit(_value):
	if startExploding:
		return
	startExploding=true	
	for i in range(3):  #延迟3帧后爆炸
		await get_tree().physics_frame	
	var temp=explosion.instantiate()
	temp.global_position=global_position
	temp.damage=damage
	get_tree().root.add_child(temp)
	
	

	if splitExplosion>0:
		for i in range(splitExplosion):
			var t=explosion.instantiate()
			t.damage=damage
			t.global_position=global_position+Vector2.RIGHT.rotated(i*((2*PI)/splitExplosion))*15
			get_tree().root.add_child(t)
			for z in range(3):  #延迟3帧后爆炸
				await get_tree().physics_frame	
	
	queue_free()
	

	
		
