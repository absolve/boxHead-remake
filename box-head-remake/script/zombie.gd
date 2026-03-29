extends "res://script/character.gd"


@onready var ani=$ani
@onready var body=$body
@onready var bodyShape=$body/bodyShape

var font:FontFile


var target=null
var targetOldPos=Vector2.ZERO
var attackRange=35 #攻击范围
var path=[]  #路径点
var targetPos=null
var pathUpdateInterval=0.5
var pathTimer=0
var pathPointIndex =0
var oldAngle=0 #之前的角度
var tween:Tween=null
var hurtTimer=0
var hurtDelay=0.5


func _ready():
	state=Game.enemyState.Idle
	font=load("res://font/AlibabaPuHuiTi-3-85-Bold.ttf")
	#font = ThemeDB.fallback_font
	print(Vector2.LEFT.angle())
	
	
func _physics_process(_delta: float) -> void:
	if state==Game.enemyState.Idle:
		#velocity=Vector2.ZERO
		pathTimer+=_delta
		if pathTimer>pathUpdateInterval:
			target=findTarget()
			if target:
				if targetOldPos!=target.global_position:
					targetOldPos=target.global_position
					path=MapData.findPath(global_position,target.global_position)
					if path.size()>0:
						pathPointIndex=1
					#print(path)
			else:
				path=[]
			pathTimer=0
	
		if path.size()>0:
			if pathPointIndex<path.size():
				targetPos=path[pathPointIndex]
				velocity=(targetPos-global_position).normalized()
				
				if global_position.distance_to(targetPos)<1:
					pathPointIndex+=1	
					print(pathPointIndex)
				
			else:
				velocity=Vector2.ZERO
		else:
			velocity=Vector2.ZERO
		
		#var dir= global_position.direction_to(target.global_position)
		#if abs(dir.x)>=abs(dir.y)*1.5:
			#velocity=Vector2(sign(dir.x), 0)
		#elif abs(dir.y)>=abs(dir.x)*1.5:
			#velocity=Vector2(0,sign(dir.y))
		#else:
			#velocity=Vector2(sign(dir.x), sign(dir.y))
			
		if target!=null:
			var dis=global_position.distance_to(target.global_position)
			if dis<attackRange:
				velocity=Vector2.ZERO
			
		if velocity.length()>0:
			currAni="walk"
		else:
			currAni="stand"
		
		if 	velocity.length()!=0:
			#print(velocity.angle())
			angle = round(velocity.angle() / (PI/4)) 
			angle = wrapi(int(angle), 0, 8)
			if angle!=oldAngle:
				velocity=Vector2.ZERO
				playRotateAni(angle)
			oldAngle=angle
		
		if tween==null ||!tween.is_running():	
			velocity*=speed
			ani.play(currAni+"_%s"%angle)
		move_and_collide(velocity*_delta)
	elif state==Game.enemyState.dead:
		pass
	elif state==Game.enemyState.hurt:
		hurtTimer+=_delta
		if hurtTimer>hurtDelay:
			hurtTimer=0
			state=Game.enemyState.Idle
		
		
	z_index=floori(global_position.y/MapData.cellSize)+1
	queue_redraw()
	
	
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

#播放旋转动画
func playRotateAni(newAngle):
	if tween!=null && tween.is_running():
		tween.kill()
	
	tween=create_tween()
	ani.animation="rotate"
	ani.frame=oldAngle*4
	tween.tween_property(ani,"frame",newAngle*4,0.2)	
	
#被击中	
func hit(damage:int,attackPos:Vector2, recoil:float=0):
	hp-=damage
	print("hit",hp)
	if hp<=0:
		state=Game.enemyState.dead
		ani.play("fallDown_%s"%[angle/2])
		bodyShape.disabled=true
		await ani.animation_finished
		var temp=create_tween()
		temp.tween_interval(2)
		temp.tween_property(ani,"modulate:a",0,1)
		temp.tween_callback(queue_free)
	else:
		state=Game.enemyState.hurt
		hurtTimer=0
		ani.play("hitFront_%s"%[angle])
	



func _draw() -> void:
	draw_string(font, Vector2(30, 10),"%s-%s"%\
	[floori(global_position.x/MapData.cellSize),floori(global_position.y/MapData.cellSize)] 
	, HORIZONTAL_ALIGNMENT_LEFT, -1,16,Color.BLACK)
	
	
