extends "res://script/item.gd"

## 手榴弹物体脚本
# 继承自item.gd，实现手榴弹的物理行为和爆炸逻辑
# 手榴弹会在空中飞行、落地后弹跳，最终停止并爆炸

## 爆炸效果场景预加载
var explosion = preload("res://scene/explosion.tscn")

## 音效节点
@onready var sound = $sound
## 碰撞形状节点
@onready var shape = $shape
## 伤害值
@export var damage = 0

## 飞行方向向量
var vector = Vector2.ZERO
## 初始高度
var height = 25
## 飞行速度
var speed = 50
## 动画补间节点（用于延迟爆炸）
var tween = null
## 落地位置
var floorPos = Vector2.ZERO
## 是否已落地
var isOnFloor = false
## 飞行角度
var angle = 0
## 重力向量
var gVec = Vector2(0, -100)
## 物理形状查询参数
var params = PhysicsShapeQueryParameters2D.new()
@export var wRange = 0

## 初始化
func _ready() -> void:
	# 设置重力加速度
	gravity = 800
	
	# 计算飞行角度和速度
	angle = vector.angle()
	vector *= speed
	
	# 配置物理查询参数
	params.exclude = [ownerId]
	params.shape = shape.shape
	params.transform = Transform2D(global_rotation, global_position)
	params.collision_mask = collision_mask
	params.collide_with_areas = true


## 物理帧更新
func _physics_process(delta: float) -> void:
	if !isOnFloor:
		# 空中阶段：应用重力，减少高度
		gVec.y += gravity * delta
		height -= gVec.y * delta
		
		# 判断是否落地
		if height <= 0:
			isOnFloor = true
			gVec = Vector2.ZERO
	else:
		# 落地阶段：速度逐渐衰减
		vector = vector.lerp(Vector2.ZERO, 0.05)
	
	# 边界反弹检测
	if position.x <= itemSize.x / 2 || position.x >= MapData.mapSize.x - itemSize.x / 2:
		vector.x *= -1
		sound.play()
	if position.y <= itemSize.y / 2 || position.y >= MapData.mapSize.y - itemSize.y / 2:
		vector.y *= -1
		sound.play()
	
	# 碰撞检测和反弹
	var space = get_world_2d().direct_space_state
	var collision = space.get_rest_info(params)
	if collision:
		var normal = collision.normal
		vector = vector.bounce(normal)
		params.exclude.append(collision.collider_id)
	
	# 限制在地图边界内
	position.x = clamp(position.x, itemSize.x / 2, MapData.mapSize.x - itemSize.x / 2)
	position.y = clamp(position.y, itemSize.y / 2, MapData.mapSize.y - itemSize.y / 2)
	
	# 设置Z轴顺序
	z_index = floori(global_position.y / MapData.cellSize) + 1
	
	# 应用移动
	position += vector * delta + gVec * delta
	
	# 速度足够小时触发爆炸
	if vector.length() <= 0.1 && tween == null:
		addExplosion()


## 添加爆炸效果
# 延迟0.5秒后创建爆炸
func addExplosion():
	tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		var temp = explosion.instantiate()
		temp.global_position = global_position
		temp.collision_mask = collision_mask
		temp.damage = damage
		get_tree().current_scene.add_child(temp)
		)
	tween.tween_callback(queue_free)
