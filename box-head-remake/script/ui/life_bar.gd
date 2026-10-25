extends Control

## 角色生命条
##
## 两种显示模式：
##   alwaysShows = true  → 始终可见（默认）
##   alwaysShows = false → 只在血量变化时显示，一段时间后淡出


## 血量染色的着色器（越低越红）
const TINT_SHADER: Shader = preload("res://shader/life_bar_tint.gdshader")


## 是否始终显示血条
@export var alwaysShows: bool = false

## 当前血量：设置时自动更新进度条
@export var hp: int = 10:
	set(val):
		# 值没变就不要重启计时器：
		# 自动回血期间每帧都会赋值，若无条件 showLifeBar() 会不断重置 2 秒计时，
		# 导致定时器永远不触发、淡出永远不发生。
		if val == hp:
			return
		hp = val
		# 节点还没进树时 bar 还是 null（@onready 未执行），直接跳过
		if bar == null:
			return
		bar.value = val
		updateTint()
		if hp > 0:
			showLifeBar()

## 最大血量：设置时自动更新进度条上限
@export var maxHp: int = 10:
	set(val):
		maxHp = val
		if bar == null:
			return
		bar.max_value = val
		updateTint()


## 淡出补间
var tween: Tween = null

## 运行时挂到进度条上的染色材质
var tint: ShaderMaterial = null


## 纹理进度条节点
@onready var bar: TextureProgressBar = $TextureProgressBar

## 隐藏计时器
@onready var timer: Timer = $Timer


func _ready() -> void:
	# 染色材质在代码里建（shader 是资源，不是节点）
	tint = ShaderMaterial.new()
	tint.shader = TINT_SHADER
	bar.material = tint

	bar.max_value = hp
	bar.value = hp
	updateTint()
	showLifeBar()


## 显示血条：重置透明度，按模式决定是否启动隐藏计时
func showLifeBar() -> void:
	if tween != null and tween.is_valid():
		tween.kill()

	bar.modulate.a = 1.0

	# 始终显示模式下不启动计时器，血条保持不透明
	if alwaysShows:
		timer.stop()
		return

	timer.start()


## 计时结束：淡出
func _on_timer_timeout() -> void:
	if alwaysShows:
		return
	tween = create_tween()
	tween.tween_property(bar, "modulate:a", 0.0, 0.5)


## 按当前血量比例更新染色
func updateTint() -> void:
	if tint == null:
		return
	var ratio: float = 1.0
	if maxHp > 0:
		ratio = clampf(float(hp) / float(maxHp), 0.0, 1.0)
	tint.set_shader_parameter("hp_ratio", ratio)
