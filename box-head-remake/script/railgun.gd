extends "res://script/weapon.gd"


@onready var ani=$ani
@onready var player=$player
@onready var ray=$ray

var targetPos=Vector2.ZERO

func _ready():
	offsetDir[0]=Vector2(45,8)
	offsetDir[1]=Vector2(20,20)
	offsetDir[2]=Vector2(-10,20)
	offsetDir[3]=Vector2(-38,10)
	offsetDir[4]=Vector2(-40,-10)
	offsetDir[5]=Vector2(-18,-45)
	offsetDir[6]=Vector2(20,-40)
	offsetDir[7]=Vector2(40,-20)
	#ray.rotate(deg_to_rad(90))


func _physics_process(_delta):
	if detecframes>0:
		detecframes-=1
		if detecframes<=0:
			excludeObj.clear()
		
		queue_redraw()

func fire(_v):
	if ammoNum<=0:
		return
	if canShoot:
		detecframes=2
		vector=_v
		ammoNum-=1
		canShoot=false
		timer.start(delay)	
		var offset=offsetDir[wrapi(int(vector.angle()/ (PI/4)), 0, 8)]
		ani.position=offset
		ani.rotation=vector.angle()
		player.play("fire")
		sound.play()
		#设置射线角度
		ray.rotation=vector.angle()
		ray.position=offset
		print(vector.angle())
		targetPos=global_position+vector*wRange+offset


func _draw() -> void:
	if detecframes>0:
		var offset=offsetDir[wrapi(int(vector.angle()/ (PI/4)), 0, 8)]
		draw_line(offset,
			targetPos-global_position,Color.BLUE_VIOLET,1.5)	
