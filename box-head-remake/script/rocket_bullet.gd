extends "res://script/item.gd"

var smoke = preload("res://scene/smoke.tscn")
var explosion = preload("res://scene/explosion.tscn")
var vector = Vector2.ZERO
var speed = 700
var damage = 0 # 伤害

func _ready() -> void:
	ani.play("default")
	var tween = create_tween()
	tween.set_loops()
	tween.tween_callback(addSmoke)
	tween.tween_interval(0.2)

func addSmoke():
	var temp = smoke.instantiate()
	temp.global_position = global_position
	get_tree().root.add_child(temp)
	

func _physics_process(delta: float) -> void:
	var body = get_overlapping_bodies()
	if body:
		var temp = explosion.instantiate()
		temp.global_position = global_position
		temp.damage = damage
		get_tree().root.add_child(temp)
		queue_free()
	var area = get_overlapping_areas()
	if area:
		var temp = explosion.instantiate()
		temp.global_position = global_position
		temp.damage = damage
		get_tree().root.add_child(temp)
		queue_free()
	
	#到达游戏屏幕边界爆炸
	if global_position.x < itemSize.x / 2 or global_position.x > MapData.mapSize.x - itemSize.x / 2 \
		or global_position.y < itemSize.y / 2 or global_position.y > MapData.mapSize.y - itemSize.y / 2:
		var temp = explosion.instantiate()
		temp.global_position = global_position
		temp.damage = damage
		get_tree().root.add_child(temp)
		queue_free()

	position += vector * speed * delta


func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	queue_free()
