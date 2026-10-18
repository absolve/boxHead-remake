extends PopupPanel

## 关于弹窗：原版信息 + 本项目说明
##
## 挂在欢迎页里，点「关于」弹出，点返回或按 Esc 关闭。

## 返回按钮
@onready var btnBack: Button = $margin/content/btnBack


func _ready() -> void:
	btnBack.pressed.connect(onBackPressed)


## 关闭弹窗
func onBackPressed() -> void:
	SoundUtil.playClick()
	hide()


## 打开弹窗并居中
func showAbout() -> void:
	popup_centered()
