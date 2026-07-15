extends "res://script/weapon.gd"

## 油桶武器脚本
# 继承自weapon.gd，实现油桶的放置逻辑
# 在当前位置放置一个油桶，被击中时会爆炸


## 油桶物体场景预加载
var barrelObj = preload("res://scene/barrel_obj.tscn")

## 分裂爆炸数量
var splitExplosion = 0


## 初始化
func _ready() -> void:
	pass


## 放置油桶
# 在当前位置放置一个油桶物体
# @param _v 放置方向（Vector2，未使用）
func fire(_v):
	if ammoNum <= 0:
		return
	
	var pos = global_position
	
	# 检查该位置是否已有物品
	if !MapData.checkHasMapItem(pos):
		# 创建油桶实例
		var temp = barrelObj.instantiate()
		
		# 将位置对齐到网格
		temp.global_position = Vector2(floori(pos.x / MapData.cellSize) * MapData.cellSize, \
				floori(pos.y / MapData.cellSize) * MapData.cellSize) + \
				Vector2(MapData.cellSize / 2, MapData.cellSize / 2)
		
		# 设置Z轴顺序
		temp.z_index = floori(pos.y / MapData.cellSize)
		
		# 设置伤害值和分裂爆炸数量
		temp.damage = damage
		temp.splitExplosion = splitExplosion
		
		get_tree().root.add_child(temp)
		
		# 记录到地图物品列表
		MapData.addMapItem(pos, temp.get_instance_id())
		
		# 播放放置音效
		sound.play()
		ammoNum -= 1