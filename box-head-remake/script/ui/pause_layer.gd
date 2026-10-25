extends CanvasLayer

## 暂停层
##
## ESC（项目设置里的 `pause` 动作）切换暂停：
##   - 暂停时 `get_tree().paused = true`，游戏逻辑全停
##   - 本节点 `process_mode = ALWAYS`，所以自身仍能接收输入
## 原版没有显式暂停菜单，这里用最简单的全屏遮罩 + 文字。


## 遮罩
var overlay: ColorRect

## 提示文字
var label: Label


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
	label.text = "PAUSED\n\nESC 继续"
	label.add_theme_font_size_override("font_size", 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(label)

	overlay.visible = false
	label.visible = false


## 切换暂停
func toggle() -> void:
	setPaused(not get_tree().paused)


## 设置暂停状态
func setPaused(on: bool) -> void:
	get_tree().paused = on
	overlay.visible = on
	label.visible = on


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()
