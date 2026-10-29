extends Control

## 角色选择卡片脚本
# 实现玩家角色的选择界面，支持左右切换角色


## 玩家ID（用于区分玩家1-4）
@export var ids: int = 1:
	set(v):
		ids = v

## 角色名称
@export var charName: String = ''


## 当前选中的角色索引
var index: int = 0
## 玩家角色列表
var player: Array = []


## 头像节点
@onready var img: TextureRect = $img
## ID显示节点
@onready var idNode: Label = $id
## 名称显示节点
@onready var nameNode: Label = $name


## 初始化
func _ready() -> void:
	# 设置ID显示
	idNode.text = str(ids)

	# 加载所有可用玩家角色
	for i in Game.playerName:
		var temp = load(i.img)
		player.append({'id': i.id, 'name': i.name, 'img': temp})

	# 每张卡默认显示不同角色：卡片编号 1..4 对应角色列表里第 1..4 个
	index = wrapi(ids - 1, 0, player.size())

	# 显示当前选中角色的信息
	showInfo()


## 显示本槽位的角色（"1P" / "2P" / "CPU" / "—"）；未启用时整张卡变暗
func setSlotRole(text: String, enabled: bool) -> void:
	if idNode == null:
		return
	idNode.text = text
	modulate.a = 1.0 if enabled else 0.4


## 显示角色信息
# 更新头像和名称显示
func showInfo() -> void:
	nameNode.text = str(player[index].name)
	img.texture = player[index].img


## 上一个角色按钮点击回调
# 切换到上一个角色
func _on_btn_prev_pressed() -> void:
	index = wrapi(index - 1, 0, player.size())
	showInfo()
	SoundUtil.playClick()


## 下一个角色按钮点击回调
# 切换到下一个角色
func _on_btn_next_pressed() -> void:
	index = wrapi(index + 1, 0, player.size())
	showInfo()
	SoundUtil.playClick()
