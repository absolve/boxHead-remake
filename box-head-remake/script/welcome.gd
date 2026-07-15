extends Node2D

## 欢迎界面脚本
# 实现游戏的欢迎界面，包含开始按钮和操作说明按钮
# 支持按钮悬停动画效果


## 标题标签节点
@onready var label = $Control/vbox/Label

## 开始按钮节点
@onready var btn = $Control/vbox/btn_start

## 操作说明按钮节点
@onready var btn_instructions = $Control/vbox/btn_instructions

## 动画补间节点
var tween: Tween

## 按钮原始位置
var originalPos: Vector2

## 动画频率（秒）
var duration = 0.8

## 位置偏移量（像素）
var offset = 2

## 当前选中的按钮
var currBtn = null


## 初始化
func _ready():
	# 创建循环动画补间
	tween = create_tween()
	tween.set_loops()
	tween.tween_method(updatePos, null, null, duration)
	tween.stop()


## 更新位置（动画回调）
# 在按钮悬停时产生微小的随机抖动效果
# @param _progress 动画进度（0-1）
func updatePos(_progress):
	var random_x = randf_range(-offset, offset)
	var random_y = randf_range(-offset, offset)
	currBtn.position = originalPos + Vector2(random_x, random_y)


## 标题标签鼠标进入回调（预留）
func _on_label_mouse_entered():
	pass


## 标题标签鼠标离开回调（预留）
func _on_label_mouse_exited():
	pass


## 开始按钮鼠标进入回调
# 启动按钮抖动动画
func _on_button_mouse_entered() -> void:
	if tween != null:
		tween.stop()
	originalPos = btn.position
	currBtn = btn
	tween.bind_node(btn)
	tween.play()


## 开始按钮鼠标离开回调
# 停止抖动动画并恢复原始位置
func _on_button_mouse_exited() -> void:
	if tween != null:
		tween.stop()
	btn.position = originalPos


## 操作说明按钮鼠标进入回调
# 启动按钮抖动动画
func _on_btn_instructions_mouse_entered():
	if tween != null:
		tween.stop()
	originalPos = btn_instructions.position
	currBtn = btn_instructions
	tween.bind_node(btn_instructions)
	tween.play()


## 操作说明按钮鼠标离开回调
# 停止抖动动画并恢复原始位置
func _on_btn_instructions_mouse_exited():
	if tween != null:
		tween.stop()
	btn_instructions.position = originalPos


## 开始按钮点击回调
# 播放音效并切换到地图选择场景
func _on_btn_start_pressed():
	SoundUtil.playChange()
	get_tree().change_scene_to_file("res://scene/map_select.tscn")