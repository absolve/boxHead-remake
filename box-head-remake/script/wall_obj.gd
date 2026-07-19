extends "res://script/item.gd"

## 墙壁物体脚本
# 继承自item.gd，实现可破坏墙壁的逻辑
# 墙壁有血量，被击中后血量减少，血量归零后销毁并产生烟雾


## 墙壁血量
var hp = 10

## 烟雾效果场景预加载
var smoke = preload("res://scene/smoke.tscn")


## 受伤处理
# 减少血量，血量归零后销毁墙壁
# @param _value 伤害值（int）
func hit(_value):
	hp -= _value
	
	if hp <= 0:
		# 创建烟雾效果
		var temp = smoke.instantiate()
		temp.global_position = global_position
		get_tree().root.add_child(temp)
		
		# 销毁墙壁
		queue_free()
	
	# 更新墙壁损坏动画帧
	ani.frame = wrapi(10 - hp, 0, 10)
