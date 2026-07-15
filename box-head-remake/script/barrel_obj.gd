extends "res://script/item.gd"

## 油桶物体脚本
# 继承自item.gd，实现油桶的逻辑
# 被击中时会爆炸，支持分裂成多个小爆炸


## 伤害值
@export var damage = 0

## 爆炸效果场景预加载
var explosion = preload("res://scene/explosion.tscn")

## 是否正在爆炸中
var startExploding = false

## 分裂爆炸数量
var splitExplosion = 0


## 初始化
func _ready():
	pass


## 武器升级处理
# 根据武器类型更新油桶属性
# @param _type 武器类型（Game.weaponType枚举值）
func weaponUpgrade(_type):
	if _type == Game.weaponType.Barrel:
		splitExplosion = MapData.allWeaponData.type['splitExplosion']
		damage = MapData.allWeaponData.type['damage']


## 受伤处理
# 被击中后触发爆炸
# @param _value 伤害值（int）
func hit(_value):
	if startExploding:
		return
	
	startExploding = true
	
	# 延迟3帧后爆炸
	for i in range(3):
		await get_tree().physics_frame
	
	# 创建主爆炸
	var temp = explosion.instantiate()
	temp.global_position = global_position
	temp.damage = damage
	get_tree().root.add_child(temp)
	
	# 如果配置了分裂爆炸，创建多个小爆炸
	if splitExplosion > 0:
		for i in range(splitExplosion):
			var t = explosion.instantiate()
			t.damage = damage
			t.global_position = global_position + Vector2.RIGHT.rotated(i * ((2 * PI) / splitExplosion)) * 15
			get_tree().root.add_child(t)
			for z in range(3):
				await get_tree().physics_frame
	
	# 销毁油桶
	queue_free()