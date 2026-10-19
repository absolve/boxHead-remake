extends PopupPanel

## 设置面板（样式与操作说明一致）
##
## 行在运行时生成，因为开关组数量固定但按钮状态要跟 mapConfig 同步。

## 行容器
@onready var list: VBoxContainer = $margin/content/scroll/list

## 标题
@onready var titleLabel: Label = $margin/content/title

## 重置按钮
@onready var btnReset: Button = $margin/content/btnRow/btnReset

## 关闭按钮
@onready var btnClose: Button = $margin/content/btnRow/btnClose

## 难度名
const DIFFICULTY_NAMES := ["BEGINNER", "INTERMEDIATE", "EXPERT", "NIGHTMARE"]

## 各行按钮引用：key -> Array[Button]
var buttonGroups: Dictionary = {}


func _ready() -> void:
	titleLabel.text = tr("OPTIONS")
	btnReset.text = tr("Reset")
	btnClose.text = tr("CLOSE")
	btnReset.pressed.connect(onReset)
	btnClose.pressed.connect(onClose)
	visibility_changed.connect(onVisibilityChanged)
	buildRows()


## 生成所有设置行
func buildRows() -> void:
	for c in list.get_children():
		c.queue_free()
	buttonGroups.clear()

	# 难度
	buttonGroups["difficulty"] = addRow(tr("Difficulty:"), DIFFICULTY_NAMES.size())
	# 三个开关
	buttonGroups["collision"] = addRow(tr("Object collision"), 2)
	buttonGroups["Devils"] = addRow(tr("Devils"), 2)
	buttonGroups["friendlyFire"] = addRow(tr("Friendly Fire"), 2)
	# 语言
	buttonGroups["language"] = addRow(tr("Language"), 2)

	# 语言行的两个按钮是「中文 / English」，单独设文字
	var langBtns: Array = buttonGroups["language"]
	(langBtns[0] as Button).text = "中文"
	(langBtns[1] as Button).text = "English"
	(langBtns[0] as Button).pressed.connect(func() -> void: setLocale("zh"))
	(langBtns[1] as Button).pressed.connect(func() -> void: setLocale("en"))

	syncUI()


## 造一行：左边标题，右边一组切换按钮
func addRow(labelText: String, count: int) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var nameLabel := Label.new()
	nameLabel.text = labelText
	nameLabel.custom_minimum_size = Vector2(190, 0)
	row.add_child(nameLabel)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)

	var group: Array[Button] = []
	for i in range(count):
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(96, 34)
		b.text = DIFFICULTY_NAMES[i] if count == DIFFICULTY_NAMES.size() else (tr("ON") if i == 0 else tr("OFF"))
		b.pressed.connect(func() -> void: onOptionPressed(count, i, group))
		box.add_child(b)
		group.append(b)

	list.add_child(row)
	return group


## 点击某一行的按钮
func onOptionPressed(_count: int, index: int, group: Array) -> void:
	for i in range(group.size()):
		(group[i] as Button).button_pressed = (i == index)
	# 只有非语言行写回 mapConfig
	if group == buttonGroups.get("difficulty", []):
		MapData.mapConfig.difficulty = index + 1
	elif group == buttonGroups.get("collision", []):
		MapData.mapConfig.collision = (index == 0)
	elif group == buttonGroups.get("Devils", []):
		MapData.mapConfig.Devils = (index == 0)
	elif group == buttonGroups.get("friendlyFire", []):
		MapData.mapConfig.friendlyFire = (index == 0)


## 面板显示/隐藏
func onVisibilityChanged() -> void:
	if visible:
		syncUI()
	else:
		Settings.saveAll()


## 把 mapConfig 的当前值回填到按钮
func syncUI() -> void:
	var cfg: Dictionary = MapData.mapConfig
	markSelected("difficulty", int(cfg.get("difficulty", 1)) - 1)
	markSelected("collision", 0 if bool(cfg.get("collision", true)) else 1)
	markSelected("Devils", 0 if bool(cfg.get("Devils", true)) else 1)
	markSelected("friendlyFire", 0 if bool(cfg.get("friendlyFire", false)) else 1)
	markSelected("language", 0 if TranslationServer.get_locale().begins_with("zh") else 1)


## 选中某行里的第 index 个按钮
func markSelected(key: String, index: int) -> void:
	if not buttonGroups.has(key):
		return
	var group: Array = buttonGroups[key]
	for i in range(group.size()):
		(group[i] as Button).button_pressed = (i == index)


## 切换语言
func setLocale(code: String) -> void:
	TranslationServer.set_locale(code)
	Settings.saveAll()
	titleLabel.text = tr("OPTIONS")
	btnReset.text = tr("Reset")
	btnClose.text = tr("CLOSE")


## 恢复默认设置
func onReset() -> void:
	MapData.mapConfig.difficulty = 1
	MapData.mapConfig.collision = true
	MapData.mapConfig.Devils = true
	MapData.mapConfig.friendlyFire = false
	Settings.saveAll()
	syncUI()


## 关闭面板
func onClose() -> void:
	SoundUtil.playClick()
	Settings.saveAll()
	hide()
