extends Node2D

## 地面贴花层（血迹 / 爆炸印记）
##
## 数组存世界坐标，一次 _draw 全画完；不生成节点。
## 贴图是原版 SWF 导出的素材：Effect.BloodSplat（59×56，4 帧）
## 与 Effect.ScorchMark（92×92，1 帧），格子 32 px。
## 用法：MapData.addBlood(pos) / MapData.addScorch(pos)

## 原版烘焙贴花时竖方向压扁 0.6（pGlobalScale.y），做出俯视透视
const SQUASH: float = 0.6
## 原版血迹在格内有 ±0.25 格随机抖动；爆炸印记不抖动
const BLOOD_JITTER_CELLS: float = 0.25
## 单条贴花上限（超出丢最旧的）
const MAX_DECALS: int = 400
## 原版导出的帧（preload 保证导出包里有这两个目录）
const BLOOD_FRAMES = [
	preload("res://sprite/fx/DefineSprite_599/1.png"),
	preload("res://sprite/fx/DefineSprite_599/2.png"),
	preload("res://sprite/fx/DefineSprite_599/3.png"),
	preload("res://sprite/fx/DefineSprite_599/4.png"),
]
const SCORCH_FRAMES = [
	preload("res://sprite/fx/DefineSprite_613/1.png"),
]

## 贴图覆盖：留空 = 用上面的原版帧；两者都留空则退回画圆点占位
@export var bloodTextures: Array[Texture2D] = []
@export var scorchTextures: Array[Texture2D] = []
## 基准大小（贴图原始尺寸 × 该系数，再乘调用方传的 size）
## 血迹 1.0 → 约 1.8 格宽，和原版一致；这里略收一点，避免死亡时糊成一片
@export var bloodScale: float = 0.7
## 爆炸印记调用方传 size=2.0，配 0.5 正好等于原版那张 92×55
@export var scorchScale: float = 0.5
## 基准透明度：原版是直接烧进地面位图（几乎不透明），这里略降以免盖住地面纹理。
## 导出的印记素材本身最大 alpha 只有 122（约 0.48），所以它不再额外压暗
@export var bloodAlpha: float = 0.85
@export var scorchAlpha: float = 1.0
## 占位圆点半径（没有贴图时才用）
@export var fallbackRadius: float = 8.0

## 每条：{pos, rot, scale, alpha, tex, kind}
var splats: Array = []


func _ready() -> void:
	add_to_group("decal")
	if bloodTextures.is_empty():
		bloodTextures.assign(BLOOD_FRAMES)
	if scorchTextures.is_empty():
		scorchTextures.assign(SCORCH_FRAMES)
	# 房间地面 Sprite2D 是 z_index 1，墙是 7~18，角色按 y 排成 ≥ 2。
	# 贴花要压在地面之上、墙和角色之下：取 2。
	# （取 1 会和地面同层，而房间是运行时后加进树的，会把血整片盖住）
	z_index = 2


## 加一条贴花
func addSplat(pos: Vector2, kind: String = "blood", size: float = 1.0) -> void:
	if not bool(MapData.mapConfig.get("blood", true)):
		return
	var isBlood := kind == "blood"
	var frames: Array = bloodTextures if isBlood else scorchTextures
	var baseScale: float = bloodScale if isBlood else scorchScale
	var baseAlpha: float = bloodAlpha if isBlood else scorchAlpha
	if isBlood:
		var j := BLOOD_JITTER_CELLS * MapData.cellSize
		pos += Vector2(randf_range(-j, j), randf_range(-j, j))
	splats.append({
		"pos": pos,
		"rot": randf() * TAU,          # 原版是 random(3) 三个朝向，这里连续随机
		"scale": baseScale * size * randf_range(0.85, 1.15),
		"alpha": baseAlpha * randf_range(0.85, 1.0),
		"tex": frames.pick_random() if not frames.is_empty() else null,
		"kind": kind,
	})
	if splats.size() > MAX_DECALS:
		splats.pop_front()
	queue_redraw()


## 清空（换关卡 / 关闭开关时调用）
func clearAll() -> void:
	splats.clear()
	queue_redraw()


func _draw() -> void:
	for s in splats:
		var tex: Texture2D = s.tex
		if tex == null:
			var fallback := Color(0.55, 0.03, 0.03, s.alpha)
			if s.kind != "blood":
				fallback = Color(0.08, 0.08, 0.08, s.alpha)
			draw_circle(s.pos, fallbackRadius * s.scale, fallback)
			continue
		# 先在未旋转的局部空间压扁，再由 draw_set_transform 旋转 —— 与原版烘焙顺序一致
		var sz: Vector2 = tex.get_size() * s.scale
		sz.y *= SQUASH
		draw_set_transform(s.pos, s.rot, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, Color(1, 1, 1, s.alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
