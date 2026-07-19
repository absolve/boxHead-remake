extends AnimatedSprite2D

## 烟雾效果脚本
# 实现不同类型的烟雾粒子效果
# 动画播放完毕后自动销毁


## 烟雾类型（Game.smokeType枚举值）
@export var type: Game.smokeType = Game.smokeType.RocketSmoke


## 初始化
func _ready() -> void:
	# 根据烟雾类型设置不同的动画和属性
	if type == Game.smokeType.RocketSmoke:
		play("0")
	elif type == Game.smokeType.SmokeCloud:
		# 烟雾云：缩小尺寸并上移
		scale = Vector2(0.2, 0.2)
		position.y -= 10
		play("1")
	
	# 动画播放完毕后销毁
	await animation_finished
	queue_free()
