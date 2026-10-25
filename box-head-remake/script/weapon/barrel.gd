extends "res://script/weapon/weapon.gd"

## 油桶武器脚本
##
## 在玩家所在格放一个油桶：对齐到格子中心，登记格子占用，
## 并把这一格写成流场障碍（僵尸会绕开它），油桶被引爆后自动从流场摘掉。
##
## 旧实现的问题：计算放置位置时对齐了格子，但登记占用/障碍用的是**玩家未对齐的
## 世界坐标**，玩家站在格子边缘时登记的就不是油桶真正所在的格子。


## 油桶物体场景预加载
var barrelObj: PackedScene = preload("res://scene/item/barrel_obj.tscn")

## 分裂爆炸数量
var splitExplosion: int = 0


## 放置油桶
# @param _v 放置方向（Vector2，未使用）
func fire(_v: Vector2) -> void:
	if ammoNum <= 0:
		return

	# 统一用"目标格子"做所有判断与登记，避免对齐前后不一致
	var cell: Vector2i = MapData.worldToCell(global_position)
	var center: Vector2 = MapData.cellCenter(cell)

	# 该格已经是障碍或已有物品 → 放不下
	if MapData.isObstacle(cell) or MapData.checkHasMapItem(center):
		return

	var temp = barrelObj.instantiate()
	temp.global_position = center
	temp.z_index = cell.y
	temp.damage = damage
	temp.biggerBang = biggerBang
	temp.clusterExplode = clusterExplode
	temp.splitExplosion = splitExplosion
	# 标记为"阻挡寻路"，并记下格子，销毁时由 item._exit_tree 自动摘除
	temp.fromWeapon = true
	temp.blocksPath = true
	temp.cell = cell

	get_tree().current_scene.add_child(temp)

	MapData.addMapItem(center, temp.get_instance_id())
	MapData.addObstacleAt(cell)

	sound.play()
	ammoNum -= 1
