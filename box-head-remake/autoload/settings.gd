extends Node

## 全局设置持久化
##
## 存档位置：
##   编辑器里          -> user://settings.cfg
##   导出的桌面版 exe  -> exe 所在目录/settings.cfg
##
## 保存内容：按键映射 + 难度 + 各项开关 + 语言

const FILE_NAME := "settings.cfg"
const SECTION_INPUT := "input"
const SECTION_GAME := "game"


## 存档的绝对路径
##
## 导出后放在 exe 旁边，方便用户直接备份/改；编辑器里用 user:// 不污染项目。
func getConfigPath() -> String:
	if OS.has_feature("editor"):
		return "user://" + FILE_NAME
	return OS.get_executable_path().get_base_dir().path_join(FILE_NAME)


## 载入并应用全部设置（在 _ready 里调用）
##
## 顺序很重要：先记录「项目里的默认按键」，再载入用户配置去覆盖。
## 反过来的话，默认值会被用户配置污染，「恢复默认」就恢复成上次改过的值了。
func _ready() -> void:
	captureDefaults()
	loadAll()


## 载入设置
func loadAll() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(getConfigPath()) != OK:
		return
	loadInput(cfg)
	loadGame(cfg)


## 保存全部设置
func saveAll() -> void:
	var cfg := ConfigFile.new()
	saveInput(cfg)
	saveGame(cfg)
	cfg.save(getConfigPath())


## 从配置里恢复按键映射
func loadInput(cfg: ConfigFile) -> void:
	if not cfg.has_section(SECTION_INPUT):
		return
	for action in cfg.get_section_keys(SECTION_INPUT):
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var data = cfg.get_value(SECTION_INPUT, action)
		if data is Dictionary:
			var ev := dictToEvent(data)
			if ev != null:
				InputMap.action_add_event(action, ev)


## 把当前按键映射写进配置
func saveInput(cfg: ConfigFile) -> void:
	for action in InputMap.get_actions():
		var events := InputMap.action_get_events(action)
		if events.is_empty():
			continue
		cfg.set_value(SECTION_INPUT, action, eventToDict(events[0]))


## 恢复某一个动作的默认按键（需要把默认值记下来）
var defaultInput := {}


## 记录当前的（默认）按键，供「重置」用
func captureDefaults() -> void:
	defaultInput.clear()
	for action in InputMap.get_actions():
		var events := InputMap.action_get_events(action)
		if not events.is_empty():
			defaultInput[action] = eventToDict(events[0])


## 把某个动作重置为默认按键
func resetAction(action: String) -> void:
	if not defaultInput.has(action):
		return
	InputMap.action_erase_events(action)
	var ev := dictToEvent(defaultInput[action])
	if ev != null:
		InputMap.action_add_event(action, ev)


## 事件 -> 字典（只存键鼠，够用）
func eventToDict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return {"type": "key", "keycode": k.keycode, "physical": k.physical_keycode}
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		return {"type": "mouse", "button": mb.button_index}
	return {}


## 字典 -> 事件
func dictToEvent(data: Dictionary) -> InputEvent:
	if data.is_empty():
		return null
	match data.get("type", ""):
		"key":
			var k := InputEventKey.new()
			k.keycode = int(data.get("keycode", 0))
			k.physical_keycode = int(data.get("physical", 0))
			return k
		"mouse":
			var mb := InputEventMouseButton.new()
			mb.button_index = int(data.get("button", 1))
			return mb
	return null


## 把事件转成给人看的名字
func eventToText(ev: InputEvent) -> String:
	if ev == null:
		return "—"
	if ev is InputEventKey:
		var key := ev as InputEventKey
		# 有些按键只记录了 physical_keycode（keycode 为 0），要回退
		var code: int = key.keycode if key.keycode != 0 else key.physical_keycode
		return OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "鼠标左键"
			MOUSE_BUTTON_RIGHT:
				return "鼠标右键"
			MOUSE_BUTTON_MIDDLE:
				return "鼠标中键"
			MOUSE_BUTTON_WHEEL_UP:
				return "滚轮上"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "滚轮下"
		return "鼠标键%d" % (ev as InputEventMouseButton).button_index
	return "?"


## 游戏数值设置
func loadGame(cfg: ConfigFile) -> void:
	if not cfg.has_section(SECTION_GAME):
		return
	MapData.mapConfig.difficulty = int(cfg.get_value(SECTION_GAME, "difficulty", 1))
	MapData.mapConfig.collision = bool(cfg.get_value(SECTION_GAME, "collision", true))
	MapData.mapConfig.Devils = bool(cfg.get_value(SECTION_GAME, "Devils", true))
	MapData.mapConfig.friendlyFire = bool(cfg.get_value(SECTION_GAME, "friendlyFire", false))


## 保存游戏数值设置
func saveGame(cfg: ConfigFile) -> void:
	cfg.set_value(SECTION_GAME, "difficulty", MapData.mapConfig.difficulty)
	cfg.set_value(SECTION_GAME, "collision", MapData.mapConfig.collision)
	cfg.set_value(SECTION_GAME, "Devils", MapData.mapConfig.Devils)
	cfg.set_value(SECTION_GAME, "friendlyFire", MapData.mapConfig.friendlyFire)
