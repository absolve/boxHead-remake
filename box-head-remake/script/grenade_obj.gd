extends "res://script/item.gd"

var explosion=preload("res://scene/explosion.tscn")
@onready var sound=$sound
@onready var shape=$shape

var vector=Vector2.ZERO
var height=25
var speed=50
var tween=null
var floorPos=Vector2.ZERO
var isOnFloor=false
var angle=0


func _ready() -> void:
	gravity=900
	#vector=vector*speed
	#vector.y=-200
	#vector.x*=speed	
	angle=vector.angle()
	vector*=speed
	vector.y+=-150*abs(cos(angle))
	#floorPos=global_position+Vector2(0,height)
	#print(floorPos)
	
	print(angle)
	print(cos(angle))
	
func _physics_process(delta: float) -> void:
	if !isOnFloor:
		vector.y += gravity*abs(cos(angle)) * delta
		#height-=gravity * delta
		height-=vector.y* delta
		if height<=0:
			isOnFloor=true
			vector.y*=sin(angle)
			print('===',abs(sin(angle)))
	if isOnFloor:
		vector=vector.lerp(Vector2.ZERO,0.05)
	

	
	if position.x<=itemSize.x/2 || position.x>=MapData.mapSize.x-itemSize.x/2:
		vector.x*=-1
		sound.play()
	if position.y<=itemSize.y/2||position.y>=MapData.mapSize.y-itemSize.y/2:
		vector.y*=-1
		sound.play()
	
	var result=has_overlapping_areas()
	#var result2=has_overlapping_bodies()
	if result:
		var space = get_world_2d().direct_space_state
		var params = PhysicsShapeQueryParameters2D.new()
		#params.exclude=[self]
		params.shape=shape.shape
		params.transform=Transform2D(global_rotation,global_position)
		params.collision_mask = collision_mask
		params.collide_with_areas=true
		var collision = space.get_rest_info(params)  # 只取第一个碰撞
		if collision:
			var normal = collision.normal
			print('normal',normal)
			
			var safe_motion = vector.project(normal)
			print(safe_motion)
			#position-=safe_motion
			vector=vector.bounce(normal)
		#if abs(vector.x)>0:
			#vector.x*=-1
			#sound.play()
		#if abs(vector.y)>0:
			#vector.y*=-1	
			#sound.play()
		#vector*=-1
	
	
	position.x=clamp(position.x,itemSize.x/2,MapData.mapSize.x-itemSize.x/2)
	position.y=clamp(position.y,itemSize.y/2,MapData.mapSize.y-itemSize.y/2)
	
	
	position+=vector*delta
	if vector.length()<=0.1&&tween==null:
		print('addExplosion')
		addExplosion()
	
	
	
func addExplosion():
	tween=create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		var temp=explosion.instantiate()
		temp.global_position=global_position
		get_tree().root.add_child(temp)
		)
	tween.tween_callback(queue_free)
	
	
