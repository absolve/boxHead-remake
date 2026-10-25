extends Area2D

## 恶魔火球
##
## 数值出处：`doc/04 §3.3`（原版 CThing_Shot_FireBall）
##   速度       0.15 格/tick  → 0.15 × 25 × 32 = 120 px/s
##   打人伤害   mAttackDamage = 50
##   拆物伤害   10000（原版用 10000 打可破坏物、100000 拆墙）
##   命中判定   碰撞半径 0.1 格（约 3.2px），判定区半径 0.25 格（约 8px）
##   射程       受恶魔 mAttackRange = 5 格 限制，由恶魔自己判断要不要开火
##
## 原版火球有一行 `mDelta.ScaleN(1.02)` 想每帧加速 2%，但返回值没被使用、实际无效，
## 所以这里也**不做加速**，保持匀速。


## 打人的伤害
@export var damage: int = 50

## 拆物/拆墙的伤害（原版 10000，比任何血量都大，等于必碎）
@export var objectDamage: int = 10000

## 飞行速度（像素/秒）
@export var speed: float = 120.0

## 命中判定圆半径（像素）
@export var hitRadius: float = 8.0

## 最长存活时间（秒），防止飞出地图后一直存在
@export var lifeTime: float = 4.0


## 飞行方向（单位向量）
var dir: Vector2 = Vector2.RIGHT

## 开火者，用于避免打到自己
var shooter: Node2D = null

## 已命中的对象，避免同一目标重复结算
var excludeObj: Array = []

## 剩余存活时间
var timeLeft: float = 0.0


## 命中半径节点
@onready var shapeNode: CollisionShape2D = $shape


func _ready() -> void:
	timeLeft = lifeTime

	# 判定圆按 hitRadius 设置（sub_resource 共享，必须 duplicate）
	if shapeNode.shape is CircleShape2D:
		var circle: CircleShape2D = (shapeNode.shape as CircleShape2D).duplicate()
		circle.radius = hitRadius
		shapeNode.shape = circle

	z_index = 200


## 从重叠区域反查能吃火球伤害的节点
func resolveTarget(area: Area2D) -> Node2D:
	# 可破坏物品（油桶/墙/地雷/充电包/手雷）
	var t = area.get("type")
	if t != null and t is int:
		if t != Game.itemType.Explosion and area.has_method("hit"):
			return area
		return null

	# 角色本体（挂在 Area2D 的 owner 上）
	var ownerNode = area.owner
	if ownerNode == null or not is_instance_valid(ownerNode):
		return null
	if ownerNode == shooter:
		return null
	if ownerNode.get("type") != null and ownerNode.type in [
			Game.roleType.Player, Game.roleType.Zombie, Game.roleType.Devil]:
		if ownerNode.has_method("hit"):
			return ownerNode
	return null


func _physics_process(delta: float) -> void:
	global_position += dir * speed * delta

	timeLeft -= delta
	if timeLeft <= 0.0:
		queue_free()
		return

	for area in get_overlapping_areas():
		if area == null or not is_instance_valid(area):
			continue
		var rid = area.get_rid()
		if excludeObj.has(rid):
			continue

		var target = resolveTarget(area)
		if target == null:
			continue
		excludeObj.append(rid)

		if target is Area2D:
			# 可破坏物：原版用 10000，必定打碎
			target.hit(objectDamage)
		else:
			# recoil 传 -1：火球只造成伤害，不产生击退
			# （原版击退由武器/近战各自的参数决定，火球没有击退）
			target.hit(damage, global_position, -1)

		queue_free()
		return
