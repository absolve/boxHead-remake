extends Node2D

## 欢迎界面脚本
# 实现游戏的欢迎界面，包含开始按钮和操作说明按钮
# 支持按钮悬停动画效果


## 动画补间节点
var tween: Tween
## 按钮原始位置
var originalPos: Vector2
## 动画频率（秒）
var duration: float = 0.8
## 位置偏移量（像素）
var offset: int = 2
## 当前选中的按钮
var currBtn: Button = null


## 开始按钮节点
@onready var btn: Button = $Control/vbox/btn_start
## 操作说明按钮节点
@onready var btnInstructions: Button = $Control/vbox/btn_instructions
## 关于按钮节点
@onready var btnAbout: Button = $Control/vbox/btn_about
## 按键设置按钮节点
@onready var btnKeybind: Button = $Control/vbox/btn_keybind
## 关于弹窗（场景里的子节点）
@onready var aboutPanel: PopupPanel = $aboutPanel
## 操作说明弹窗（场景里的子节点）
@onready var instructionsPanel: PopupPanel = $instructionsPanel


## 初始化
func _ready() -> void:
	# 创建循环动画补间（from/to 必须是数值，传 null 会让回调收到 Nil）
	tween = create_tween()
	tween.set_loops()
	tween.tween_method(updatePos, 0.0, 1.0, duration)
	tween.stop()


## 更新位置（动画回调）
# 在按钮悬停时产生微小的随机抖动效果
# @param _progress 动画进度（0-1）
func updatePos(_progress: float) -> void:
	var randomX = randf_range(-offset, offset)
	var randomY = randf_range(-offset, offset)
	currBtn.position = originalPos + Vector2(randomX, randomY)


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
func _on_btn_instructions_mouse_entered() -> void:
	if tween != null:
		tween.stop()
	originalPos = btnInstructions.position
	currBtn = btnInstructions
	tween.bind_node(btnInstructions)
	tween.play()


## 操作说明按钮鼠标离开回调
# 停止抖动动画并恢复原始位置
func _on_btn_instructions_mouse_exited() -> void:
	if tween != null:
		tween.stop()
	btnInstructions.position = originalPos


## 开始按钮点击回调
# 播放音效并切换到地图选择场景
func _on_btn_start_pressed() -> void:
	SoundUtil.playChange()
	SceneTransition.changeScene("res://scene/ui/map_select.tscn")


## 操作说明按钮点击回调：弹出说明弹窗
func _on_btn_instructions_pressed() -> void:
	SoundUtil.playClick()
	instructionsPanel.popup_centered()


## 关于按钮点击回调：弹出关于弹窗
func _on_btn_about_pressed() -> void:
	SoundUtil.playClick()
	aboutPanel.popup_centered()


## 关于按钮鼠标进入：启动抖动
func _on_btn_about_mouse_entered() -> void:
	if tween != null:
		tween.stop()
	originalPos = btnAbout.position
	currBtn = btnAbout
	tween.bind_node(btnAbout)
	tween.play()


## 关于按钮鼠标离开：停止抖动并复位
func _on_btn_about_mouse_exited() -> void:
	if tween != null:
		tween.stop()
	btnAbout.position = originalPos


## 按键设置按钮：弹出改键面板
func _on_btn_keybind_pressed() -> void:
	SoundUtil.playClick()
	var panel = get_node_or_null("keyBindPanel")
	if panel != null:
		panel.popup_centered()


## 按键设置按钮鼠标进入：启动抖动
func _on_btn_keybind_mouse_entered() -> void:
	if tween != null:
		tween.stop()
	originalPos = btnKeybind.position
	currBtn = btnKeybind
	tween.bind_node(btnKeybind)
	tween.play()


## 按键设置按钮鼠标离开：停止抖动并复位
func _on_btn_keybind_mouse_exited() -> void:
	if tween != null:
		tween.stop()
	btnKeybind.position = originalPos
