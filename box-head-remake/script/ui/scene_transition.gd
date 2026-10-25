extends Node

## 场景切换：全屏遮罩沿渐变方向擦除覆盖，期间异步加载目标场景
##
## 用法：SceneTransition.changeScene("res://scene/welcome.tscn")
##
## 着色器 factor 的语义：0 = 完全透明，1 = 完全覆盖。
## 所以入场是把 factor 从 0 补间到 1（遮住屏幕），加载完再补间回 0（露出新场景）。
## 擦除方向、颜色、宽度都在场景里的 ShaderMaterial 上调，不用改代码。


## 默认总时长（擦入 + 擦出）
const DEFAULT_DURATION: float = 0.6


## 是否正在切换中（切换期间忽略新的请求）
var isTransitioning: bool = false

## 待加载的场景路径
var pendingScenePath: String = ""

## 本次切换的时长
var pendingDuration: float = 0.0

## 覆盖层的着色器材质
var overlayMaterial: ShaderMaterial = null


@onready var overlay: ColorRect = $canvasLayer/overlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlayMaterial = overlay.material as ShaderMaterial
	overlay.visible = false
	setFactor(0.0)
	syncResolution()
	get_viewport().size_changed.connect(syncResolution)


## 切换到指定场景：先擦入遮罩，后台加载，加载完再擦出
func changeScene(path: String, duration: float = DEFAULT_DURATION) -> void:
	if isTransitioning:
		return
	isTransitioning = true
	pendingScenePath = path
	pendingDuration = duration

	overlay.visible = true
	setFactor(0.0)

	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(setFactor, 0.0, 1.0, maxf(duration * 0.5, 0.12))
	tween.tween_callback(startSceneLoad)


## 开始异步加载目标场景
func startSceneLoad() -> void:
	var err: int = ResourceLoader.load_threaded_request(pendingScenePath)
	if err != OK:
		push_error("SceneTransition 加载失败: %s" % pendingScenePath)
		onFinished()
		return
	monitorSceneLoad.call_deferred()


## 轮询加载进度，完成后切场景并擦出
func monitorSceneLoad() -> void:
	while isTransitioning:
		var status: int = ResourceLoader.load_threaded_get_status(pendingScenePath)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed: Resource = ResourceLoader.load_threaded_get(pendingScenePath)
			if packed is PackedScene:
				get_tree().change_scene_to_packed(packed)
				playWipeOut()
			else:
				push_error("SceneTransition 加载的不是 PackedScene: %s" % pendingScenePath)
				onFinished()
			return
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("SceneTransition 加载失败: %s" % pendingScenePath)
			onFinished()
			return
		await get_tree().process_frame


## 擦出：遮罩从 1 补间回 0
func playWipeOut() -> void:
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(setFactor, 1.0, 0.0, maxf(pendingDuration * 0.5, 0.12))
	tween.tween_callback(onFinished)


## 切完后的收尾
func onFinished() -> void:
	setFactor(0.0)
	overlay.visible = false
	pendingScenePath = ""
	pendingDuration = 0.0
	isTransitioning = false


## 着色器用它做宽高比校正
func syncResolution() -> void:
	if overlayMaterial == null:
		return
	overlayMaterial.set_shader_parameter("node_resolution", get_viewport().get_visible_rect().size)


## 设置擦除进度：0 = 透明，1 = 完全覆盖
func setFactor(value: float) -> void:
	if overlayMaterial != null:
		overlayMaterial.set_shader_parameter("factor", value)


## 过渡期间吞掉所有输入，防止点击穿透到下层场景
func _input(_event: InputEvent) -> void:
	if isTransitioning:
		get_viewport().set_input_as_handled()
