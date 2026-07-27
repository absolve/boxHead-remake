extends "res://script/item.gd"

## 爆炸效果脚本
# 继承自item.gd，实现爆炸的伤害范围和动画逻辑
# 爆炸会对范围内的所有角色和可破坏物品造成伤害


## 伤害值
@export var damage = 0
## 爆炸类型
var explosionType = Game.explosionType.normal
## 已处理碰撞的对象列表（避免重复伤害）
var excludeObj = []
@export var wRange = 0

## 初始化
func _ready() -> void:
	# 根据爆炸类型播放对应动画
	if explosionType == Game.explosionType.normal:
		ani.play("0")
	elif explosionType == Game.explosionType.air:
		ani.play("1")
	
	# 播放爆炸音效
	SfxManage.playExplosion()
	
	# 动画播放完毕后销毁
	await ani.animation_finished
	queue_free()


## 物理帧更新
# 在爆炸持续期间检测周围的碰撞对象并造成伤害
func _physics_process(_delta: float) -> void:
	var r = get_overlapping_areas()
	if r:
		for i in r:
			if i.get("type") && i.type in [Game.itemType.Barrel,
								Game.itemType.Wall]:
				# 可破坏物品
				if !excludeObj.has(i.get_rid()):
					i.hit(damage)
					excludeObj.append(i.get_rid())
			elif i.owner.type && i.owner.type in [Game.roleType.Player,
				Game.roleType.Zombie, Game.roleType.Devil]:
				# 角色
				if !excludeObj.has(i.get_rid()):
					i.owner.hit(damage, global_position, 0)
					excludeObj.append(i.get_rid())
