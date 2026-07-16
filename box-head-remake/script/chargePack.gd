extends "res://script/weapon.gd"

## 充电包武器脚本
# 继承自weapon.gd，实现充电包的放置和引爆逻辑
# 放置一个充电包，再次按下发射键时引爆，或延迟后自动爆炸


## 充电包物体场景预加载
var chargePackObj = preload("res://scene/chargePackObj.tscn")

## 当前放置的充电包（用于再次按下时引爆）
var currentChargePack: Node = null


## 放置或引爆充电包
# 如果已放置充电包且存在，引爆它；否则放置一个新的充电包
# @param _v 放置方向（Vector2，未使用）
func fire(_v):
	if ammoNum <= 0:
		return

	# 如果已有充电包，引爆它
	if currentChargePack != null && is_instance_valid(currentChargePack):
		currentChargePack.addExplosion()
		currentChargePack = null
		return

	# 放置新的充电包
	var pos = global_position
	
	if !MapData.checkHasMapItem(pos):
		var temp = chargePackObj.instantiate()
		
		# 将位置对齐到网格
		temp.global_position = Vector2(floori(pos.x / MapData.cellSize) * MapData.cellSize, \
				floori(pos.y / MapData.cellSize) * MapData.cellSize) + \
				Vector2(MapData.cellSize / 2, MapData.cellSize / 2)
		
		# 设置Z轴顺序
		temp.z_index = floori(pos.y / MapData.cellSize)
		
		# 设置伤害值
		temp.damage = damage
		
		get_tree().root.add_child(temp)
		
		# 记录到地图物品列表
		MapData.addMapItem(pos, temp.get_instance_id())
		
		# 播放放置音效
		sound.play()
		ammoNum -= 1
		
		# 保存引用以便后续引爆
		currentChargePack = temp
