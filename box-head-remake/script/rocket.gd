extends "res://script/weapon.gd"

## 火箭发射器脚本
# 继承自weapon.gd，实现火箭发射器的发射逻辑
# 发射火箭弹实体，火箭弹会飞行并在碰撞时爆炸


## 火箭弹场景预加载
var bullet = preload("res://scene/rocket_bullet.tscn")


## 初始化
func _ready():
	# 设置8个方向的武器偏移量
	offsetDir[0] = Vector2(45, -15)
	offsetDir[1] = Vector2(20, 0)
	offsetDir[2] = Vector2(-10, 10)
	offsetDir[3] = Vector2(-35, -5)
	offsetDir[4] = Vector2(-40, -35)
	offsetDir[5] = Vector2(-18, -45)
	offsetDir[6] = Vector2(15, -50)
	offsetDir[7] = Vector2(40, -35)


## 射击
# 发射火箭弹实体
# @param v 发射方向（Vector2）
func fire(v):
	if ammoNum <= 0:
		return
	if canShoot:
		ammoNum -= 1
		canShoot = false
		timer.start(delay)
		sound.play()
		vector = v
		
		# 创建火箭弹实例
		var temp = bullet.instantiate()
		temp.vector = vector
		
		# 根据方向计算发射位置偏移
		var offset = offsetDir[wrapi(int(vector.angle() / (PI / 4)), 0, 8)]
		temp.global_position = global_position + offset
		temp.damage = damage
		
		get_tree().root.add_child(temp)