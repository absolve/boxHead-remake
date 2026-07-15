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
	get_tree().change_scene_to_file("res://scene/welcome.tscn")