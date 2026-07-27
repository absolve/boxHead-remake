extends "res://script/item.gd"

## 火箭弹脚本
# 继承自item.gd，实现火箭弹的飞行和爆炸逻辑
# 火箭弹会沿直线飞行，碰撞物体或到达边界时爆炸，并留下烟雾轨迹


## 烟雾效果场景预加载
var smoke = preload("res://scene/smoke.tscn")

## 爆炸效果场景预加载
var explosion = preload("res://scene/explosion.tscn")

## 飞行方向向量
var vector = Vector2.ZERO

## 飞行速度
var speed = 700

## 伤害值
var damage = 0


## 初始化
func _ready() -> void:
	# 播放默认动画
	ani.play("default")
	
	# 创建循环补间，定期生成烟雾轨迹
	var tween = create_tween()
	tween.set_loops()
	tween.tween_callback(addSmoke)
	tween.tween_interval(0.2)


## 添加烟雾效果
# 在当前位置创建一个烟雾粒子
func addSmoke():
	var temp = smoke.instantiate()
	temp.global_position = global_position
	get_tree().current_scene.add_child(temp)


## 物理帧更新
func _physics_process(delta: float) -> void:
	# 检测与物体的碰撞
	var body = get_overlapping_bodies()
	if body:
		var temp = explosion.instantiate()
		temp.global_position = global_position
		temp.damage = damage
		get_tree().current_scene.add_child(temp)
		queue_free()
	
	# 检测与区域的碰撞
	var area = get_overlapping_areas()
	if area:
		var temp = explosion.instantiate()
		temp.global_position = global_position
		temp.damage = damage
		get_tree().current_scene.add_child(temp)
		queue_free()
	
	# 到达地图边界时爆炸
	if global_position.x < itemSize.x / 2 or global_position.x > MapData.mapSize.x - itemSize.x / 2 \
		or global_position.y < itemSize.y / 2 or global_position.y > MapData.mapSize.y - itemSize.y / 2:
		var temp = explosion.instantiate()
		temp.global_position = global_position
		temp.damage = damage
		get_tree().current_scene.add_child(temp)
		queue_free()
	
	# 沿方向移动
	position += vector * speed * delta


## 离开屏幕时销毁
func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	queue_free()
