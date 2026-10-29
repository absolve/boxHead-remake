extends Node2D

## 爆炸画面抖动测试场景（直接 F6 运行本场景）
##
## 只有一个固定相机 + 一个房间，爆炸发生在视野正中，用来肉眼和数字双重验证抖动参数。
##
## 按键：
##   1 单发爆炸          2 两发同帧          3 五发同帧（验证封顶）
##   4 连锁 6 发（0.12s 间隔，模拟油桶连锁）
##   5 BigBang 型（4 发，80~200ms 随机延迟，模拟升级子爆）
##   空格 开关设置里的「画面抖动」        R 复位相机与统计
##   ↑/↓ 单发幅度 ±1 px                   ←/→ 叠加上限 ±1 px
##
## 屏幕左上角实时显示参数、当前位移、上一次抖动的峰值与持续时间。
## 屏幕中央的十字线画在 CanvasLayer 上，不随相机移动，作为幅度参照。


const EXPLOSION: PackedScene = preload("res://scene/fx/explosion.tscn")
const DECAL_SCRIPT: Script = preload("res://script/fx/decal_layer.gd")


## 爆炸伤害：0 = 用默认半径（2 格），场景里没有可伤害目标
@export var explosionDamage: int = 0


var cam: Camera2D = null
var label: Label = null
var room: Node2D = null
## 上一次抖动的统计
var peak: float = 0.0
var shakeStartMs: int = 0
var lastDurationMs: int = 0
var timing: bool = false
## 进场景前的设置值，退出时还原（测试里的切换不写 settings.cfg）
var shakeWasEnabled: bool = true


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#EDE2CF"))
	MapData.playerCount = 1
	MapData.selectedMapId = 0
	shakeWasEnabled = bool(MapData.mapConfig.get("screenShake", true))

	room = load("res://scene/level/room_001.tscn").instantiate()
	add_child(room)
	MapData.mapSize = room.mapSize

	# 让爆炸也有焦痕，顺便验证贴花层
	var decals := Node2D.new()
	decals.set_script(DECAL_SCRIPT)
	add_child(decals)

	cam = $camera as Camera2D
	_centerCamera()
	_buildUI()
	print("[test_shake] 准备就绪：按 1~5 触发爆炸")


func _centerCamera() -> void:
	if cam == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	# game_camera.tscn 用的是 ANCHOR_MODE_FIXED_TOP，position = 视口左上角
	cam.global_position = (MapData.mapSize - vp) * 0.5
	cam.offset = Vector2.ZERO
	cam.set("shakeAmp", 0.0)


## 固定在屏幕上的文字与参照线（CanvasLayer 不受相机抖动影响）
func _buildUI() -> void:
	var ui: CanvasLayer = $ui

	label = Label.new()
	label.position = Vector2(8, 6)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	ui.add_child(label)

	var vp: Vector2 = get_viewport_rect().size
	var c := vp * 0.5
	# 十字线：竖线按抖动方向（竖直）贯穿，横线做辅助
	_ruler(Vector2(c.x, 20), Vector2(1, vp.y - 40), Color(0, 0.4, 0.9, 0.8))
	_ruler(Vector2(c.x - 40, c.y), Vector2(80, 1), Color(0, 0.4, 0.9, 0.8))
	# 刻度：±15 px = 原版可见峰值，±32 px = 叠加上限
	for d in [15.0, 32.0]:
		for s in [-1.0, 1.0]:
			_ruler(Vector2(c.x - 6, c.y + s * d), Vector2(13, 1), Color(0.85, 0.15, 0.15, 0.85))


func _ruler(pos: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	($ui as CanvasLayer).add_child(r)


func _process(_delta: float) -> void:
	if cam == null:
		return
	var amp: float = cam.get("shakeAmp")
	if amp > peak:
		peak = amp
	if timing and amp <= 0.0:
		timing = false
		lastDurationMs = Time.get_ticks_msec() - shakeStartMs

	var enabled := bool(MapData.mapConfig.get("screenShake", true))
	label.text = "\n".join([
		"画面抖动：%s    当前幅度 %.1f px    位移 %.0f px" % [
			"开" if enabled else "关", amp, cam.offset.y],
		"单发幅度 %.0f   叠加上限 %.0f   频率 %.1f Hz   半衰期 %.0f ms" % [
			cam.get("shakeImpulse"), cam.get("shakeMax"), cam.get("shakeFrequency"), cam.get("shakeHalfLife") * 1000.0],
		"上一次：峰值 %.1f px，持续 %d ms" % [peak, lastDurationMs],
		"[1]单发  [2]双发  [3]五发  [4]连锁  [5]BigBang",
		"[空格]开关  [R]复位  [↑↓]单发幅度  [←→]叠加上限",
	])


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_1:
			burst(1)
		KEY_2:
			burst(2)
		KEY_3:
			burst(5)
		KEY_4:
			burst(6, 0.12)
		KEY_5:
			bigBang()
		KEY_SPACE:
			_toggleShake()
		KEY_R:
			_reset()
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
			_tune(k.keycode)


## 同帧连发 count 发；interval > 0 时改成每隔 interval 秒一发
func burst(count: int, interval: float = 0.0) -> void:
	_trigger("触发 %d 发%s" % [count, "" if interval <= 0.0 else "（间隔 %.2fs）" % interval])
	for i in count:
		_explode()
		if interval > 0.0 and i < count - 1:
			await get_tree().create_timer(interval).timeout


## 模拟 BigBang：4 发、80~200ms 随机延迟
func bigBang() -> void:
	_trigger("触发 BigBang（4 发，80~200ms 随机延迟）")
	for i in 4:
		await get_tree().create_timer(randf_range(0.08, 0.2)).timeout
		_explode()


func _explode() -> void:
	var e: Node2D = EXPLOSION.instantiate()
	e.set("damage", explosionDamage)
	var vp: Vector2 = get_viewport_rect().size
	e.global_position = cam.global_position + vp * 0.5
	add_child(e)


func _trigger(title: String) -> void:
	peak = 0.0
	lastDurationMs = 0
	shakeStartMs = Time.get_ticks_msec()
	timing = true
	print("[test_shake] ", title)


func _toggleShake() -> void:
	var on := not bool(MapData.mapConfig.get("screenShake", true))
	MapData.mapConfig.screenShake = on
	if not on:
		cam.set("shakeAmp", 0.0)
		cam.offset = Vector2.ZERO
	print("[test_shake] 画面抖动 = ", on)


func _tune(key: int) -> void:
	var impulse: float = cam.get("shakeImpulse")
	var cap: float = cam.get("shakeMax")
	match key:
		KEY_UP:
			cam.set("shakeImpulse", minf(impulse + 1.0, 60.0))
		KEY_DOWN:
			cam.set("shakeImpulse", maxf(impulse - 1.0, 1.0))
		KEY_RIGHT:
			cam.set("shakeMax", minf(cap + 1.0, 80.0))
		KEY_LEFT:
			cam.set("shakeMax", maxf(cap - 1.0, 1.0))


func _reset() -> void:
	_centerCamera()
	peak = 0.0
	lastDurationMs = 0
	timing = false
	print("[test_shake] 已复位")


## 退出测试场景时把全局状态还原
func _exit_tree() -> void:
	MapData.playerCount = 4
	MapData.mapConfig.screenShake = shakeWasEnabled
