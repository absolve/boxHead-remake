extends "res://script/item/item.gd"

## 手榴弹物体脚本
# 继承自item.gd，实现手榴弹的物理行为和爆炸逻辑
# 手榴弹会在空中飞行、落地后弹跳，最终停止并爆炸


## 伤害值
@export var damage: int = 0

@export var wRange: int = 0


## 爆炸效果场景预加载
var explosion: PackedScene = preload("res://scene/fx/explosion.tscn")

## 飞行方向向量
var vector: Vector2 = Vector2.ZERO

## 初始高度
var height: int = 30

## 飞行速度
var speed: int = 50

## 动画补间节点（用于延迟爆炸）
var tween: Tween = null

## 落地位置
var floorPos: Vector2 = Vector2.ZERO

## 落地弹跳：撞击竖直速度低于这个值就不再弹（px/s）
var verticalBounceMin: float = 120.0

## 每次弹跳保留的竖直速度比例
var verticalBounceFactor: float = 0.6

## 是否已落地
var isOnFloor: bool = false

## 飞行角度
var angle: float = 0

## 重力向量
var gVec: Vector2 = Vector2(0, -100)

## 物理形状查询参数
var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()


## 音效节点
@onready var sound: AudioStreamPlayer2D = $sound

## 碰撞形状节点
@onready var shape: CollisionShape2D = $shape


## 初始化
func _ready() -> void:
	# 设置重力加速度
	gravity = 800

	# 计算飞行角度和速度
	angle = vector.angle()
	vector *= speed

	# 配置物理查询参数
	params.exclude = []
	if ownerId is RID:
		params.exclude = [ownerId]
	params.shape = shape.shape
	params.transform = Transform2D(global_rotation, global_position)
	params.collision_mask = collision_mask
	params.collide_with_areas = true


## 添加爆炸效果
# 延迟0.5秒后创建爆炸
func addExplosion() -> void:
	tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		var temp = explosion.instantiate()
		temp.global_position = global_position
		temp.collision_mask = collision_mask
		temp.damage = damage
		temp.biggerBang = biggerBang
		temp.clusterExplode = clusterExplode
		get_tree().current_scene.add_child(temp)
		)
	tween.tween_callback(queue_free)


## 物理帧更新
func _physics_process(delta: float) -> void:
	params.transform = Transform2D(global_rotation, global_position)
	if not isOnFloor:
		# 空中阶段：应用重力，减少高度
		gVec.y += gravity * delta
		height -= gVec.y * delta

		# 判断是否落地
		if height <= 0:
			height = 0
			# 落地音效 + 反弹减速（原版：水平 ×0.5）
			vector *= 0.5
			sound.play()
			# 竖直速度够大就再弹一次（原版 mDelta.mZ 反向），太低就直接停
			if gVec.y > verticalBounceMin:
				gVec.y = -gVec.y * verticalBounceFactor
			else:
				isOnFloor = true
				gVec = Vector2.ZERO
	else:
		# 落地阶段：速度逐渐衰减
		vector = vector.lerp(Vector2.ZERO, 0.05)

	# 边界反弹检测（用可活动区域，避免跑进墙带里）
	var pr: Rect2 = MapData.getPlayRect()
	var rad: float = itemSize.x / 2
	if position.x <= pr.position.x + rad  or  position.x >= pr.end.x - rad:
		vector.x *= -1
		sound.play()
	if position.y <= pr.position.y + rad  or  position.y >= pr.end.y - rad:
		vector.y *= -1
		sound.play()

	# 碰撞检测和反弹
	var space = get_world_2d().direct_space_state
	var collision = space.get_rest_info(params)
	if collision:
		#print(collision)
		var normal = collision.normal
		vector = vector.bounce(normal)
		# 撞墙反弹减速（原版 ×0.25）
		vector *= 0.25
		sound.play()
		# exclude 是 Array[RID]：必须用 collision.rid，不能用 int 的 collider_id
		if not params.exclude.has(collision.rid):
			params.exclude.append(collision.rid)

	# 限制在可活动区域内
	position.x = clampf(position.x, pr.position.x + rad, pr.end.x - rad)
	position.y = clampf(position.y, pr.position.y + rad, pr.end.y - rad)

	# 设置Z轴顺序
	z_index = floori(global_position.y / MapData.cellSize) + 1

	# 应用移动
	position += vector * delta + gVec * delta

	# 速度足够小时触发爆炸
	if vector.length() <= 0.1  and  tween == null:
		addExplosion()
