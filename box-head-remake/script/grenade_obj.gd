extends "res://script/item.gd"

var explosion=preload("res://scene/explosion.tscn")
@onready var sound=$sound

var vector=Vector2.ZERO
var height=50
var speed=50
var tween=null

func _ready() -> void:
	gravity=100
	vector=vector*speed
	#vector.x*=speed
	
func _physics_process(delta: float) -> void:
	if height>0:
		vector.y += gravity * delta
		height-=gravity * delta
	vector=vector.lerp(Vector2.ZERO,0.05)
	position+=vector*delta
	#print( vector.length())
	
	if position.x<=itemSize.x/2 || position.x>=MapData.mapSize.x-itemSize.x/2:
		vector.x*=-1
		sound.play()
	if position.y<=itemSize.y/2||position.y>=MapData.mapSize.y-itemSize.y/2:
		vector.y*=-1
		sound.play()
	
	var result=has_overlapping_areas()
	if result:
		if abs(vector.x)>0:
			vector.x*=-1
			sound.play()
		if abs(vector.y)>0:
			vector.y*=-1	
			sound.play()
	
	position.x=clamp(position.x,itemSize.x/2,MapData.mapSize.x-itemSize.x/2)
	position.y=clamp(position.y,itemSize.y/2,MapData.mapSize.y-itemSize.y/2)
	
	if vector.length()<=0.1&&tween==null:
		print('addExplosion')
		addExplosion()
	
	
	
func addExplosion():
	tween=create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		var temp=explosion.instantiate()
		temp.global_position=global_position
		get_tree().root.add_child(temp)
		)
	tween.tween_callback(queue_free)
	
	
