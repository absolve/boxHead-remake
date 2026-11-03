extends CanvasLayer

## 暂停层
##
## ESC（项目设置里的 `pause` 动作）切换暂停：
##   - 暂停时 `get_tree().paused = true`，游戏逻辑全停
##   - 本节点 `process_mode = ALWAYS`，所以自身仍能接收输入
## 原版没有显式暂停菜单，这里是全屏遮罩 + 文字 + 两个按钮（继续 / 返回主菜单）。
## 按钮是代码里建的，不占场景文件，改样式直接改 `_makeButton()`。


## 遮罩
var overlay: ColorRect
## 提示文字
var label: Label
## 按钮容器（只在暂停时显示）
var buttons: VBoxContainer


func _ready() -> void:
	# 暂停时自己还要跑，否则按 ESC 无法恢复
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95

	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	label = Label.new()
	label.text = "%s\n\n%s" % [tr("PAUSED"), tr("ESC to resume")]
	label.add_theme_font_size_override("font_size", 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(label)

	buttons = VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	buttons.offset_top = -140.0
	buttons.offset_left = -110.0
	buttons.offset_right = 110.0
	buttons.offset_bottom = -20.0
	add_child(buttons)

	var resumeBtn := _makeButton(tr("Resume"))
	resumeBtn.pressed.connect(func() -> void: setPaused(false))
	buttons.add_child(resumeBtn)

	var menuBtn := _makeButton(tr("Main Menu"))
	menuBtn.pressed.connect(goToMainMenu)
	buttons.add_child(menuBtn)

	overlay.visible = false
	label.visible = false
	buttons.visible = false


## 生成一个菜单按钮（沿用项目主题，尺寸统一）
func _makeButton(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 44)
	b.focus_mode = Control.FOCUS_ALL
	return b


## 返回主菜单：必须先解除暂停，否则换场景后 get_tree().paused 仍是 true，
## 新场景会一进场就冻住
func goToMainMenu() -> void:
	setPaused(false)
	SceneTransition.changeScene("res://scene/welcome.tscn")


## 切换暂停
func toggle() -> void:
	setPaused(not get_tree().paused)


## 设置暂停状态
func setPaused(on: bool) -> void:
	get_tree().paused = on
	overlay.visible = on
	label.visible = on
	buttons.visible = on
	# 键盘/手柄也能直接选：暂停时把焦点给"继续"按钮
	if on:
		buttons.get_child(0).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()
