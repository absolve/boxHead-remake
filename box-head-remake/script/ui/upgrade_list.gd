extends CanvasLayer

## 升级内容一览
##
## 列出 MapData.upgradeTable 里的全部 60 档升级：倍率 / 目标武器 / 升级名 / 是否已获得。
## 按 TAB 开关。文本走 tr()，所以会跟随语言设置；提示文本本身来自
## MapData.buildUpgradeTable()，和右上角的升级播报用的是同一批字符串。


## 已获得的标记
const MARK_GOT: String = "[color=#5f5]★[/color]"

## 未获得的标记
const MARK_TODO: String = "[color=#666]·[/color]"


## 内容标签
@onready var body: RichTextLabel = $panel/body


func _ready() -> void:
	# 列表打开时要暂停游戏，所以自己必须在暂停中也能处理输入
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	refresh()


## 重建列表内容
func refresh() -> void:
	if body == null:
		return

	# 先收集所有条目（不带表头），再按两列排布
	var entries: Array[String] = []
	var keys: Array = MapData.upgradeTable.keys()
	keys.sort()

	for m in keys:
		for item in MapData.upgradeTable[m]:
			var got := false
			if item.has('unlock'):
				got = MapData.weaponUnlock.has(item.unlock)
			elif item.has('w'):
				got = MapData.weaponUpgrades.get(item.w, {}).has(item.up)

			var mark := MARK_GOT if got else MARK_TODO
			# 新武器用绿色系（已获得亮绿 / 未获得中绿）；
			# 其它升级已获得正常色、未获得略淡
			var isNewWeapon: bool = item.has('unlock')
			var textColor: String
			if isNewWeapon:
				textColor = "#6f6" if got else "#63b063"
			else:
				textColor = "#f2f2f2" if got else "#b0b0b0"
			entries.append("%s [color=#9a9a9a]%3d[/color] [color=%s]%s[/color]" % [
					mark, int(m), textColor, tr(str(item.text))])

	var sb := "[b][font_size=20]%s[/font_size][/b]  [color=#888]%s[/color]\n\n" % [
			tr("Upgrades"), tr("TAB to close")]

	var half := int(ceil(entries.size() / 2.0))
	sb += "[table=2]"
	for i in range(half):
		var left: String = entries[i]
		var right: String = entries[i + half] if i + half < entries.size() else ""
		sb += "[cell]%s[/cell][cell]%s[/cell]" % [left, right]
	sb += "[/table]"

	body.text = sb


## 切换显示（每次打开都重建，保证状态是最新的）
func toggle() -> void:
	setShown(not visible)


## 显示/隐藏；显示时暂停游戏（原版看升级列表也会暂停）
func setShown(on: bool) -> void:
	visible = on
	if on:
		refresh()
		get_tree().paused = true
	else:
		get_tree().paused = false


## 供其它脚本调用
func showList() -> void:
	setShown(true)


func hideList() -> void:
	setShown(false)


## TAB 开关
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	# Godot 4 物理按键的 keycode 可能为 0，必须退回 physical_keycode
	var kc: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if kc == KEY_TAB:
		toggle()
		get_viewport().set_input_as_handled()
