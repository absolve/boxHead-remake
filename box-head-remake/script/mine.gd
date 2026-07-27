extends "res://script/weapon.gd"

## 地雷武器脚本
# 继承自weapon.gd，实现地雷的放置逻辑
# 在当前位置放置一个地雷，敌人触碰到时会爆炸


## 地雷物体场景预加载
var mineObj = preload("res://scene/mine_obj.tscn")


## 放置地雷
# 在当前位置放置一个地雷物体
# @param _v 放置方向（Vector2，未使用）
func fire(_v):
	if ammoNum <= 0:
		return
	
	var pos = global_position
	
	# 检查该位置是否已有物品
	if !MapData.checkHasMapItem(pos):
		# 创建地雷实例
		var temp = mineObj.instantiate()
		
		# 将位置对齐到网格
		temp.global_position = Vector2(floori(pos.x / MapData.cellSize) * MapData.cellSize, \
				floori(pos.y / MapData.cellSize) * MapData.cellSize) + \
				Vector2(MapData.cellSize / 2, MapData.cellSize / 2)
		
		# 设置Z轴顺序
		temp.z_index = floori(pos.y / MapData.cellSize)
		
		# 设置伤害值
		temp.damage = damage
		
		get_tree().current_scene.add_child(temp)
		
		# 记录到地图物品列表
		MapData.addMapItem(pos, temp.get_instance_id())
		
		# 播放放置音效
		sound.play()
		ammoNum -= 1
