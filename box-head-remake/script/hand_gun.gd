extends "res://script/weapon.gd"

@onready var ani=$ani
@onready var player=$player


func _ready() -> void:
	offsetDir[0]=Vector2(45,3)
	offsetDir[1]=Vector2(20,20)
	offsetDir[2]=Vector2(-10,20)
	offsetDir[3]=Vector2(-38,10)
	offsetDir[4]=Vector2(-40,-20)
	offsetDir[5]=Vector2(-18,-45)
	offsetDir[6]=Vector2(20,-40)
	offsetDir[7]=Vector2(40,-20)


func _physics_process(_delta: float) -> void:
	if detecframes>0:
		detecframes-=1
		if detecframes<=0:
			queue_redraw()
		var space_state = get_world_2d().direct_space_state
		var offset=offsetDir[wrapi(int(vector.angle() / (PI/4)), 0, 8)]
		var query = PhysicsRayQueryParameters2D.create(global_position+offset, 
		global_position+vector*wRange+offset,collisionMask)
		query.collide_with_areas=true
		print(global_position+offset,global_position+vector*wRange+offset)
		#query.exclude = [ownerId]
		var result = space_state.intersect_ray(query)
		print(result)

func fire(v):
	if canShoot:
		print('shoot')
		detecframes=2
		vector=v
		queue_redraw()
		canShoot=false
		timer.start(delay)	
		ani.position=offsetDir[wrapi(int(vector.angle()/ (PI/4)), 0, 8)]
		player.play("fire")
		sound.play()
	#else:
		#if timer.is_stopped():
			#timer.start(delay)	
	
func _draw() -> void:
	if detecframes>0:
		var offset=offsetDir[wrapi(int(vector.angle()/ (PI/4)), 0, 8)]
		draw_line(offset,
			offset+vector*wRange,Color.WHITE)
