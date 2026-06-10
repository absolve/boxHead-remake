extends "res://script/character.gd"


@onready var ani = $ani
@onready var body = $body
@onready var bodyShape = $body/bodyShape
@onready var attackArea=$attackArea
@onready var navigationAgent2D=$NavigationAgent2D


var font: FontFile

var target = null
var targetOldPos = Vector2.ZERO
var attackRange = 35 # 攻击范围
var path = [] # 路径点
var targetPos = null
var pathUpdateInterval = 1
var pathTimer = 0
var pathPointIndex = 0
var oldAngle = 0 # 之前的角度
#var tween: Tween = null
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
var dir = [
	Vector2(1, 0),       # right
	Vector2(1, 1),       # down-right
	Vector2(0, 1),       # down
	Vector2(-1, 1),      # down-left
	Vector2(-1, 0),      # left
	Vector2(-1, -1),      # up-left
	Vector2(0, -1),      # up
	Vector2(1, -1),      # up-right
]
var directions:Array[eightDir]=[]
var recentPos:Array[Vector2]=[]  #旧的格子位置
var recentMax=30  #最大记录数
var isBlocked=false #前进方向被阻挡
var initPos=Vector2.ZERO #抵达初始点后开始寻找玩家
var delta=0


class eightDir:
	var dir:Vector2
	var dot:float
	var canMove:bool #是否可以移动
	var normal:Vector2  #碰到障碍物的法线
	var distance:float #距离目标位置的距离
	
	func _init(_dir:Vector2):
		self.dir=_dir

	func _to_string() -> String:
		return 'dir %s canMove %s distance %s  dot %s'%[dir,canMove,distance,dot]



#攻击时判定框位置调整
var attackPos={0:Vector2(20,-9),1:Vector2(20,-3),2:Vector2(0,3),
				3:Vector2(-11,-5),4:Vector2(-9,-11),5:Vector2(5,-17),
				6:Vector2(5,-17),7:Vector2(16,-17)}
var attackPosAngle={2:90,6:90}


func _ready():
	state = Game.enemyState.hurt
	font = ThemeDB.fallback_font
	#shapeQuery.collide_with_bodies=false
	shapeQuery.collide_with_areas=true
	shapeQuery.collision_mask=1+2+4+8
	shapeQuery.exclude=[get_rid()]
	shapeQuery.shape=shape.shape
	
	for i in dir:
		directions.append(eightDir.new(i))
	delta=get_physics_process_delta_time()

	
