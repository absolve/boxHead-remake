extends Node2D

## 地面贴花层（血迹 / 爆炸印记）
##
## 数组存世界坐标，一次 _draw 全画完；不生成节点。
## 目前画半透明圆点占位；把 texture 赋值后自动改成画贴图（可旋转）。
## 用法：MapData.addBlood(pos) / MapData.addScorch(pos)

## 单条贴花上限（超出丢最旧的）
const MAX_DECALS: int = 400

## 血迹贴图（留空 = 画圆点占位）
@export var bloodTexture: Texture2D = null
## 爆炸印记贴图（留空 = 画深灰圆点）
@export var scorchTexture: Texture2D = null

## 每条：{pos: Vector2, rot: float, scale: float, alpha: float, kind: String}
var splats: Array = []


func _ready() -> void:
	add_to_group("decal")
	z_index = -10          # 画在角色下面


## 加一条贴花
func addSplat(pos: Vector2, kind: String = "blood", size: float = 1.0) -> void:
	if not bool(MapData.mapConfig.get("blood", true)):
		return
	splats.append({
		"pos": pos,
		"rot": randf() * TAU,          # 随机旋转，避免看出重复
		"scale": size * randf_range(0.85, 1.15),
		"alpha": randf_range(0.35, 0.6),
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
	if splats.is_empty():
		return
	for s in splats:
		if s.kind == "blood":
			_drawOne(s, bloodTexture, Color(0.55, 0.03, 0.03, s.alpha), 6.0)
		else:
			_drawOne(s, scorchTexture, Color(0.08, 0.08, 0.08, s.alpha), 10.0)


## 有贴图就画旋转贴图，没有就画圆
func _drawOne(s: Dictionary, tex: Texture2D, fallback: Color, baseRadius: float) -> void:
	if tex != null:
		var sz: Vector2 = tex.get_size() * s.scale
		draw_set_transform(s.pos, s.rot, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, Color(1, 1, 1, s.alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(s.pos, baseRadius * s.scale, fallback)
