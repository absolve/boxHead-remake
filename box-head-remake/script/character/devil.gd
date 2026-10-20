class_name Devil
extends "res://script/character/character.gd"

## 恶魔敌人脚本（宿主）
##
## 只保留"宿主能力"：数值、取目标、流场取方向、动画、火球、受伤与死亡。
## 具体行为已拆到 StateMachine 下的 5 个状态节点：
## [code]Chase / Turn / Attack / Hurt / Dead[/code]，见 [code]script/character/devil_states/[/code]。
##
## 数值全部来自原版 `CThing_Creature_Devil.as`（doc/04 §3.1）：
##   mMaxLife 1000 / mSpeed 0.04 格/tick（= 32 px/s）/ mAttackRange 5 格（= 160 px）
##   mAttackDamage 50 / mMass 5 / mScore 1000 / mHeight 1.8 / 半径 0.42
##   mFireRate 0 → 每次攻击动画都能开火，没有独立冷却
##   mFireRateCount 初值 5 tick → 出生后约 0.2 秒才能打第一发

## 火球场景
const FIREBALL := preload("res://scene/projectile/fireball.tscn")

## 攻击伤害（mAttackDamage）
@export var damage: int = 50
## 攻击距离（像素）：原版 5 格 × 32
@export var attackRange: float = 160.0
## 火球速度（像素/秒）：原版 0.15 格/tick
@export var fireballSpeed: float = 120.0
## 攻击动画的判定帧（原版在攻击动画第 3 帧生成火球）
@export var attackHitFrame: int = 3
## 两次攻击之间的最短间隔（秒）
@export var attackDelay: float = 0.4
## 出生后的首发延迟（秒）：原版 mFireRateCount = 5 tick
@export var firstAttackDelay: float = 0.2
## 受击硬直（秒）
@export var hurtDelay: float = 0.4
## 重新取目标的间隔（秒）
@export var targetRefreshInterval: float = 0.5

## 当前目标
var target = null
## 是否正面受击
var hitFromFront: bool = true
## 目标刷新计时
var targetTimer: float = 0.0

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
	target = findTarget()

	fsm.start(&"Chase")


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


# ---------------------------------------------------------------- 移动

## 流场方向；站在障碍格内时退化为朝目标的自由方向
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
	if not hasTarget():
		return
	var f = FIREBALL.instantiate()
	# 出生点：本体 + 朝向 × 1.5 倍半径（原版 NaN 时的回退方案）
	var offset: Vector2 = Zombie.vectorFromAngle(angle) * (0.42 * 1.5 * MapData.cellSize)
	f.global_position = global_position + offset
	f.dir = (target.global_position - global_position).normalized()
	f.damage = damage
	f.speed = fireballSpeed
	f.shooter = self
	get_tree().current_scene.add_child(f)


## 受伤（子弹/爆炸调用）
func hit(_damage: int, _attackPos: Vector2, recoil: float = 0) -> void:
	if isDead:
		return

	hp -= _damage
	if hp <= 0:
		die()
		return

	var attackerDir := Zombie.angleFromVector(_attackPos - global_position)
	var diff := wrapi(attackerDir - angle, 0, 8)
	hitFromFront = diff <= 1 or diff >= 7
	velocity = (global_position - _attackPos).normalized() * recoil

	fsm.transitionTo(&"Hurt")


func die() -> void:
	isDead = true
	fsm.transitionTo(&"Dead")
	fsm.enabled = false
	Game.enemyKilled.emit(global_position)


## 供 Dead 状态调用：关闭碰撞与受击
func disableHitbox() -> void:
	body.monitorable = false
	body.monitoring = false
	bodyShape.disabled = true
	shape.disabled = true


# ---------------------------------------------------------------- Godot 内置

func _physics_process(_delta: float) -> void:
	# 与状态无关的公共处理：限制在地图内 + 按 Y 排序
	if not isDead:
		position.x = clampf(position.x, bodySize.x / 2.0, MapData.mapSize.x - bodySize.x / 2.0)
		position.y = clampf(position.y, bodySize.y / 2.0, MapData.mapSize.y - bodySize.y / 2.0)
	z_index = roundi(global_position.y / MapData.cellSize) + 1
