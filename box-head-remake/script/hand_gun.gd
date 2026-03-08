extends "res://script/weapon.gd"

func _ready() -> void:
	position+=offset
	pass


func _physics_process(_delta: float) -> void:
	if detecframes>0:
		detecframes-=1
		if detecframes<=0:
			queue_redraw()
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, 
		Vector2.RIGHT.rotated(fireAngle)*wRange)
		#query.exclude = [self]
		var result = space_state.intersect_ray(query)
		print(result)

func fire(angle):
	if canShoot:
		print('shoot')
		detecframes=2
		fireAngle=angle
		queue_redraw()
	else:
		if timer.is_stopped():
			timer.start(delay)	
	
func _draw() -> void:
	if detecframes>0:
		draw_line(position.rotated(fireAngle),Vector2.RIGHT.rotated(fireAngle)*wRange,Color.WHITE)
	pass
