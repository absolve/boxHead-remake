extends Node2D

## 地图选择界面脚本
# 实现地图选择界面，支持左右切换地图、查看地图预览和名称

## 设置弹窗节点
@onready var setting = $gameSetting
## 地图预览图节点
@onready var mapImg = $Control/mapImg
## 地图名称显示节点
@onready var mapName = $Control/mapName
## 地图索引显示节点
@onready var mapIndex = $Control/mapIndex


## 地图图片列表
var img = []

## 当前选中的地图索引
var index = 0


## 初始化
func _ready() -> void:
	# 加载所有地图预览图
	for i in Game.mapId:
		var temp = load(i.img)
		img.append({'id': i.id, 'img': temp, 'name': i.name})
	
	# 显示当前选中地图的信息
	showMapInfo()
	# 点击预览图 / 按回车 开始游戏
	if mapImg is Control:
		mapImg.gui_input.connect(onMapImgGuiInput)


## 显示地图信息
# 更新地图预览图、名称和索引显示
func showMapInfo():
	mapImg.texture = img[index].img
	mapName.text = str(img[index].name)
	mapIndex.text = "%s/%s" % [index + 1, img.size()]


## 地图预览图鼠标进入回调
# 改变图片颜色表示选中状态
func _on_map_img_mouse_entered() -> void:
	mapImg.modulate = Color("#e29999")


## 地图预览图鼠标离开回调
# 恢复图片颜色
func _on_map_img_mouse_exited() -> void:
	mapImg.modulate = Color.WHITE


## 上一张按钮点击回调
# 切换到上一张地图
func _on_btn_prev_pressed() -> void:
	index = wrapi(index - 1, 0, img.size())
	showMapInfo()
	SoundUtil.playClick()


## 下一张按钮点击回调
# 切换到下一张地图
func _on_btn_next_pressed() -> void:
	index = wrapi(index + 1, 0, img.size())
	showMapInfo()
	SoundUtil.playClick()


## 设置按钮点击回调
# 打开游戏设置弹窗
func _on_btn_option_pressed() -> void:
	SoundUtil.playClick()
	setting.popup_centered()


## 返回按钮点击回调
# 返回欢迎界面
func _on_btn_back_pressed() -> void:
	SoundUtil.playChange()
	SceneTransition.changeScene("res://scene/welcome.tscn")


## 点击地图预览图
func onMapImgGuiInput(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		startGame()


## 回车 / 空格也能开始
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER \
				or event.keycode == KEY_SPACE:
			startGame()


## 开始游戏：记录选择并切到游戏场景
func startGame() -> void:
	MapData.selectedMapId = int(img[index].id)
	SoundUtil.playChange()
	SceneTransition.changeScene("res://scene/map.tscn")


## 操作说明按钮：弹出说明弹窗
func _on_btn_control_pressed() -> void:
	SoundUtil.playClick()
	var panel = get_node_or_null("instructionsPanel")
	if panel != null:
		panel.popup_centered()
