extends "res://script/item.gd"

## 充电包物体脚本
# 继承自item.gd，实现充电包的逻辑
# 放置后可以手动引爆，或延迟后自动爆炸，支持分裂成多个小爆炸


## 音效节点
@onready var sound = $sound

## 伤害值
@export var damage = 0

## 爆炸延迟时间（秒）
var delay = 1

## 动画补间节点
var tween: Tween = null

## 分裂爆炸数量
var splitExplosion = 0

## 分裂半径
var splitRadius = 30

## 爆炸效果场景预加载
var explosion = preload("res://scene/explosion.tscn")

## 手榴弹物体场景预加载（用于分裂爆炸）
var grenadeObj = preload("res://scene/grenade_obj.tscn")


## 初始化
func _ready() -> void:
	# 连接武器升级信号
	Game.weaponUpgrade.connect(weaponUpgrade)


## 武器升级处理
# 根据武器类型更新充电包属性
# @param _type 武器类型（Game.weaponType枚举值）
func weaponUpgrade(_type):
	if _type == Game.weaponType.ChargePack:
		splitExplosion = MapData.allWeaponData._type['splitExplosion']
		damage = MapData.allWeaponData.type['damage']


## 添加爆炸效果
# 创建爆炸并处理分裂效果，然后销毁自身
func addExplosion():
	# 创建主爆炸
	var temp = explosion.instantiate()
	temp.global_position = global_position
	temp.damage = damage
	get_tree().root.add_child(temp)
	
	# 如果配置了分裂爆炸，创建多个手榴弹向四周飞散
	if splitExplosion > 0:
		for i in range(splitExplosion):
			var t = grenadeObj.instantiate()
			t.global_position = global_position - Vector2(0, 32)
			t.damage = damage
			var angle = Vector2.RIGHT.rotated(2 * PI / splitExplosion * i)
			t.vector = angle.normalized()
			t.speed = 50
			get_tree().root.add_child(t)
	
	# 销毁充电包
	queue_free()