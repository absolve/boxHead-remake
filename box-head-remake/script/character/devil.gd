class_name Devil
extends "res://script/character/character.gd"

## 恶魔敌人脚本（宿主）
##
## 只保留"宿主能力"：数值、取目标、流场取方向、攻击判定、拆障碍、动画、火球、受伤与死亡。
## 具体行为已拆到 StateMachine 下的状态节点：
## [code]EnterMap / RemoveObject / Chase / Turn / Attack / TrackTarget / Hurt / Dead[/code]，
## 见 [code]script/character/devil_states/[/code]。
##
## 数值全部来自原版 `CThing_Creature_Devil.as`（doc/04 §3.1）：
##   mMaxLife 1000 / mSpeed 0.04 格/tick（= 32 px/s）/ mAttackRange 5 格（= 160 px）
##   mAttackDamage 50 / mMass 5 / mScore 1000 / mHeight 1.8 / 半径 0.42
##   mFireRate 0 → 每次攻击动画都能开火，没有独立冷却
##   mFireRateCount 初值 5 tick → 出生后约 0.2 秒才能打第一发


## 火球场景
const FIREBALL: PackedScene = preload("res://scene/projectile/fireball.tscn")


## 攻击伤害（mAttackDamage）
@export var damage: int = 50
## 拆障碍伤害（原版 CThing_Affect_DevilAttack 传 100000，直接摧毁假墙/油桶）
@export var objectDamage: int = 100000
## 攻击距离（像素）：原版 5 格 × 32
@export var attackRange: float = 160.0
## 火球速度（像素/秒）：原版 0.15 格/tick
@export var fireballSpeed: float = 120.0
## 攻击动画的判定帧（原版在攻击动画第 3 帧生成火球）
@export var attackHitFrame: int = 3
## 没有 attack 动画时的开火间隔（秒）；有动画时由动画长度决定节奏
@export var attackDelay: float = 0.4
## 出生后的首发延迟（秒）：原版 mFireRateCount = 5 tick
@export var firstAttackDelay: float = 0.2
## 受击硬直（秒）
@export var hurtDelay: float = 0.4
## 重新取目标的间隔（秒）
@export var targetRefreshInterval: float = 0.5
## 当前目标
var target: Node2D = null
## 目标刷新计时
var targetTimer: float = 0.0
## 出生首发延迟倒计时（原版 mFireRateCount = 5 tick）
var firstAttackTimer: float = 0.0
## 击退位移（单位：格/帧，Hurt 状态里再 ×cellSize）
var knockbackDelta: Vector2 = Vector2.ZERO
## 剩余击退帧数
var knockbackFrames: int = 0


## 状态机（devil.tscn 里的 StateMachine 子节点）
@onready var fsm: StateMachine = $StateMachine
## 身体受击区域
@onready var body: Area2D = $body
## 身体受击形状
@onready var bodyShape: CollisionShape2D = $body/bodyShape


func _ready() -> void:
	# 由 map.gd 在 add_child 前写入的出生方向速度，换算成初始朝向
	if velocity.length() != 0:
		angle = Zombie.angleFromVector(velocity)
	oldAngle = angle
	targetTimer = 0.0
	firstAttackTimer = firstAttackDelay
	target = findTarget()

	fsm.start(&"EnterMap")


# ---------------------------------------------------------------- 目标


func findTarget() -> Node2D:
	var best: Node2D = null
	var bestDis := INF
	for p in get_tree().get_nodes_in_group("player"):
		if p == null or not is_instance_valid(p) or p.get("isDead") == true:
			continue
		var dis: float = global_position.distance_squared_to(p.global_position)
		if dis < bestDis:
			bestDis = dis
			best = p
	return best


func hasTarget() -> bool:
	return target != null and is_instance_valid(target) and target.get("isDead") != true


func refreshTarget(delta: float) -> bool:
	targetTimer -= delta
	if targetTimer <= 0.0 or not hasTarget():
		targetTimer = targetRefreshInterval
		target = findTarget()
	return hasTarget()


func targetId() -> int:
	if hasTarget() and target.get("playerId") != null:
		return int(target.playerId)
	return 1


func dirToTarget() -> int:
	if not hasTarget():
		return angle
	return Zombie.angleFromVector(target.global_position - global_position)


func targetInRange() -> bool:
	if not hasTarget():
		return false
	return global_position.distance_squared_to(target.global_position) <= attackRange * attackRange


func isFacingTarget() -> bool:
	return hasTarget() and angle == dirToTarget()


