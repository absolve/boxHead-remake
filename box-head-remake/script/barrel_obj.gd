extends "res://script/item.gd"


@export var damage=0 #伤害
var explosion=preload("res://scene/explosion.tscn")
#var splitNum=4  #分裂成小爆炸
#var splitRadius=30 #分裂半径
var startExploding=false

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
	
	queue_free()
	#if splitNum>0:
		#var new=load("res://scene/grenade_obj.tscn")
		#for i in range(splitNum):
			#var b=new.instantiate()
			#b.global_position=global_position
			#b.vector=Vector2(1,0).rotated(i*(2*PI/splitNum))
			#b.height=100
			#b.speed=200
			#get_tree().root.add_child(b)
	
		
