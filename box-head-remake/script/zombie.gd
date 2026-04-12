extends "res://script/character.gd"


@onready var ani = $ani
@onready var body = $body
@onready var bodyShape = $body/bodyShape
@onready var attackArea=$attackArea


var font: FontFile

var target = null
var targetOldPos = Vector2.ZERO
var attackRange = 35 # 攻击范围
var path = [] # 路径点
var targetPos = null
var pathUpdateInterval = 0.5
var pathTimer = 0
var pathPointIndex = 0
var oldAngle = 0 # 之前的角度
var tween: Tween = null
var hurtTimer = 0
var hurtDelay = 0.5
var attackTimer = 0
var attackDelay=1
var shapeQuery=PhysicsShapeQueryParameters2D.new()
var lastVelocity=Vector2.ZERO
var searchOrder=true #查找方向  true为顺时针
var findPathTimer=0
var findPathDelay=2
var nextPoint=Vector2.ZERO
#方向
var directions:Array[eightDir]=[]
var oldDir:Array[Vector2]=[]  #旧的方向


class eightDir:
	var dir:Vector2
	var dot:float
	var canMove:bool
	
	func _init(_dir:Vector2,_dot:float):
		self.dir=_dir
		self.dot=_dot
	

#攻击时判定框位置调整
var attackPos={0:Vector2(20,-9),1:Vector2(20,-3),2:Vector2(0,3),
				3:Vector2(-11,-5),4:Vector2(-9,-11),5:Vector2(5,-17),
				6:Vector2(5,-17),7:Vector2(16,-17)}
var attackPosAngle={2:90,6:90}


func _ready():
	state = Game.enemyState.Idle
	font = load("res://font/AlibabaPuHuiTi-3-85-Bold.ttf")
	#font = ThemeDB.fallback_font
	shapeQuery.collide_with_bodies=false
	shapeQuery.collide_with_areas=true
	shapeQuery.collision_mask=1+2+4
	shapeQuery.exclude=[body.get_rid()]
	shapeQuery.shape=shape.shape
	
	for i in range(0,8):
		directions.append(eightDir.new(Vector2.RIGHT.rotated(i * PI * 2 / 8),0))
	
	
