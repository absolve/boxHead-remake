extends "res://script/item/item.gd"

## 火箭弹脚本
# 继承自item.gd，实现火箭弹的飞行和爆炸逻辑
# 火箭弹会沿直线飞行，碰撞物体或到达边界时爆炸，并留下烟雾轨迹


## 烟雾效果场景预加载
var smoke: PackedScene = preload("res://scene/fx/smoke.tscn")

## 爆炸效果场景预加载
var explosion: PackedScene = preload("res://scene/fx/explosion.tscn")

## 飞行方向向量
var vector: Vector2 = Vector2.ZERO

## 飞行速度
## 初速（px/s）：原版 0.5 格/tick = 0.5 × 32 × 25
var speed: float = 400.0

## 每 1/25 秒的加速倍率（原版 mDelta.ScaleN(1.1)）
var accelFactor: float = 1.1

## 最高速度（原版无上限，这里封顶避免飞出地图太快）
var maxSpeed: float = 1200.0

## 25Hz 累积器
var accelAcc: float = 0.0

## 伤害值
var damage: int = 0


## 初始化
func _ready() -> void:
	# 播放默认动画
	ani.play("default")

	# 创建循环补间，定期生成烟雾轨迹
	var tween = create_tween()
	tween.set_loops()
	tween.tween_callback(addSmoke)
	tween.tween_interval(0.2)


## 添加烟雾效果
# 在当前位置创建一个烟雾粒子
func addSmoke() -> void:
	var temp = smoke.instantiate()
	temp.global_position = global_position
	get_tree().current_scene.add_child(temp)


## 离开屏幕时销毁
func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	queue_free()


## 引爆：生成爆炸并销毁自己
func explode() -> void:
	var temp = explosion.instantiate()
	temp.global_position = global_position
	temp.damage = damage
	temp.biggerBang = biggerBang
	temp.clusterExplode = clusterExplode
	get_tree().current_scene.add_child(temp)
	queue_free()


## 物理帧更新
func _physics_process(delta: float) -> void:
	# 撞静态障碍格：地图里的柱子/边界墙只有障碍格数据，未必有物理体，
	# 光靠 get_overlapping_bodies() 会穿过去，所以按格子再判一次。
	if MapData.isObstacle(MapData.worldToCell(global_position)):
		explode()
		return

	# 检测与物体的碰撞
	var body = get_overlapping_bodies()
	if body:
		explode()
		return

	# 检测与区域的碰撞
	var area = get_overlapping_areas()
	if area:
		explode()
		return

	# 到达地图边界时爆炸
	if global_position.x < itemSize.x / 2 or global_position.x > MapData.mapSize.x - itemSize.x / 2 \
		or global_position.y < itemSize.y / 2 or global_position.y > MapData.mapSize.y - itemSize.y / 2:
		explode()
		return

	# 加速：原版每 1/25 秒 mDelta ×1.1（先用新速度再移动）
	accelAcc += delta
	var accStep: float = 1.0 / MapData.TICKS_PER_SEC
	while accelAcc >= accStep:
		accelAcc -= accStep
		speed = minf(speed * accelFactor, maxSpeed)

	# 沿方向移动
	position += vector * speed * delta
