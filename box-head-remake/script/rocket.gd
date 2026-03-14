extends "res://script/weapon.gd"

var bullet=preload("res://scene/rocket_bullet.tscn")

func _ready():
	offsetDir[0]=Vector2(45,3)
	offsetDir[1]=Vector2(20,20)
	offsetDir[2]=Vector2(-10,30)
	offsetDir[3]=Vector2(-38,10)
	offsetDir[4]=Vector2(-40,-20)
	offsetDir[5]=Vector2(-18,-45)
	offsetDir[6]=Vector2(20,-40)
	offsetDir[7]=Vector2(40,-20)



func fire(v):
	if ammoNum<=0:
		return
	if canShoot:
		ammoNum-=1
		canShoot=false
		timer.start(delay)	
		sound.play()
		vector=v
		var temp=bullet.instantiate()
		temp.vector=vector
		var offset=offsetDir[wrapi(int(vector.angle() / (PI/4)), 0, 8)]
		temp.global_position=global_position+offset
		get_tree().root.add_child(temp)
		
