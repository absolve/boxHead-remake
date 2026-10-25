extends PopupPanel

## 选项面板（布局对齐原版 Boxhead 的设置窗口）
##
## 每行 = 标题 + 选项按钮 + 下方一行灰色说明。
## 行在运行时生成：开关组的状态要跟 mapConfig 同步，说明文字要走 i18n。


## 难度名（原版用词）
const DIFFICULTY_NAMES: Array = ["BEGINNER", "INTERMEDIATE", "EXPERT", "NIGHTMARE"]

## 每一行的配置：key / 标题 / 说明 / 选项文字
## 说明文字直接作为 i18n 的 key（英文原文），中文在 lang.csv 里
const ROWS: Array = [
	{
		"key": "difficulty",
		"label": "Difficulty:",
		"tip": "Sets the difficulty of the level: escalates the level and the upgrades accordingly",
		"options": ["BEGINNER", "INTERMEDIATE", "EXPERT", "NIGHTMARE"],
	},
	{
		"key": "collision",
		"label": "Object collision:",
		"tip": "Turns the Collisions with Zombies, Fake walls & barrels on/off. Forfeits hiscore!",
		"options": ["OFF", "ON"],
	},
	{
		"key": "Devils",
		"label": "Devils:",
		"tip": "Turns the Devils on/off, when off the Devils do not spawn. Forfeits hiscore!",
		"options": ["OFF", "ON"],
	},
	{
		"key": "friendlyFire",
		"label": "Friendly Fire:",
		"tip": "Turns the Friendly damage on/off, however damage from barrels is "
				+ "still applicable. Forfeits hiscore!",
		"options": ["OFF", "ON"],
	},
	{
		"key": "language",
		"label": "Language:",
		"tip": "Switch the display language",
		"options": ["中文", "English"],
	},
]


## 选中态背景色（取自原版选项按钮的浅蓝 #BCD7FE）
var selectedColor: Color = Color(0.737, 0.843, 0.996)

## 选中态的文字颜色（浅蓝底上要用深色才看得清）
var selectedTextColor: Color = Color(0.102, 0.102, 0.102)

## 各行按钮引用：key -> Array[Button]
var buttonGroups: Dictionary = {}


## 行容器
@onready var list: VBoxContainer = $margin/content/scroll/list

## 标题
@onready var titleLabel: Label = $margin/content/title

## 重置按钮
@onready var btnReset: Button = $margin/content/btnRow/btnReset

## 关闭按钮
@onready var btnClose: Button = $margin/content/btnRow/btnClose


func _ready() -> void:
	btnReset.pressed.connect(onReset)
	btnClose.pressed.connect(onClose)
	visibility_changed.connect(onVisibilityChanged)
	buildRows()


## 生成所有设置行
func buildRows() -> void:
	for c in list.get_children():
		c.queue_free()
	buttonGroups.clear()

	titleLabel.text = tr("OPTIONS")
	btnReset.text = tr("Reset")
	btnClose.text = tr("CLOSE")

	for row in ROWS:
		var group: Array[Button] = addRow(row)
		buttonGroups[row["key"]] = group
		# 语言行的两个按钮要切换语言
		if row["key"] == "language":
			group[0].pressed.connect(func() -> void: setLocale("zh"))
			group[1].pressed.connect(func() -> void: setLocale("en"))

	syncUI()


## 造一行：标题 / 按钮（自动换行） / 说明
func addRow(row: Dictionary) -> Array[Button]:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	# 标题
	var nameLabel := Label.new()
	nameLabel.text = tr(row["label"])
	box.add_child(nameLabel)

	# 按钮：HFlowContainer 放不下会自动换到下一行
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 4)
	box.add_child(flow)

	var group: Array[Button] = []
	var options: Array = row["options"]
	for i in range(options.size()):
		var b := Button.new()
		b.text = tr(options[i])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(104, 30)
		applySelectedStyle(b)
		flow.add_child(b)
		group.append(b)
		b.pressed.connect(func() -> void: onOptionPressed(row["key"], i, group))

	# 说明：调亮一点，自动折行
	var tip := Label.new()
	tip.text = tr(row["tip"])
	tip.add_theme_font_size_override("font_size", 13)
	tip.add_theme_color_override("font_color", Color(0.86, 0.86, 0.86, 1.0))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(520, 0)
	box.add_child(tip)

	list.add_child(box)
	return group


## 点击某个选项
func onOptionPressed(key: String, index: int, group: Array) -> void:
	for i in range(group.size()):
		(group[i] as Button).button_pressed = (i == index)

	match key:
		"difficulty":
			MapData.mapConfig.difficulty = index + 1
		"collision":
			MapData.mapConfig.collision = (index == 1)
		"Devils":
			MapData.mapConfig.Devils = (index == 1)
		"friendlyFire":
			MapData.mapConfig.friendlyFire = (index == 1)
		_:
			pass
	Settings.saveAll()


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
	markSelected("collision", 1 if bool(cfg.get("collision", true)) else 0)
	markSelected("Devils", 1 if bool(cfg.get("Devils", true)) else 0)
	markSelected("friendlyFire", 1 if bool(cfg.get("friendlyFire", false)) else 0)
	markSelected("language", 0 if TranslationServer.get_locale().begins_with("zh") else 1)


## 选中某行里的第 index 个按钮
func markSelected(key: String, index: int) -> void:
	if not buttonGroups.has(key):
		return
	var group: Array = buttonGroups[key]
	for i in range(group.size()):
		(group[i] as Button).button_pressed = (i == index)


## 切换语言：改 locale 后整表重建，行标题和说明才会跟着变
func setLocale(code: String) -> void:
	TranslationServer.set_locale(code)
	Settings.saveAll()
	buildRows()


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


## 给按钮套上「选中 = 浅蓝底深色字」的样式
func applySelectedStyle(b: Button) -> void:
	var pressedStyle := StyleBoxFlat.new()
	pressedStyle.bg_color = selectedColor
	pressedStyle.set_corner_radius_all(6)

	var hoverPressed := pressedStyle.duplicate() as StyleBoxFlat
	hoverPressed.bg_color = selectedColor.lightened(0.08)

	b.add_theme_stylebox_override("pressed", pressedStyle)
	b.add_theme_stylebox_override("hover_pressed", hoverPressed)
	b.add_theme_color_override("font_pressed_color", selectedTextColor)
	b.add_theme_color_override("font_hover_pressed_color", selectedTextColor)
