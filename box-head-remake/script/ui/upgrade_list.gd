extends CanvasLayer

## 升级内容一览
##
## 列出 MapData.upgradeTable 里的全部 60 档升级：倍率 / 目标武器 / 升级名 / 是否已获得。
## 按 TAB 开关。文本走 tr()，所以会跟随语言设置；提示文本本身来自
## MapData.buildUpgradeTable()，和右上角的升级播报用的是同一批字符串。

## 内容标签
@onready var body: RichTextLabel = $panel/body

## 已获得的标记
const MARK_GOT := "[color=#5f5]★[/color]"
## 未获得的标记
const MARK_TODO := "[color=#666]·[/color]"


func _ready() -> void:
	visible = false
	refresh()


## 重建列表内容
func refresh() -> void:
	if body == null:
		return

	var lines: Array[String] = []
	lines.append("[b][font_size=22]%s[/font_size][/b]" % tr("Upgrades"))
	lines.append("[color=#888]%s[/color]" % tr("TAB to close"))
	lines.append("")

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
			lines.append("%s [color=#aaa]%3d[/color]  %s" % [mark, int(m), tr(str(item.text))])

	body.text = "\n".join(lines)


## TAB 开关
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event.keycode == KEY_TAB:
		toggle()
		get_viewport().set_input_as_handled()


## 切换显示（每次打开都重建，保证状态是最新的）
func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


## 供其它脚本调用
func showList() -> void:
	visible = true
	refresh()


func hideList() -> void:
	visible = false
