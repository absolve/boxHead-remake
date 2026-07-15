extends Control

## 角色选择卡片脚本
# 实现玩家角色的选择界面，支持左右切换角色


## 头像节点
@onready var img = $img

## ID显示节点
@onready var idNode = $id

## 名称显示节点
@onready var nameNode = $name


## 玩家ID（用于区分玩家1-4）
@export var ids = 1:
	set(v):
		ids = v

## 角色名称
@export var charName = ''

## 当前选中的角色索引
var index = 0

## 玩家角色列表
var player = []


## 初始化
func _ready() -> void:
	# 设置ID显示
	idNode.text = str(ids)
	
	# 加载所有可用玩家角色
	for i in Game.playerName:
		var temp = load(i.img)
		player.append({'id': i.id, 'name': i.name, 'img': temp})
	
	# 显示当前选中角色的信息
	showInfo()


## 显示角色信息
# 更新头像和名称显示
func showInfo():
	nameNode.text = str(player[index].name)
	img.texture = player[index].img


## 上一个角色按钮点击回调
# 切换到上一个角色
func _on_btn_prev_pressed():
	index = wrapi(index - 1, 0, player.size())
	showInfo()
	SoundUtil.playClick()


## 下一个角色按钮点击回调
# 切换到下一个角色
func _on_btn_next_pressed():
	index = wrapi(index + 1, 0, player.size())
	showInfo()
	SoundUtil.playClick()