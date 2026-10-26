extends "res://script/item/item.gd"

## 墙壁物体脚本
# 继承自item.gd，实现可破坏墙壁的逻辑
# 墙壁有血量，被击中后血量减少，血量归零后销毁并产生烟雾


## 墙壁血量
var hp: int = 10

## 烟雾效果场景预加载
var smoke: PackedScene = preload("res://scene/fx/smoke.tscn")


## 受伤处理
# 减少血量，血量归零后销毁墙壁
# @param damage 伤害值（int）
## 受击；签名与角色一致（爆炸会传 4 个参数，其余忽略）
func hit(damage: int, _attackPos: Vector2 = Vector2.ZERO,
		_knockDir: Vector2 = Vector2.ZERO, _fromExplosion: bool = false) -> void:
	hp -= damage

	if hp <= 0:
		# 创建烟雾效果
		var temp = smoke.instantiate()
		temp.global_position = global_position
		get_tree().current_scene.add_child(temp)

		# 销毁墙壁
		queue_free()

	# 更新墙壁损坏动画帧
	ani.frame = wrapi(10 - hp, 0, 10)
