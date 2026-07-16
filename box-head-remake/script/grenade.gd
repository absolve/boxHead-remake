extends "res://script/weapon.gd"

## 手榴弹武器脚本
# 继承自weapon.gd，实现手榴弹的投掷逻辑
# 按住发射键蓄力，松开后扔出，手榴弹会弹跳并延迟爆炸


## 手榴弹物体场景预加载
var grenadeObj = preload("res://scene/grenade_obj.tscn")

## 蓄力速度增量
var speedIncrement = 20

## 当前投掷速度
var speed = 60

## 最大投掷速度
var maxSpeed = 2500

## 最小投掷速度
var minSpeed = 60

## 投掷高度偏移
var height = 25


## 初始化
func _ready():
	pass


## 投掷手榴弹
# 释放手榴弹实体，根据蓄力速度决定投掷距离
# @param _v 投掷方向（Vector2）
func fire(_v):
	if ammoNum <= 0:
		return
	
	ammoNum -= 1
	vector = _v
	
	# 创建手榴弹实例
	var temp = grenadeObj.instantiate()
	temp.vector = vector.normalized()
	temp.speed = speed
	temp.global_position = global_position - Vector2(0, height)
	temp.collision_mask = collisionMask
	temp.ownerId = ownerId
	temp.damage = damage
	
	# 重置投掷速度
	speed = minSpeed
	
	get_tree().root.add_child(temp)


## 蓄力增加速度
# 在按住发射键时调用，增加投掷速度直到达到最大值
func increase():
	speed += speedIncrement
	speed = min(speed, maxSpeed)