## 原版 mFireRateCount <= 0：出生首发延迟已经过去
func attackReady() -> bool:
	return firstAttackTimer <= 0.0


## 原版 State_Attack_Decision：冷却 + 目标存活 + 同向 + 射程 + 通视
func canAttack() -> bool:
	return (attackReady() and hasTarget() and isFacingTarget()
			and targetInRange() and hasLineOfSight())


## 视线检测：原版用 Collide_Line(..., mAffect_PlayerLineOfSight)
##
## 这里用一条射线近似：线路上先撞到墙或可破坏物就算不通视。
## 玩家自己不在射线的碰撞掩码里，所以不会被自己挡住。
func hasLineOfSight() -> bool:
	if not hasTarget():
		return false
	var query := PhysicsRayQueryParameters2D.create(
			global_position, target.global_position,
			MapData.LAYER_WALL | MapData.LAYER_ITEM)
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# ---------------------------------------------------------------- 移动


## 流场方向；站在障碍格内时退化为朝目标的自由方向
##
## 原版 `Nav_Direction(..., mCollide_NonMovable, true)` 的最后一个参数 forceIt
## 表示"不受全扫描配额限制"。恶魔直接读 BFS 流场（整张图都有方向，没有扫描配额），
## 所以不需要这个参数；[code]Zombie.navDirection()[/code] 只给逐格行走的僵尸使用。
func flowDirection() -> Vector2:
	var cell := MapData.worldToCell(global_position)
	if MapData.isObstacle(cell):
		return freeDirectionTowardsTarget()
	var dir: Vector2 = MapData.getFlowDir(global_position, targetId())
	if dir == Vector2.ZERO:
		dir = freeDirectionTowardsTarget()
	return dir


func freeDirectionTowardsTarget() -> Vector2:
	var want := Vector2.ZERO
	if hasTarget():
		want = (target.global_position - global_position).normalized()
	if want == Vector2.ZERO:
		want = Zombie.vectorFromAngle(angle)

	var best := Vector2.ZERO
	var bestDot := -INF
	for d in Zombie.DIRS:
		var dot := d.normalized().dot(want)
		if dot > bestDot:
			bestDot = dot
			best = d
	return best


func moveInDirection(dir: Vector2, delta: float) -> void:
	if dir == Vector2.ZERO:
		return
	velocity = dir.normalized() * speed
	move_and_collide(velocity * delta)


# ---------------------------------------------------------------- 拆障碍


## 当前所在格
func cellPosition() -> Vector2i:
	return MapData.worldToCell(global_position)


## 正前方（相邻一格）的格子坐标
func frontCell() -> Vector2i:
	return cellPosition() + Zombie.dirStep(angle)


## 正前方的可破坏物（假墙 / 油桶）；没有返回 null
func frontObject() -> Node:
	return objectAtCell(frontCell())


## 朝向 direction 的相邻格里的可破坏物
func objectInDirection(direction: int) -> Node:
	return objectAtCell(cellPosition() + Zombie.dirStep(direction))


## 某格里的可破坏物（假墙 / 油桶）
##
## 两条查找路径缺一不可：
##   1) 玩家放置的物体登记在 MapData.mapTile；
##   2) 房间场景里预摆的油桶/假墙不登记 mapTile（见 room_generic.registerItemObstacles），
##      只能用物品层（layer 4）的点查询把它们找出来。
func objectAtCell(cell: Vector2i) -> Node:
	var id = MapData.mapTile.get(MapData.cellKey(cell))
	if id != null and is_instance_id_valid(int(id)):
		var placed = instance_from_id(int(id))
		if isBreakableObject(placed):
			return placed as Node

	var params := PhysicsPointQueryParameters2D.new()
	params.position = MapData.cellCenter(cell)
	params.collision_mask = MapData.LAYER_ITEM
	params.collide_with_areas = true
	params.collide_with_bodies = false
	for result in get_world_2d().direct_space_state.intersect_point(params, 8):
		var found = result.get("collider")
		if isBreakableObject(found):
			return found as Node
	return null


## 是否是恶魔能拆的物体：假墙（Wall）或油桶（Barrel）
func isBreakableObject(obj: Node2D) -> bool:
	if obj == null or not is_instance_valid(obj):
		return false
	if not obj.has_method("hit"):
		return false
	var t = obj.get("type")
	if t == null or not (t is int):
		return false
	return t == Game.itemType.Wall or t == Game.itemType.Barrel


