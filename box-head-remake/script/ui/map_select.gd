extends Node2D

## 地图选择界面脚本
# 实现地图选择界面，支持左右切换地图、查看地图预览和名称


## 地图图片列表
var img: Array = []
## 当前选中的地图索引
var index: int = 0


## 槽位角色下拉框的文字（下标 = MapData.SLOT_*）
const ROLE_TEXT: Array[String] = ["关闭", "1P", "2P", "CPU"]
## 卡片上显示的文字：关闭的槽位显示 "—"
const CARD_TEXT: Array[String] = ["—", "1P", "2P", "CPU"]


## 设置弹窗节点
@onready var setting: PopupPanel = $gameSetting
## 四个玩家槽位的角色下拉框
@onready var slotButtons: Array = [
	$Control/slot1, $Control/slot2, $Control/slot3, $Control/slot4,
]

## 四张角色卡（显示槽位角色 + 选角色）
@onready var cards: Array = [
	$Control/characterCard, $Control/characterCard2,
	$Control/characterCard3, $Control/characterCard4,
]

## 地图预览图节点
@onready var mapImg: TextureRect = $Control/mapImg
## 地图名称显示节点
@onready var mapName: Label = $Control/mapName
## 地图索引显示节点
@onready var mapIndex: Label = $Control/mapIndex


## 初始化
func _ready() -> void:
	# 加载所有地图预览图
	for i in Game.mapId:
		var temp = load(i.img)
		img.append({'id': i.id, 'img': temp, 'name': i.name})

	# 显示当前选中地图的信息
	showMapInfo()
	# 玩家槽位（1P / 2P / CPU）下拉框
	initSlots()
	# 点击预览图 / 按回车 开始游戏
	if mapImg is Control:
		mapImg.gui_input.connect(onMapImgGuiInput)


## 初始化 4 个槽位的下拉框，并回填 MapData 里的选择
func initSlots() -> void:
	for i in slotButtons.size():
		var b: OptionButton = slotButtons[i]
		b.clear()
		for role in ROLE_TEXT.size():
			b.add_item(ROLE_TEXT[role], role)
		b.select(b.get_item_index(MapData.playerSlots[i]))
		b.item_selected.connect(_onSlotRoleSelected.bind(i))
	refreshSlotCards()


## 槽位角色改变：1P / 2P 全局唯一，且至少保留一个人类
func _onSlotRoleSelected(itemIdx: int, slot: int) -> void:
	var role: int = slotButtons[slot].get_item_id(itemIdx)

	# 其他槽位上的人类数量（1P + 2P）
	var humansOther := 0
	for i in MapData.playerSlots.size():
		if i == slot:
			continue
		var r: int = MapData.playerSlots[i]
		if r == MapData.SLOT_P1 or r == MapData.SLOT_P2:
			humansOther += 1

	# 不允许把最后一个人类关掉
	if role == MapData.SLOT_OFF and humansOther == 0:
		slotButtons[slot].select(slotButtons[slot].get_item_index(MapData.playerSlots[slot]))
		return

	# 1P / 2P 已经被别的槽位占着：对方让位（它是唯一人类时改成交换）
	if role == MapData.SLOT_P1 or role == MapData.SLOT_P2:
		for i in MapData.playerSlots.size():
			if i != slot and MapData.playerSlots[i] == role:
				MapData.playerSlots[i] = MapData.playerSlots[slot] if humansOther <= 1 \
						else MapData.SLOT_OFF

	MapData.playerSlots[slot] = role
	MapData.normalizeSlots()
	syncSlotButtons()
	refreshSlotCards()
	SoundUtil.playClick()


## 把 MapData 里的槽位选择刷新到下拉框（select 不会触发 item_selected，不会递归）
func syncSlotButtons() -> void:
	for i in slotButtons.size():
		var b: OptionButton = slotButtons[i]
		b.select(b.get_item_index(MapData.playerSlots[i]))


## 卡片上显示 1P / 2P / CPU / —
func refreshSlotCards() -> void:
	for i in cards.size():
		var role: int = MapData.playerSlots[i]
		cards[i].setSlotRole(CARD_TEXT[role], role != MapData.SLOT_OFF)


## 显示地图信息
# 更新地图预览图、名称和索引显示
func showMapInfo() -> void:
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


## 开始游戏：记录选择并切到游戏场景
func startGame() -> void:
	MapData.selectedMapId = int(img[index].id)
	# 槽位 + 每张卡选的角色（角色目前只影响界面展示，游戏内仍按槽位换色）
	MapData.normalizeSlots()
	for i in cards.size():
		MapData.playerSlotChars[i] = int(cards[i].index)
	MapData.playerCount = MapData.playerSlotTotal()
	SoundUtil.playChange()
	SceneTransition.changeScene("res://scene/map.tscn")


## 操作说明按钮：弹出说明弹窗
func _on_btn_control_pressed() -> void:
	SoundUtil.playClick()
	var panel = get_node_or_null("instructionsPanel")
	if panel != null:
		panel.popup_centered()


## 回车 / 空格也能开始
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER \
				or event.keycode == KEY_SPACE:
			startGame()
