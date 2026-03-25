extends "res://script/character.gd"


@onready var ani=$ani
var target=null
var attackRange=35 #攻击范围


func _ready():
	state=Game.enemyState.Idle
	
	pass

func _physics_process(_delta: float) -> void:
	if state==Game.enemyState.Idle:
		velocity=Vector2.ZERO
		target=findTarget()
	
			

		var dir= global_position.direction_to(target.global_position)
		#print(dir)
		if abs(dir.x)>=abs(dir.y)*1.5:
			velocity=Vector2(sign(dir.x), 0)
		elif abs(dir.y)>=abs(dir.x)*1.5:
			velocity=Vector2(0,sign(dir.y))
		#else:
			#velocity=Vector2(sign(dir.x), sign(dir.y))
		
		var dis=global_position.distance_to(target.global_position)
		if dis<attackRange:
			velocity=Vector2.ZERO
			
		if velocity.length()>0:
			currAni="walk"
		else:
			currAni="stand"
		if 	velocity.length()!=0:
			angle = wrapi(int(velocity.angle() / (PI/4)), 0, 8)
		velocity*=speed
		ani.play(currAni+"_%s"%angle)
		move_and_collide(velocity*_delta)
		
	z_index=floori(global_position.y/MapData.cellSize)+1
	
#寻找目标
func findTarget():
	var nodes=get_tree().get_nodes_in_group("player")
	if nodes.size()>0:
		var minDistance=INF
		var nearestEnemy=null 
		for i in nodes:
			var dis=global_position.distance_to(i.global_position)
			if dis<minDistance:
				minDistance=dis
				nearestEnemy=i
		return nearestEnemy		
	else:
		return null	
