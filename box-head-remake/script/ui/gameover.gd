extends Node2D


## 结算音效
@onready var sound: AudioStreamPlayer2D = $sound
## 分数标签
@onready var scoreLabel: Label = $Control/score
## 菜单项：select new Level / retry / back to menu
@onready var levelLabel: Control = $Control/UILabel
@onready var retryLabel: Control = $Control/UILabel2


func _ready() -> void:
	sound.play()

	# 本局真实得分（和游戏中一样的 14 位补零格式）
	scoreLabel.text = str(MapData.score)

	# 这两项的场景里没连信号，这里连
	levelLabel.gui_input.connect(onLevelPressed)
	retryLabel.gui_input.connect(onRetryPressed)


## 选择新关卡 → 选图界面
func onLevelPressed(event: InputEvent) -> void:
	if isLeftClick(event):
		SceneTransition.changeScene("res://scene/ui/map_select.tscn")


## 重试 → 重新开始当前地图
func onRetryPressed(event: InputEvent) -> void:
	if isLeftClick(event):
		SceneTransition.changeScene("res://scene/map.tscn")


## 返回主菜单（场景里已连接）
func _onBackMenuGuiInput(event: InputEvent) -> void:
	if isLeftClick(event):
		SceneTransition.changeScene("res://scene/welcome.tscn")


## 是否是鼠标左键按下
func isLeftClick(event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	return mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.is_pressed()
