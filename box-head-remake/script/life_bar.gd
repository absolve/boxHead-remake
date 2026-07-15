extends Control

## 血条UI脚本
# 实现角色血条的显示和动画效果
# 血量变化时显示，一段时间后自动隐藏


## 纹理进度条节点
@onready var bar = $TextureProgressBar

## 计时器节点（用于控制血条显示时长）
@onready var timer = $Timer

## 动画补间节点
var tween: Tween = null

## 是否始终显示血条
var alwaysShows = false


## 当前血量
# 设置时自动更新进度条并显示血条
@export var hp = 10:
	set(val):
		hp = val
		bar.value = val
		if hp > 0:
			showLifeBar()


## 最大血量
# 设置时自动更新进度条最大值
@export var maxHp = 10:
	set(val):
		maxHp = val
		bar.max_value = val


## 初始化
func _ready() -> void:
	# 设置进度条初始值
	bar.max_value = hp
	bar.value = hp
	
	# 初始化血条显示状态
	showLifeBar()


## 显示血条
# 重置显示状态并启动计时器
func showLifeBar():
	# 如果已有补间动画，停止它
	if tween != null && tween.is_valid():
		tween.kill()
	
	# 设置血条为完全不透明
	bar.modulate.a = 1
	
	# 启动计时器
	timer.start()


## 计时器超时回调
# 创建淡出动画，血条逐渐消失
func _on_timer_timeout() -> void:
	tween = create_tween()
	tween.tween_property(bar, "modulate:a", 0, 0.5)