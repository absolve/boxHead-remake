extends AnimatedSprite2D

## 烟雾效果脚本
# 实现不同类型的烟雾粒子效果
# 动画播放完毕后自动销毁


## 爆炸烟团的 15 帧（原版 Effect.SmokeCloud 的源符号，128×128，25fps 播完 0.6s）
const BURST_FRAMES: Array[Texture2D] = [
	preload("res://sprite/fx/DefineSprite_626/1.png"),
	preload("res://sprite/fx/DefineSprite_626/2.png"),
	preload("res://sprite/fx/DefineSprite_626/3.png"),
	preload("res://sprite/fx/DefineSprite_626/4.png"),
	preload("res://sprite/fx/DefineSprite_626/5.png"),
	preload("res://sprite/fx/DefineSprite_626/6.png"),
	preload("res://sprite/fx/DefineSprite_626/7.png"),
	preload("res://sprite/fx/DefineSprite_626/8.png"),
	preload("res://sprite/fx/DefineSprite_626/9.png"),
	preload("res://sprite/fx/DefineSprite_626/10.png"),
	preload("res://sprite/fx/DefineSprite_626/11.png"),
	preload("res://sprite/fx/DefineSprite_626/12.png"),
	preload("res://sprite/fx/DefineSprite_626/13.png"),
	preload("res://sprite/fx/DefineSprite_626/14.png"),
	preload("res://sprite/fx/DefineSprite_626/15.png"),
]


## 烟雾类型（Game.smokeType枚举值）
@export var type: Game.smokeType = Game.smokeType.RocketSmoke

## 颜色：默认原色；>1 的份量会提亮（墙被打爆用 2 倍接近白色，油桶用默认灰）
@export var tint: Color = Color.WHITE


## 初始化
func _ready() -> void:
	modulate = tint

	# 根据烟雾类型设置不同的动画和属性
	if type == Game.smokeType.RocketSmoke:
		play("0")
	elif type == Game.smokeType.SmokeCloud:
		# 烟雾云：缩小尺寸并上移
		scale = Vector2(0.2, 0.2)
		position.y -= 10
		play("1")
	elif type == Game.smokeType.ExplosionSmoke:
		sprite_frames = _buildBurstFrames()
		play("burst")

	# 动画播放完毕后销毁
	await animation_finished
	queue_free()


## 15 帧烟团：场景里的 SpriteFrames 只放了两种动画，这个按需拼出来
func _buildBurstFrames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("burst")
	sf.set_animation_loop("burst", false)
	sf.set_animation_speed("burst", 25.0)   # 原版每个 25Hz tick 一帧
	for tex in BURST_FRAMES:
		sf.add_frame("burst", tex)
	return sf
