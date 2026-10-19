extends PopupPanel

## 操作说明弹窗
##
## 正文在运行时按 InputMap 生成，这样改键后说明里的按键会跟着变，
## 没绑定的动作显示「未设置」。

## 返回按钮
@onready var btnBack: Button = $margin/content/btnBack

## 正文
@onready var body: RichTextLabel = $margin/content/body

## 每种动作的显示名（动作名去掉 p1_ 前缀后的部分）
## 顺序与 project.godot 里动作的定义顺序一致：
## left / right / up / down / fire / nextWeapon / prevWeapon
const ACTION_LABELS := {
	"left": "Move Left",
	"right": "Move Right",
	"up": "Move Up",
	"down": "Move Down",
	"fire": "Shoot",
	"nextWeapon": "Next Weapon",
	"prevWeapon": "Prev Weapon",
}

## 玩家数
const PLAYER_COUNT := 4


func _ready() -> void:
	btnBack.pressed.connect(onBackPressed)
	body.bbcode_enabled = true
	# 标题和按钮用显式 tr()，不依赖节点自动翻译
	$margin/content/title.text = tr("Instructions")
	btnBack.text = tr("CLOSE")
## 每次显示时重建正文（保证按键是最新的）
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		buildBody()


## 生成按键说明
func buildBody() -> void:
	var lines: Array[String] = []

	for p in range(1, PLAYER_COUNT + 1):
		lines.append("[b]%s %d[/b]" % [tr("Player"), p])
		for suffix in ACTION_LABELS:
			var action := "p%d_%s" % [p, suffix]
			lines.append("    %s:  %s" % [tr(ACTION_LABELS[suffix]), describeAction(action)])
		lines.append("")

	lines.append("[b]%s[/b]" % tr("Goal"))
	lines.append(tr("Kill every zombie in the room. Boxes give new weapons and upgrades."))
	lines.append(tr("Chain kills to unlock them faster."))

	body.text = "\n".join(lines)


## 取某个动作当前绑定的按键文本
func describeAction(action: String) -> String:
	if not InputMap.has_action(action):
		return tr("Not set")
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return tr("Not set")
	return Settings.eventToText(events[0])


## 关闭弹窗
func onBackPressed() -> void:
	SoundUtil.playClick()
	hide()
