extends "res://script/item/item.gd"

## 爆炸效果脚本
##
## 半径与伤害衰减照原版（doc/03 §6.1 / §6.2）：
##   半径(格) = 2 + max(damage - 100, 0) × 0.005
##   伤害倍率 = 距离/半径 ≤ 0.5 → 1.00；≤ 0.75 → 0.75；≤ 1.0 → 0.50；> 1 → 不命中
## 所以改伤害会自动改半径（火箭 250 伤害 → 2.75 格，油桶 150 → 2.25 格）。
##
## 升级效果（doc/03 §6.4，字段在 item.gd 基类上）：
##   biggerBang     1 = BigBang，2 = BiggerBang → 爆出若干延迟子爆炸
##   clusterExplode > 0                          → 爆出 4 枚分裂爆
##
## 注意：子爆炸会把自己的 biggerBang / clusterExplode 清零，避免无限递归。


## 子爆炸延迟范围（秒）——原版是 2..5 帧，按 25fps 换算
const SUB_DELAY_MIN: float = 2.0 / 25.0

const SUB_DELAY_MAX: float = 5.0 / 25.0


## 伤害值
@export var damage: int = 0

## 爆炸半径覆盖（像素）；为 0 时按 damage 推导
@export var wRange: float = 0.0


## 爆炸类型
var explosionType: int = Game.explosionType.normal

## 已处理碰撞的对象列表（避免同一目标被多次结算）
var excludeObj: Array = []

## 本次爆炸的实际半径（像素）
var radius: float = 64.0

## 额外延迟（秒）——子爆炸用，原版是 mDelay
var mDelay: float = 0.0

## 是否已经爆开（子爆炸延迟期间不结算伤害）
var detonated: bool = false


## 碰撞形状节点
@onready var shapeNode: CollisionShape2D = $shape


func _ready() -> void:
	# 1) 算半径：优先用调用方指定的 wRange，否则按原版公式由伤害推导
	radius = wRange if wRange > 0.0 else (2.0 + maxf(damage - 100, 0) * 0.005) * MapData.cellSize

	# 2) 把碰撞圈撑到实际半径
	#    .tscn 里的 CircleShape2D 是所有实例共用的 sub_resource，必须 duplicate 后再改
	if shapeNode.shape is CircleShape2D:
		var circle: CircleShape2D = (shapeNode.shape as CircleShape2D).duplicate()
		circle.radius = radius
		shapeNode.shape = circle

	# 3) 子爆炸的延迟引爆
	if mDelay > 0.0:
		await get_tree().create_timer(mDelay).timeout
	detonated = true

	# 4) 画面 + 音效
	if explosionType == Game.explosionType.normal:
		ani.play("0")
	elif explosionType == Game.explosionType.air:
		ani.play("1")
	SfxManage.playExplosion()

	# 5) 升级带来的附加爆炸
	spawnCluster()
	spawnSubExplosions()

	await ani.animation_finished
	queue_free()


## 从重叠的 Area2D 反查"能挨打的节点"
# 角色：Area2D 的 owner（玩家/僵尸/恶魔本体）
# 物品：Area2D 自己（油桶/墙/地雷/充电包/手雷）
# 返回 null 表示这个 Area2D 不吃爆炸伤害
func resolveTarget(area: Area2D) -> Node2D:
	var t = area.get("type")
	if t != null and t is int:
		# 物品：排除爆炸自身，避免连锁递归
		if t != Game.itemType.Explosion and area.has_method("hit"):
			return area
		return null

	var ownerNode = area.owner
	if ownerNode != null and ownerNode.get("type") != null:
		if ownerNode.type in [Game.roleType.Player, Game.roleType.Zombie, Game.roleType.Devil]:
			if ownerNode.has_method("hit"):
				return ownerNode
	return null


## 结算伤害（角色是 3 参 hit，物品是 1 参 hit）
func applyDamage(target: Node2D, dmg: int) -> void:
	# friendlyFire 关闭时，爆炸不伤玩家（含自己踩雷/被队友炸）
	if target.get("type") == Game.roleType.Player and not MapData.friendlyFireOn():
		return

	if target.has_method("hit"):
		if target is Area2D:
			target.hit(dmg, Vector2.ZERO, Vector2.ZERO, true)
		else:
			target.hit(dmg, global_position, target.global_position - global_position, true)


## ClusterExplode：4 枚分裂爆（原版是 4 枚 CThing_Shot_ClusterShell 弹丸，
## 这里简化为 4 个偏移的延迟爆炸，效果等价且不需要额外的弹丸场景）
func spawnCluster() -> void:
	if clusterExplode <= 0:
		return
	var step := TAU / 4.0
	for i in range(4):
		var ang := step * i + randf() * step * 0.5 - step * 0.25
		var off := Vector2.RIGHT.rotated(ang) * radius * 0.75
		spawnSub(off, randf_range(SUB_DELAY_MIN, SUB_DELAY_MAX))


## BigBang / BiggerBang：环形延迟子爆炸
## 原版 BigBang 生成 6 个、BiggerBang 生成 4 个（后者反而更少，是原版的数值 bug，见 doc/03 §6.4）；
## 这里按文档建议改成单调递增的 6 / 10。
func spawnSubExplosions() -> void:
	var count := 0
	if biggerBang == 1:
		count = 6
	elif biggerBang >= 2:
		count = 10
	if count <= 0:
		return

	var step := TAU / count
	for i in range(count):
		var ang := step * i + randf() * step * 0.25 - step * 0.125
		var off := Vector2.RIGHT.rotated(ang) * randf_range(radius * 0.5, radius)
		spawnSub(off, randf_range(SUB_DELAY_MIN, SUB_DELAY_MAX))


## 生成一个子爆炸（不继承升级标志，防止递归）
func spawnSub(offset: Vector2, delay: float) -> void:
	var scene: PackedScene = load("res://scene/fx/explosion.tscn")
	if scene == null:
		return
	var t = scene.instantiate()
	t.global_position = global_position + offset
	t.damage = damage
	t.wRange = 0.0
	t.biggerBang = 0
	t.clusterExplode = 0
	t.mDelay = delay
	get_tree().current_scene.add_child(t)


## 物理帧更新：对范围内目标按距离衰减结算伤害
func _physics_process(_delta: float) -> void:
	if not detonated:
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

		var ratio: float = (
				global_position.distance_to(area.global_position) / radius
				if radius > 0.0 else 0.0)
		if ratio > 1.0:
			continue

		# 原版三段衰减：≤0.5 全伤，≤0.75 七五折，≤1.0 半伤
		var mul := 1.0
		if ratio > 0.75:
			mul = 0.5
		elif ratio > 0.5:
			mul = 0.75

		var dmg := int(round(damage * mul))
		if dmg <= 0:
			continue

		excludeObj.append(rid)
		applyDamage(target, dmg)
