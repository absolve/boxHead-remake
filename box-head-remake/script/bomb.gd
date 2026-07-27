extends Node2D

## 炸弹脚本
# 实现炸弹的飞行和爆炸逻辑
# 炸弹会沿指定方向飞一段距离后爆炸


## 爆炸效果场景预加载
var explosion = preload("res://scene/explosion.tscn")

## 动画节点
@onready var ani = $ani

## 飞行方向向量
var vector: Vector2

## 飞行距离（像素）
var distance = 40


## 初始化
func _ready() -> void:
	# 创建飞行动画补间
	var tween = create_tween()
	tween.tween_property(self, "position", global_position + vector * distance +
						Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.6) \
						.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# 飞行结束后触发爆炸
	tween.tween_callback(addExplosion)


## 添加爆炸效果
# 创建爆炸并销毁炸弹
func addExplosion():
	var temp = explosion.instantiate()
	temp.global_position = global_position
	get_tree().current_scene.add_child(temp)
	queue_free()
