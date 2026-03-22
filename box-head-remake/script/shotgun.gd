extends "res://script/weapon.gd"

@onready var ani=$ani
@onready var player=$player

var bulletNum=4  #散弹数量
var splitAngle=30.0  #散弹分裂最大角度
var targetPosList=[]  #射线列表


func _ready():
	offsetDir[0]=Vector2(45,8)
	offsetDir[1]=Vector2(20,20)
	offsetDir[2]=Vector2(-10,20)
	offsetDir[3]=Vector2(-38,10)
	offsetDir[4]=Vector2(-40,-10)
	offsetDir[5]=Vector2(-18,-45)
	offsetDir[6]=Vector2(20,-40)
	offsetDir[7]=Vector2(40,-20)
	
	for i in range(bulletNum):
		targetPosList.append(Vector2.ZERO)

func _physics_process(_delta: float) -> void:
	if detecframes>0:
	
		detecframes-=1
		if detecframes<=0:
			excludeObj.clear()
			#queue_redraw()
		for i in range(bulletNum):
			var space_state = get_world_2d().direct_space_state
			var offset=offsetDir[wrapi(int(vector.angle() / (PI/4)), 0, 8)]
			targetPosList[i]=global_position+vector.rotated(deg_to_rad(-splitAngle/2+i*splitAngle/bulletNum+randi_range(-2,2)))\
			*wRange+offset
			var query = PhysicsRayQueryParameters2D.create(global_position+offset, 
			targetPosList[i],collisionMask)
			query.collide_with_areas=true
			query.exclude = [ownerId]
			var result = space_state.intersect_ray(query)
			if result:
				#if !excludeObj.has(result.collider):	
				if 	result.collider is StaticBody2D:
					targetPosList[i]=result.position
				elif result.collider.type &&result.collider.type in [Game.itemType.Barrel,Game.itemType.Wall]:
					if !excludeObj.has(result.collider):
						result.collider.hit(damage)
						excludeObj.append(result.collider)
					targetPosList[i]=result.position
						
		queue_redraw()			

func fire(_v):
	if canShoot:
		detecframes=2
		vector=_v
		#queue_redraw()
		canShoot=false
		timer.start(delay)	
		ani.position=offsetDir[wrapi(int(vector.angle()/ (PI/4)), 0, 8)]
		ani.rotation=vector.angle()
		player.play("fire")
		sound.play()

func _draw() -> void:
	if detecframes>0:
		var offset=offsetDir[wrapi(int(vector.angle()/ (PI/4)), 0, 8)]
		for i in targetPosList:
			draw_line(offset,
			i-global_position
			*wRange,Color.WHITE,1.5)
		