func _physics_process(_delta: float) -> void:
	delta=_delta
	if state == Game.enemyState.Idle:
		#velocity=Vector2.ZERO
		pathTimer += _delta
		if pathTimer > pathUpdateInterval:
			target = findTarget()
			pathTimer = 0
			navigationAgent2D.target_position=target.global_position
		if navigationAgent2D.is_navigation_finished():
			velocity=Vector2.ZERO
			return
		var next_path_position: Vector2 = navigationAgent2D.get_next_path_position()
		var newVelocity=global_position.direction_to(next_path_position)
		#var octant: int = wrapi(int(velocity.angle() / (PI / 4.0)),0,8)
		#velocity=dir[octant].normalized()
		navigationAgent2D.set_velocity(newVelocity*speed)
		
			
		#if target != null:
			#var dis = global_position.distance_to(target.global_position)
			#if dis < attackRange:
				#velocity = Vector2.ZERO
				#ani.play("attack" + "_%s"%angle)
				#attackArea.position=attackPos[angle]
				#attackTimer=0
				#if attackPosAngle.has(angle):
					#attackArea.rotation=deg_to_rad(attackPosAngle[angle])
				#else:
					#attackArea.rotation=0	
				#state=Game.enemyState.attack
				#return
		#
		##判断是否发生碰撞	
		#shapeQuery.transform=Transform2D(global_rotation,global_position)
		#var result=space_state.intersect_shape(shapeQuery,1)
		#if result:
			#var r=result[0]
			#if r.collider.get('type')&&r.collider.type in [Game.itemType.Barrel,
								#Game.itemType.Wall,Game.roleType.Player,
								#Game.roleType.Zombie,Game.roleType.Devil]:
				#var shape1=r.collider.get_node("shape").shape
				#var delta=global_position-r.collider.global_position
				##if abs(delta.x)>shape1.size.x/2&&abs(delta.y)>shape1.size.y/2:
				#if abs(delta.x) > abs(delta.y):
					## 左右边
					#var signx = sign(delta.x)
					#global_position.x =r.collider.global_position.x+signx*(shape1.size.x/2+shape.shape.size.x/2)
				#else:
					## 上下边
					#var signy = sign(delta.y)	
					#global_position.y =r.collider.global_position.y+signy*(shape1.size.y/2+shape.shape.size.y/2)
		
		#if velocity.length() > 0:
			#currAni = "walk"
		#else:
			#currAni = "stand"

		#if velocity.length() != 0:
			##print(velocity.angle())
			#angle = round(velocity.angle() / (PI / 4))
			#angle = wrapi(int(angle), 0, 8)
			#if angle != oldAngle:
				##velocity = Vector2.ZERO
				#playRotateAni(angle)
				#return
			##oldAngle = angle
		#ani.play(currAni + "_%s"%angle)
	elif state == Game.enemyState.dead:
		pass
	elif state == Game.enemyState.hurt:
		hurtTimer += _delta
		if hurtTimer >= hurtDelay:
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
	elif state==Game.enemyState.rotate:
		#print(angle,'   ',oldAngle)
		if abs(angle-oldAngle)==7:  #特殊情况
			if angle<oldAngle:
				ani.frame=wrapi(ani.frame+1,0,32)
			else:
				ani.frame=wrapi(ani.frame-1,0,32)	
		elif  angle<oldAngle || abs(angle-oldAngle)>=4:
			ani.frame=wrapi(ani.frame-1,0,32)
		else:
			ani.frame=wrapi(ani.frame+1,0,32)
		if ani.frame==angle*4:
			oldAngle=angle
			state=Game.enemyState.Idle			
	elif state==Game.enemyState.init:
		currAni = "walk"
		var space_state = get_world_2d().direct_space_state
		#判断是否发生碰撞	
		shapeQuery.transform=Transform2D(global_rotation,global_position)
		var result=space_state.intersect_shape(shapeQuery,1)
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
				currAni = "stand"
		
		ani.play(currAni + "_%s"%angle)
		move_and_collide(velocity *speed* _delta)	
		if global_position.distance_to(initPos)<1:
			state=Game.enemyState.Idle
		
		
	z_index = roundi(global_position.y / MapData.cellSize) + 1
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
func playRotateAni(_newAngle):
	#if tween != null && tween.is_valid():
		#tween.kill()
	#
	#tween = create_tween()
	ani.stop()
	ani.animation = "rotate"
	ani.frame = oldAngle * 4
	state=Game.enemyState.rotate
	#print(oldAngle,' ',newAngle)
	#print(oldAngle * 4,' ',newAngle*4,' ',abs(newAngle*4-oldAngle*4))
	#print(sign(newAngle-oldAngle))
	#var add=1
	#if newAngle<oldAngle || abs(newAngle-oldAngle)>=4:
		#add=-1
	#tween.set_loops()	
	#tween.step_finished.connect(_on_tween_step)
	#tween.tween_callback(changeFrame.bind(add))
	#tween.tween_interval(0.05)
	
	#tween.tween_property(ani, "frame", newAngle * 4, 0.2)

#func changeFrame(val):
	#print(val)
	#ani.frame=wrapi(ani.frame+val,0,32)
	#print(ani.frame)

#func _on_tween_step(_idx):
	#if ani.frame==angle*4:
		#tween.kill()
	
#被击中	
func hit(damage: int, _attackPos: Vector2, recoil: float = 0):
	if isDead:
		return
	hp -= damage
	print("hit", hp)
	#if tween != null && tween.is_valid():
		#tween.kill()
	if oldAngle!=angle:
		oldAngle=angle
	if hp <= 0:
		isDead=true
		state = Game.enemyState.dead
		ani.play("fallDown_%s" % [angle / 2])
		body.monitorable=false
		body.monitoring=false
		bodyShape.disabled=true
		shape.disabled = true
		Game.enemyKilled.emit(global_position)
		var temp = create_tween()
		temp.tween_interval(5)
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


func _on_navigation_agent_2d_velocity_computed(_safe_velocity: Vector2) -> void:
	#var octant: int = wrapi(int(_safe_velocity.angle() / (PI / 4.0)),0,8)
	#velocity=dir[octant].normalized()
	#velocity=_safe_velocity.snapped(Vector2.RIGHT.rotated(TAU / 8.0))
	if state == Game.enemyState.Idle:
		#velocity=_safe_velocity.normalized()
		velocity=_safe_velocity.snapped(Vector2.RIGHT.rotated(TAU / 8.0)).normalized()
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
				return
			#oldAngle = angle
		ani.play(currAni + "_%s"%angle)
		

		move_and_collide(velocity *speed*delta)