func _physics_process(_delta: float) -> void:
	if state == Game.enemyState.Idle:
		#velocity=Vector2.ZERO
		pathTimer += _delta
		if pathTimer > pathUpdateInterval:
			target = findTarget()
			#if target:
				#if targetOldPos != target.global_position:
					#targetOldPos = target.global_position
					#path = MapData.findPath(global_position, target.global_position)
					#if path.size() > 0:
						##pathPointIndex = 1
						#nextPoint=path[1]
			#else:
				#path = []
			pathTimer = 0
	
		
		
		#if path.size() > 0:
			#velocity = (nextPoint- global_position).normalized()
			#if global_position.distance_to(nextPoint)<1:
				#if path.size()<2:
					#velocity = Vector2.ZERO
				#else:
					#path.remove_at(0)
					#nextPoint=path[1]
		#else:
			#velocity = Vector2.ZERO
			
		var space_state = get_world_2d().direct_space_state
		
		#简单的寻路
		if target != null:
			var targetDir=(target.global_position-global_position)
			var bestDir=Vector2.ZERO
			var minDot=[]
			var maxDot=[]
			for i in directions:
				var dot=targetDir.dot(i.dir)
				shapeQuery.transform=Transform2D(global_rotation,global_position+i.dir*speed*_delta)
				var predictionResult=space_state.intersect_shape(shapeQuery,4)
				if predictionResult:
					i.canMove=false
				else:
					i.canMove=true	
				var a = round(i.dir.angle() / (PI / 4))
				i.dot = wrapi(int(a), 0, 8)	
				if dot>=0 && i.canMove: #夹角大于等于90
					minDot.append(i)
				elif i.canMove:
					maxDot.append(i)
			#挑选夹角最小值
			if minDot.size()>0:
				bestDir=minDot[0]
				for m in minDot:
					print('---',m.dir,' ',m.dot)
					#var dot1=floor(targetDir.dot(m.dir))
					#var dot2=floor(targetDir.dot(bestDir.dir))
					if m.dot<bestDir.dot:
						bestDir=m
			else: #只有大于90度的方向
				bestDir= maxDot[0]
				for m in maxDot:
					if floor(m.dir.dot(targetDir))>floor(bestDir.dot(targetDir)):
						bestDir=m
			
			#判断所有的方向是否可以移动 排除不可以移动的反向
			print(bestDir.dir)
			
			velocity=bestDir.dir
		
			
		if target != null:
			var dis = global_position.distance_to(target.global_position)
			if dis < attackRange:
				velocity = Vector2.ZERO
				ani.play("attack" + "_%s"%angle)
				attackArea.position=attackPos[angle]
				attackTimer=0
				if attackPosAngle.has(angle):
					attackArea.rotation=deg_to_rad(attackPosAngle[angle])
				else:
					attackArea.rotation=0	
				state=Game.enemyState.attack
				return
		
		#判断是否发生碰撞
		
		shapeQuery.transform=Transform2D(global_rotation,global_position)
		var result=space_state.intersect_shape(shapeQuery,4)
		if result:
			var r=result[0]
			if r.collider.get('type')&&r.collider.type in [Game.itemType.Barrel,
								Game.itemType.Wall,Game.roleType.Player,
								Game.roleType.Zombie,Game.roleType.Devil]:
				var shape1=r.collider.get_node("shape").shape
				var delta=global_position-r.collider.global_position
				#if abs(delta.x)>shape1.size.x/2&&abs(delta.y)>shape1.size.y/2:
				if abs(delta.x) > abs(delta.y):
					# 左右边
					var signx = sign(delta.x)
					global_position.x =r.collider.global_position.x+signx*(shape1.size.x/2+shape.shape.size.x/2)
				else:
					# 上下边
					var signy = sign(delta.y)	
					global_position.y =r.collider.global_position.y+signy*(shape1.size.y/2+shape.shape.size.y/2)
		
		#预测当前方向是否会发生碰撞	
		#shapeQuery.transform=Transform2D(global_rotation,global_position+velocity*speed*_delta)
		#var predictionResult=space_state.get_rest_info(shapeQuery)
		#
		#if predictionResult:	
			#findPathTimer+=_delta
			#if findPathDelay<findPathTimer:	#重新寻路
				#findPathTimer=0
				#path = MapData.findPath(global_position, target.global_position)
				#if path.size() > 0:
					#nextPoint=path[1]
					#
			#print(velocity)
			##velocity =velocity.rotated(deg_to_rad(-90)).normalized()
			#velocity=Vector2.DOWN
			#lastVelocity=velocity	
		
					
		#print(velocity.angle())
		
			
		if velocity.length() > 0:
			currAni = "walk"
		else:
			currAni = "stand"
		
		if velocity.length() != 0:
			#print(velocity.angle())
			angle = round(velocity.angle() / (PI / 4))
			angle = wrapi(int(angle), 0, 8)
			if angle != oldAngle:
				#velocity = Vector2.ZERO
				playRotateAni(angle)
			oldAngle = angle
		
		if tween == null || !tween.is_running():
			velocity *= speed
			ani.play(currAni + "_%s"%angle)
			move_and_collide(velocity * _delta)
		
	elif state == Game.enemyState.dead:
		pass
	elif state == Game.enemyState.hurt:
		hurtTimer += _delta
		if hurtTimer > hurtDelay:
			hurtTimer = 0
			state = Game.enemyState.Idle
		velocity=velocity.lerp(Vector2.ZERO,hurtTimer)
		move_and_collide(velocity * _delta)
	elif state==Game.enemyState.attack:
		if !ani.is_playing():
			attackTimer+=_delta
			if attackTimer>attackDelay:
				attackTimer=0
				state=Game.enemyState.Idle
				
				
	z_index = floori(global_position.y / MapData.cellSize) + 1
	queue_redraw()
	
	
#寻找目标
func findTarget():
	var nodes = get_tree().get_nodes_in_group("player")
	if nodes.size() > 0:
		var minDistance = INF
		var nearestEnemy = null
		for i in nodes:
			var dis = global_position.distance_to(i.global_position)
			if dis < minDistance:
				minDistance = dis
				nearestEnemy = i
		return nearestEnemy
	else:
		return null

#播放旋转动画
func playRotateAni(newAngle):
	if tween != null && tween.is_running():
		tween.kill()
	
	tween = create_tween()
	ani.animation = "rotate"
	ani.frame = oldAngle * 4
	tween.tween_property(ani, "frame", newAngle * 4, 0.2)
	
#被击中	
func hit(damage: int, _attackPos: Vector2, recoil: float = 0):
	hp -= damage
	print("hit", hp)
	if hp <= 0:
		state = Game.enemyState.dead
		ani.play("fallDown_%s" % [angle / 2])
		shape.disabled = true
		bodyShape.disabled = true
		await ani.animation_finished
		var temp = create_tween()
		temp.tween_interval(2)
		temp.tween_property(ani, "modulate:a", 0, 1)
		temp.tween_callback(queue_free)
	else:
		state = Game.enemyState.hurt
		hurtTimer = 0
		var attacker=(_attackPos-global_position).normalized()
		var dot = velocity.normalized().dot(attacker)
		if dot>0: #正面击中
			ani.play("hitFront_%s" % [angle])
		else: #背面 侧面击中
			ani.play("hitRear_%s" % [angle])	
		velocity=Vector2.RIGHT.rotated(velocity.angle())*-recoil

func _draw() -> void:
	draw_string(font, Vector2(30, 10), "%s-%s" % \
	[floori(global_position.x / MapData.cellSize), floori(global_position.y / MapData.cellSize)]
	, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
