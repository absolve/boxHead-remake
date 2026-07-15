extends "res://script/weapon.gd"

## 墙壁武器脚本
# 继承自weapon.gd，实现墙壁的放置逻辑
# 在当前位置放置一堵临时墙壁，用于阻挡敌人


## 墙壁物体场景预加载
var wallObj = preload("res://scene/wall_obj.tscn")


## 放置墙壁
# 在当前位置放置一堵墙壁物体
# @param _v 放置方向（Vector2，未使用）
func fire(_v):
	if ammoNum <= 0:
		return
	
	var pos = global_position
	
	# 检查该位置是否已有物品
	if !MapData.checkHasMapItem(pos):
		# 创建墙壁实例
		var temp = wallObj.instantiate()
		
		# 将位置对齐到网格
		temp.global_position = Vector2(floori(pos.x / MapData.cellSize) * MapData.cellSize, \
				floori(pos.y / MapData.cellSize) * MapData.cellSize) + \
				Vector2(MapData.cellSize / 2, MapData.cellSize / 2)
		
		# 设置Z轴顺序
		temp.z_index = floori(pos.y / MapData.cellSize)
		
		get_tree().root.add_child(temp)
		
		# 记录到地图物品列表
		MapData.addMapItem(pos, temp.get_instance_id())
		
		# 播放放置音效
		sound.play()
		ammoNum -= 1