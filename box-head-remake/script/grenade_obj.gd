extends "res://script/item.gd"

var explosion=preload("res://scene/explosion.tscn")
@onready var sound=$sound
@onready var shape=$shape

@export var damage=0 #伤害
var vector=Vector2.ZERO
var height=25
var speed=50
var tween=null
var floorPos=Vector2.ZERO
var isOnFloor=false
var angle=0
var gVec=Vector2(0,-100)  #重力速度


func _ready() -> void:
	gravity=800
	#vector=vector*speed
	#vector.y=-200
	#vector.x*=speed	
	angle=vector.angle()
	vector*=speed
	#floorPos=global_position+Vector2(0,height)
	#print(floorPos)
	print(ownerId)
	
func _physics_process(delta: float) -> void:
	if !isOnFloor:
		#vector.y += gravity*abs(cos(angle)) * delta
		#height-=gravity * delta
		gVec.y+=gravity* delta
		height-=gVec.y* delta
		if height<=0:
			isOnFloor=true
			gVec=Vector2.ZERO
			#vector.y*=sin(angle)
			#print('===',abs(sin(angle)))
	if isOnFloor:
		vector=vector.lerp(Vector2.ZERO,0.05)
	

	
	if position.x<=itemSize.x/2 || position.x>=MapData.mapSize.x-itemSize.x/2:
		vector.x*=-1
		sound.play()
	if position.y<=itemSize.y/2||position.y>=MapData.mapSize.y-itemSize.y/2:
		vector.y*=-1
		sound.play()
	
	
	var space = get_world_2d().direct_space_state
	var params = PhysicsShapeQueryParameters2D.new()
	params.exclude=[ownerId]
	params.shape=shape.shape
	params.transform=Transform2D(global_rotation,global_position)
	params.collision_mask = collision_mask
	params.collide_with_areas=true
	var collision = space.get_rest_info(params)  # 只取第一个碰撞
	if collision:
		var normal = collision.normal
		#var safe_motion = vector.project(normal)
		#print(safe_motion)
		#position-=safe_motion
		vector=vector.bounce(normal)

	
	position.x=clamp(position.x,itemSize.x/2,MapData.mapSize.x-itemSize.x/2)
	position.y=clamp(position.y,itemSize.y/2,MapData.mapSize.y-itemSize.y/2)
	z_index = floori(global_position.y / MapData.cellSize) + 1
	
	
	position+=vector*delta+gVec* delta
	if vector.length()<=0.1&&tween==null:
		print('addExplosion')
		addExplosion()
	
	
	
func addExplosion():
	tween=create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		var temp=explosion.instantiate()
		temp.global_position=global_position
		temp.collision_mask=collision_mask
		temp.damage=damage
		get_tree().root.add_child(temp)
		)
	tween.tween_callback(queue_free)
	
	