# ---------------------------------------------------------------- 动画


## 播放动画；缺素材时静默跳过
func playAnim(kind: String, force: bool = false) -> void:
	if ani == null or ani.sprite_frames == null:
		return
	var animName := "%s_%d" % [kind, angle]
	if not ani.sprite_frames.has_animation(animName):
		return
	if force or ani.animation != animName:
		ani.play(animName)


func isAnimPlaying() -> bool:
	return ani != null and ani.is_playing()


## 当前朝向是否有某种动画（素材缺失时用来退化处理）
func hasAnim(kind: String) -> bool:
	if ani == null or ani.sprite_frames == null:
		return false
	return ani.sprite_frames.has_animation("%s_%d" % [kind, angle])


func playFallAnim() -> void:
	var animName := "fallDown_%d" % int(angle / 2.0)
	if ani != null and ani.sprite_frames != null and ani.sprite_frames.has_animation(animName):
		ani.play(animName)


# ---------------------------------------------------------------- 攻击 / 受伤


## 发射火球（原版在攻击动画第 3 帧、从双手平均位置生成）
func fireFireball() -> void:
	var f = FIREBALL.instantiate()
	# 出生点：本体 + 朝向 × 1.5 倍半径（原版 NaN 时的回退方案）
	var offset: Vector2 = Zombie.vectorFromAngle(angle) * (0.42 * 1.5 * MapData.cellSize)
	f.global_position = global_position + offset
	# 原版用进入攻击时锁定的 mAttackAngle（8 方向量化）；开火前已经对准目标，
	# 所以直接取当前朝向，不做"追踪玩家"的实时瞄准。
	f.dir = Zombie.vectorFromAngle(angle)
	f.damage = damage
	f.speed = fireballSpeed
	f.shooter = self
	get_tree().current_scene.add_child(f)


## 受伤（子弹/爆炸调用）
## 受击；签名与 Zombie.hit 保持一致（爆炸会传第 4 个参数）
func hit(dmg: int, _attackPos: Vector2 = Vector2.ZERO,
		knockDir: Vector2 = Vector2.ZERO, fromExplosion: bool = false) -> void:
	if isDead or dying:
		return

	hp -= dmg
	MapData.addBlood(global_position, 2.5 if hp <= 0 else 1.2)

	# 致命伤：先标记 dying 并进入 Hurt（被打飞），Hurt 结束再 die()
	if hp <= 0:
		dying = true

	# 原版不区分前后：受击动画随机二选一，不再算夹角

	# 和僵尸同一套击退模型：先切状态，再设置击退增量
	fsm.transitionTo(&"Hurt")
	# 击退方向由调用方给；ZERO = 不推
	if knockDir == Vector2.ZERO:
		return
	beginKnockback(knockDir, knockbackSpeed(dmg, fromExplosion))
	# 硬直 = 击退帧数 + 3 tick（和僵尸同一套原版公式）
	hurtDelay = hurtTimeFrom(knockbackFrames)


## 由击退速度算出每帧位移（格/帧）和持续帧数（每帧衰减 0.65）
func beginKnockback(dir: Vector2, speed: float) -> void:
	knockbackDelta = dir.normalized() * speed / MapData.TICKS_PER_SEC / MapData.cellSize
	knockbackFrames = 0
	var l: float = knockbackDelta.length()
	while l >= 0.01:
		knockbackFrames += 1
		l *= 0.65


func die() -> void:
	isDead = true
	fsm.transitionTo(&"Dead")
	fsm.enabled = false
	Game.enemyKilled.emit(global_position, 1000)


## 供 Dead 状态调用：关闭碰撞与受击
func disableHitbox() -> void:
	body.monitorable = false
	body.monitoring = false
	bodyShape.disabled = true
	shape.disabled = true


# ---------------------------------------------------------------- Godot 内置


func _physics_process(delta: float) -> void:
	# 原版 Process_Normal 每 tick 递减 mFireRateCount
	if firstAttackTimer > 0.0:
		firstAttackTimer = maxf(firstAttackTimer - delta, 0.0)

	# 与状态无关的公共处理：限制在地图内 + 按 Y 排序
	if not isDead:
		position.x = clampf(position.x, bodySize.x / 2.0, MapData.mapSize.x - bodySize.x / 2.0)
		position.y = clampf(position.y, bodySize.y / 2.0, MapData.mapSize.y - bodySize.y / 2.0)
	z_index = roundi(global_position.y / MapData.cellSize) + 1
