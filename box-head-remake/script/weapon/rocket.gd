extends "res://script/weapon/weapon.gd"

## 火箭发射器脚本
# 继承自weapon.gd，实现火箭发射器的发射逻辑
# 发射火箭弹实体，火箭弹会飞行并在碰撞时爆炸


## 火箭弹场景预加载
var bullet: PackedScene = preload("res://scene/projectile/rocket_bullet.tscn")


## 初始化
func _ready() -> void:
	# 8 方向枪口 = 原版 XSI 枪口锚点（rocketstand，16 方向取 dir = angle×2）+ 脚底锚点偏移 (0,3)
	# 重生成：doc/tools/gen_offset_dir.py；推导记于 doc/xsi-sprite-skins.md §8
	offsetDir[0] = Vector2(25, -14)
	offsetDir[1] = Vector2(10, -4)
	offsetDir[2] = Vector2(-11, -4)
	offsetDir[3] = Vector2(-25, -14)
	offsetDir[4] = Vector2(-25, -29)
	offsetDir[5] = Vector2(-10, -40)
	offsetDir[6] = Vector2(11, -39)
	offsetDir[7] = Vector2(25, -29)


## 射击
# 发射火箭弹实体
# @param v 发射方向（Vector2）
func fire(v: Vector2) -> void:
	if ammoNum <= 0:
		return
	if canShoot:
		ammoNum -= 1
		canShoot = false
		timer.start(delay)
		sound.play()
		vector = v

		# 创建火箭弹实例
		var temp = bullet.instantiate()
		temp.vector = vector

		# 根据方向计算发射位置偏移
		var offset = offsetDir[dirIdx(vector)]
		temp.global_position = global_position + offset
		# 必须带上发射者：朝脚下发射时枪口就贴在玩家受击框上，
		# 不排除的话火箭弹第一帧就会判到自己而直接爆炸
		temp.ownerId = ownerId
		temp.damage = damage
		temp.biggerBang = biggerBang
		temp.clusterExplode = clusterExplode

		get_tree().current_scene.add_child(temp)
