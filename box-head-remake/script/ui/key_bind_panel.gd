extends PopupPanel

## 按键修改面板
##
## 列表在运行时按 InputMap 里的动作生成（数量不固定，没法在场景里预设），
## 点某一行的按键按钮后进入「等待输入」状态，下一个键盘/鼠标按键即完成绑定。


## 等待输入的动作名；空 = 不在等待
var waitingAction: String = ""
## 当前等待中的那行按钮
var waitingButton: Button = null

## 动作名 → 显示文案：直接显示 p1_left 这种内部名字玩家看不懂
const ACTION_LABEL: Dictionary = {
	"left": "Left", "right": "Right", "up": "Up", "down": "Down",
	"fire": "Fire", "nextWeapon": "Next Weapon", "prevWeapon": "Prev Weapon",
}


## 行容器
@onready var list: VBoxContainer = $margin/content/scroll/list
## 状态提示
@onready var hint: Label = $margin/content/hint
## 关闭按钮
@onready var btnClose: Button = $margin/content/btnRow/btnClose
## 全部恢复默认按钮
@onready var btnDefaultAll: Button = $margin/content/btnRow/btnDefaultAll


func _ready() -> void:
	Settings.captureDefaults()
	btnClose.pressed.connect(onClose)
	btnDefaultAll.text = tr("ALL DEFAULTS")
	btnDefaultAll.pressed.connect(onRestoreAllDefaults)
	hint.text = ""
	buildList()
	$margin/content/title.text = tr("KEY BINDINGS")
	btnClose.text = tr("CLOSE")


## 生成动作列表（按玩家分组）
func buildList() -> void:
	for c in list.get_children():
		c.queue_free()

	var actions: Array[String] = []
	for a in InputMap.get_actions():
		var s := String(a)
		if s.begins_with("p") and s.length() > 2 and s[1].is_valid_int():
			actions.append(s)
	# 不排序：沿用 InputMap 的顺序（即 project.godot 里的定义顺序）

	# 按玩家分组显示，每组一个小标题
	var currentPlayer := ""
	for action in actions:
		var group := action.substr(0, 2)  # p1 / p2 / p3 / p4
		if group != currentPlayer:
			currentPlayer = group
			var header := Label.new()
			header.text = "玩家 %s" % group.substr(1)
			header.add_theme_font_size_override("font_size", 18)
			list.add_child(header)
		list.add_child(buildRow(action))


## 动作名 → 玩家看得懂的名字（p1_left -> 左）
func actionLabel(action: String) -> String:
	var short: String = action.substr(3) if action.length() > 3 else action
	var text: String = ACTION_LABEL.get(short, short)
	return tr(text)


## 造一行：动作名 + 当前按键按钮 + 重置
func buildRow(action: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var nameLabel := Label.new()
	nameLabel.text = actionLabel(action)
	nameLabel.custom_minimum_size = Vector2(200, 0)
	row.add_child(nameLabel)

	var keyBtn := Button.new()
	keyBtn.custom_minimum_size = Vector2(160, 32)
	keyBtn.text = formatAction(action)
	keyBtn.pressed.connect(func() -> void: startListening(action, keyBtn))
	row.add_child(keyBtn)

	var resetBtn := Button.new()
	resetBtn.text = "重置"
	resetBtn.pressed.connect(func() -> void: onReset(action, keyBtn))
	row.add_child(resetBtn)

	# 恢复成项目里的默认按键
	var defaultBtn := Button.new()
	defaultBtn.text = tr("Default")
	defaultBtn.pressed.connect(func() -> void: onRestoreDefault(action, keyBtn))
	row.add_child(defaultBtn)

	return row


## 把动作的第一个按键转成文本
func formatAction(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return tr("Not set")
	return Settings.eventToText(events[0])


## 开始等待用户按键
func startListening(action: String, btn: Button) -> void:
	waitingAction = action
	waitingButton = btn
	btn.text = "按下新按键…"
	hint.text = "正在修改：%s（按 Esc 取消）" % action


## 取消等待
func stopListening() -> void:
	if waitingButton != null and is_instance_valid(waitingButton):
		waitingButton.text = formatAction(waitingAction)
	waitingAction = ""
	waitingButton = null
	hint.text = ""


## 恢复某个动作为项目默认按键
func onRestoreDefault(action: String, btn: Button) -> void:
	Settings.resetAction(action)
	Settings.saveAll()
	btn.text = formatAction(action)
	hint.text = "%s %s" % [action, tr("restored to default")]


## 重置某个动作：清空绑定，显示「未设置」
func onReset(action: String, btn: Button) -> void:
	InputMap.action_erase_events(action)
	Settings.saveAll()
	btn.text = formatAction(action)
	hint.text = "%s 已清空" % action


## 关闭面板
func onClose() -> void:
	stopListening()
	Settings.saveAll()
	hide()


## 全部恢复默认按键
func onRestoreAllDefaults() -> void:
	for action in Settings.defaultInput.keys():
		Settings.resetAction(action)
	Settings.saveAll()
	buildList()
	hint.text = tr("all restored to default")


## 捕获输入并绑定
func _input(event: InputEvent) -> void:
	if waitingAction == "":
		return

	if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		stopListening()
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if not event.is_pressed():
		return

	var data := Settings.eventToDict(event)
	if data.is_empty():
		return

	InputMap.action_erase_events(waitingAction)
	var ev := Settings.dictToEvent(data)
	if ev != null:
		InputMap.action_add_event(waitingAction, ev)

	Settings.saveAll()
	if waitingButton != null and is_instance_valid(waitingButton):
		waitingButton.text = Settings.eventToText(ev)
	hint.text = "已保存"
	waitingAction = ""
	waitingButton = null
	get_viewport().set_input_as_handled()
