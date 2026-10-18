extends Control

## 操作说明界面
##
## 静态文本，按 P1 的默认按键列出玩法要点。原版 Boxhead 的操作很简单，
## 这里只列出真正会影响操作的部分。

## 返回按钮
@onready var btnBack: Button = $panel/btnBack


func _ready() -> void:
	btnBack.pressed.connect(onBackPressed)


## 返回主菜单
func onBackPressed() -> void:
	SoundUtil.playClick()
	SceneTransition.changeScene("res://scene/welcome.tscn")
