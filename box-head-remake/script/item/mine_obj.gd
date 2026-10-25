extends "res://script/item/item.gd"

## 地雷物体脚本
# 继承自item.gd，实现地雷的逻辑
# 放置后等待敌人触碰，触碰后延迟爆炸，支持分裂成多个小爆炸


## 伤害值
@export var damage: int = 0

@export var wRange: int = 0


## 爆炸延迟时间（秒）
var delay: float = 1

## 动画补间节点
var tween: Tween = null

## 分裂爆炸数量
var splitExplosion: int = 0

## 分裂半径
var splitRadius: int = 80

## 爆炸效果场景预加载
var explosion: PackedScene = preload("res://scene/fx/explosion.tscn")

## 手榴弹物体场景预加载（用于分裂爆炸）
var grenadeObj: PackedScene = preload("res://scene/projectile/grenade_obj.tscn")


## 音效节点
@onready var sound: AudioStreamPlayer2D = $sound


## 初始化
func _ready() -> void:
	# 连接武器升级信号
	Game.weaponUpgrade.connect(weaponUpgrade)


## 武器升级处理
# 根据武器类型更新地雷属性
# @param weaponType 武器类型（Game.weaponType枚举值）
func weaponUpgrade(weaponType: int) -> void:
	if weaponType == Game.weaponType.Mine:
		var d: Dictionary = MapData.allWeaponData[Game.weaponType.Mine]
		damage = d['damage']
		splitExplosion = d.get('splitExplosion', 0)
		biggerBang = d.get('biggerBang', 0)
		clusterExplode = d.get('clusterExplode', 0)


## 添加爆炸效果
# 创建爆炸并处理分裂效果
func addExplosion() -> void:
	# 创建主爆炸
	var temp = explosion.instantiate()
	temp.global_position = global_position
	temp.damage = damage
	temp.biggerBang = biggerBang
	temp.clusterExplode = clusterExplode
	get_tree().current_scene.add_child(temp)

	# 如果配置了分裂爆炸，创建多个手榴弹向四周飞散
	if splitExplosion > 0:
		for i in range(splitExplosion):
			var t = grenadeObj.instantiate()
			t.global_position = global_position - Vector2(0, 32)
			t.damage = damage
			t.biggerBang = 0
			t.clusterExplode = 0
			var angle = Vector2.RIGHT.rotated(2 * PI / splitExplosion * i)
			t.vector = angle.normalized()
			t.speed = 50
			get_tree().current_scene.add_child(t)


## 物体进入碰撞区域时触发
# 播放音效并延迟爆炸
# @param _body 进入的物体节点
func _on_body_entered(_body: Node2D) -> void:
	if tween == null:
		sound.play()
		tween = create_tween()
		# 加速动画
		tween.tween_property(ani, "speed_scale", 4, 0)
		# 延迟爆炸
		tween.tween_interval(delay)
		# 触发爆炸
		tween.tween_callback(addExplosion)
		# 销毁地雷
		tween.tween_callback(queue_free)
