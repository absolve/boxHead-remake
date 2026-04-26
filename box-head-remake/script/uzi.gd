extends "res://script/weapon.gd"

@onready var ani=$ani
@onready var player=$player
#var intersectPos=null
var targetPos=Vector2.ZERO

func _ready():
	offsetDir[0]=Vector2(45,-15)
	offsetDir[1]=Vector2(20,0)
	offsetDir[2]=Vector2(-10,10)
	offsetDir[3]=Vector2(-35,-5)
	offsetDir[4]=Vector2(-40,-35)
	offsetDir[5]=Vector2(-18,-45)
	offsetDir[6]=Vector2(15,-50)
	offsetDir[7]=Vector2(40,-35)


func _physics_process(_delta: float) -> void:
	if detecframes>0:
		detecframes-=1
		#if detecframes<=0:
			#queue_redraw()
			#excludeObj.clear()
		var space_state = get_world_2d().direct_space_state
		var offset=offsetDir[wrapi(int(vector.angle() / (PI/4)), 0, 8)]
		targetPos=global_position+vector*wRange+offset
		var query = PhysicsRayQueryParameters2D.create(global_position+offset, 
		targetPos,collisionMask)
		#query.exclude = [self]
		var result = space_state.intersect_ray(query)
		print(result)
		if result:
			#if !excludeObj.has(result.collider):		
			if 	result.collider is StaticBody2D:
				targetPos=result.position
				addSmoke(targetPos)
			elif result.collider.get("type") &&result.collider.type in [Game.itemType.Barrel,
									Game.itemType.Wall]:
				if !excludeObj.has(result.collider_id):
					result.collider.hit(damage)
					excludeObj.append(result.collider_id)
				targetPos=result.position
				addSmoke(targetPos)
			elif result.collider is Area2D:
				if result.collider.owner.type && result.collider.owner.type in [Game.roleType.Player,
				Game.roleType.Zombie,Game.roleType.Devil]:
					if !excludeObj.has(result.collider_id):
						result.collider.owner.hit(damage,result.position,hitFeedback)
						excludeObj.append(result.collider_id)
					targetPos=result.position
					addSmoke(targetPos)	
		queue_redraw()
		
func fire(v):
	if ammoNum<=0:
		return
	if canShoot:
		ammoNum-=1
		print('shoot')
		detecframes=2
		vector=v
		#queue_redraw()
		canShoot=false
		timer.start(delay)		
		ani.position=offsetDir[wrapi(int(vector.angle()/ (PI/4)), 0, 8)]
		ani.rotation=vector.angle()
		player.play("fire")
		sound.play()
		excludeObj.clear()
	
func _draw() -> void:
	if detecframes>0:
		var offset=offsetDir[wrapi(int(vector.angle()/ (PI/4)), 0, 8)]
		#if intersectPos!=null:
			#draw_line(offset,
				#intersectPos-global_position,Color.WHITE)
		#else:
		draw_line(offset,
			targetPos-global_position,Color.WHITE,1.5)	
