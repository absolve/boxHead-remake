extends "res://script/weapon/weapon.gd"

## 墙壁武器脚本
##
## 在玩家所在格放一堵墙：对齐到格子中心，登记格子占用，
## 并把这一格写成流场障碍（僵尸会绕开它），墙被打碎后自动从流场摘掉。
##
## 与油桶一致：判定/登记/障碍全部用同一个"目标格子"，不再混用未对齐的世界坐标。


## 墙壁物体场景预加载
var wallObj = preload("res://scene/item/wall_obj.tscn")


## 放置墙壁
# @param _v 放置方向（Vector2，未使用）
func fire(_v):
	if ammoNum <= 0:
		return

	var cell: Vector2i = MapData.worldToCell(global_position)
	var center: Vector2 = MapData.cellCenter(cell)

	if MapData.isObstacle(cell) or MapData.checkHasMapItem(center):
		return

	var temp = wallObj.instantiate()
	temp.global_position = center
	temp.z_index = cell.y
	temp.blocksPath = true
	temp.cell = cell

	get_tree().current_scene.add_child(temp)

	MapData.addMapItem(center, temp.get_instance_id())
	MapData.addObstacleAt(cell)

	sound.play()
	ammoNum -= 1
