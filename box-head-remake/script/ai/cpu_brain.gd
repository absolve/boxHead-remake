class_name CpuBrain
extends Node

## CPU 玩家的"大脑"：Beehave 行为树 + Area2D 感知 + 策略/武器选择
##
## 挂在 Player 节点下面（Player 会自动认领为 cpuBrain）。树只写"意图"：
##   player.cpuMoveDir / cpuAimDir / cpuWantFire
## 移动与开火仍由 Player 的 Idle 状态执行，Hurt / Dead 由状态机接管。
##
## 树结构（运行时搭出来，方便和测试场景一起迭代）：
##   SequenceReactive root
##   ├── CanAct
##   ├── Perceive
##   ├── PickStrategy
##   └── SelectorReactive behaviour
##       ├── dodge    FireballIncoming → Dodge
##       ├── rescue   ShouldRescue → Rescue
##       ├── retreat  ShouldRetreat → Retreat
##       ├── combat   HasTarget → PickWeapon → MoveToRange → FireIfSafe
##       ├── search   HasLastKnown → MoveToLastKnown
##       ├── follow   HasAlly → FollowAlly
##       └── idle

const LEAF_DIR := "res://script/ai/leaves/"
## 物理层（project.godot）：敌人本体 / 敌人受击区 / 危险物（恶魔火球）/ 可拆物品（油桶、墙）
const LAYER_ENEMY := 2
const LAYER_ENEMY_BODY := 32
const LAYER_ITEM := 4
const LAYER_HAZARD := 128
## 低血求生：血量比例低于它就优先找箱子 / 拉开距离
const SURVIVE_HP_RATIO := 0.25

## 主策略
enum Strategy { AGGRESSIVE, DEFENSIVE, SUPPORT, KITER, PATROL }

## 感知半径（像素）：默认 12 格
@export var senseRadius: float = 384.0
## 行为树 tick 间隔（帧）：6 帧 ≈ 0.1s（Beehave 的 tick_rate 按帧算）
@export var tickEveryFrames: int = 6
## 换枪冷却（毫秒）
@export var switchCooldownMs: int = 2000
## 策略驻留时间（毫秒）：非强制切换时，至少隔这么久才重评
@export var strategyDwellMs: int = 15000
## 性格：-1 = 按 playerId 自动分配（3 突进 / 4 防守 / 5 放风筝）
@export var personality: int = -1


var player: Player = null
var area: Area2D = null
var tree: BeehaveTree = null
var board: Blackboard = null
## 感知结果
var target: Node2D = null
var hazards: Array = []
## 范围内的油桶 / 墙（可拆物品）
var props: Array = []
## 低血时最近的补给箱
var boxTarget: Node2D = null
## 目标记忆：丢失目标后去最后看到的位置找 1.2 秒
var targetSeenMs: int = 0
var lastKnownPos: Vector2 = Vector2.ZERO
var hasLastKnown: bool = false
## 换枪冷却
var lastSwitchMs: int = 0
## 策略
var strategy: int = Strategy.DEFENSIVE
var strategySinceMs: int = 0
## 手动覆盖策略到该时间点（测试用：T 键轮换后 20 秒内不被自动策略改回）
var manualUntilMs: int = 0
var anchorPos: Vector2 = Vector2.ZERO
var _lastStrategyEvalMs: int = 0

## 巡逻（没敌人时用）：一格一格走，走一段歇一会，不乱窜
@export var patrolLeashCells: float = 5.0
var patrolHome: Vector2 = Vector2.ZERO
var patrolDir: Vector2 = Vector2.ZERO
var patrolSteps: int = 0
var patrolLastCell: Vector2i = Vector2i(-9999, -9999)
var patrolWaitUntilMs: int = 0


func _ready() -> void:
	player = get_parent() as Player
	if player == null:
		push_warning("CpuBrain 必须挂在 Player 节点下")
		return
	player.cpuBrain = self
	anchorPos = player.global_position
	strategy = personalityOf()
	strategySinceMs = Time.get_ticks_msec()
	buildPerception()
	buildTree()


## Area2D 感知：一次查询拿到范围内的敌人（本体 + 受击区）和火球
func buildPerception() -> void:
	area = Area2D.new()
	area.name = "Perception"
	area.collision_layer = 0
	area.collision_mask = LAYER_ENEMY | LAYER_ENEMY_BODY | LAYER_ITEM | LAYER_HAZARD
	area.monitoring = true
	area.monitorable = false

	var cs := CollisionShape2D.new()
	cs.name = "Shape"
	var circle := CircleShape2D.new()
	circle.radius = senseRadius
	cs.shape = circle
	area.add_child(cs)
	# 注意：必须挂在玩家（Node2D）下面。挂在 brain（普通 Node）下面时，
	# Area2D 的变换相对画布原点，会永远停在 (0,0)，探不到身边的敌人。
	#
	# 用 deferred：map.gd 先把 brain 挂到玩家、再把玩家加进树，
	# brain._ready 执行时玩家正在建自己的子节点，直接 add_child 会报
	# "Parent node is busy setting up children" 并静默失败，
	# 结果就是正式地图里的 CPU 全部看不见敌人（只会巡逻挨打）。
	# 用 deferred：无论在 _ready 还是 tree_entered 里，玩家都可能正处于
	# "busy setting up children" 状态，直接 add_child 会报错并静默失败，
	# 结果就是正式地图里的 CPU 全部看不见敌人（只会巡逻挨打）。
	player.add_child.call_deferred(area)


## 用代码拼行为树：先把整棵子树建好，再挂进场景，避免 BeehaveTree 空树 tick
func buildTree() -> void:
	tree = BeehaveTree.new()
	tree.name = "BehaviourTree"
	tree.actor = player
	tree.tick_rate = maxi(tickEveryFrames, 1)

	var root := _sequence("root", [
		["can_act", true],
		["perceive", true],
		["pick_strategy", false],
	])

	var behaviour := SelectorReactiveComposite.new()
	behaviour.name = "behaviour"
	root.add_child(behaviour)

	behaviour.add_child(_sequence("dodge", [["fireball_incoming", true], ["dodge", false]]))
	behaviour.add_child(_sequence("survive", [["should_survive", true], ["survive", false]]))
	behaviour.add_child(_sequence("rescue", [["should_rescue", true], ["rescue", false]]))
	behaviour.add_child(_sequence("retreat", [["should_retreat", true], ["retreat", false]]))
	behaviour.add_child(_sequence("demolish", [["should_demolish", true], ["demolish", false]]))
	behaviour.add_child(_sequence("combat", [
		["has_target", true], ["pick_weapon", false],
		["move_to_range", false], ["fire_if_safe", false],
	]))
	behaviour.add_child(_sequence("search", [["has_last_known", true], ["move_to_last_known", false]]))
	behaviour.add_child(_sequence("patrol", [["should_patrol", true], ["patrol", false]]))
	behaviour.add_child(_sequence("follow", [["has_ally", true], ["follow_ally", false]]))
	behaviour.add_child(_makeLeaf("idle", false))

	tree.add_child(root)
	add_child(tree)
	board = tree.blackboard


func _sequence(nodeName: String, children: Array) -> SequenceReactiveComposite:
	# 用 Reactive 版：条件每个 tick 都重新判断（普通 Sequence 会跳过已成功的子节点）
	var s := SequenceReactiveComposite.new()
	s.name = nodeName
	for c in children:
		s.add_child(_makeLeaf(str(c[0]), bool(c[1])))
	return s


func _makeLeaf(leafName: String, isCondition: bool) -> BeehaveNode:
	var n: BeehaveNode = ConditionLeaf.new() if isCondition else ActionLeaf.new()
	n.name = leafName
	var sc := load(LEAF_DIR + leafName + ".gd") as Script
	if sc == null:
		push_error("缺少 CPU 行为树叶子脚本: %s" % leafName)
	else:
		n.set_script(sc)
	return n


# ---------------------------------------------------------------- 感知

## 刷新感知：敌人（带目标粘滞与记忆）+ 危险物
func scan() -> void:
	var now := Time.get_ticks_msec()
	_scanHazards()
	_scanProps()
	_scanBox()

	var candidates := _collectEnemies()
	var best: Node2D = null
	var bestScore := -INF
	for e in candidates:
		var s: float = _targetScore(e)
		if s > bestScore:
			bestScore = s
			best = e

	# 粘滞：原目标还有效且新目标优势不到 15%，就继续打原目标
	if _validEnemy(target):
		var cur: float = _targetScore(target)
		if cur > 0.0 and bestScore <= cur * 1.15:
			best = target

	target = best
	if target != null:
		targetSeenMs = now
		lastKnownPos = target.global_position
		hasLastKnown = true
	elif hasLastKnown and now - targetSeenMs > 1200:
		hasLastKnown = false


func _scanHazards() -> void:
	hazards.clear()
	if area == null:
		return
	for a in area.get_overlapping_areas():
		if a.is_in_group("hazard"):
			hazards.append(a)
	# 兜底：万一火球没被 Area2D 捕捉（层级配置问题），按组补一次；场景里火球通常个位数
	if hazards.is_empty():
		var r2: float = senseRadius * senseRadius
		for h in get_tree().get_nodes_in_group("hazard"):
			if is_instance_valid(h) \
					and player.global_position.distance_squared_to(h.global_position) <= r2:
				hazards.append(h)


## 收集范围内的可拆物品（油桶 / 墙）
func _scanProps() -> void:
	props.clear()
	if area == null:
		return
	for a in area.get_overlapping_areas():
		if a.is_in_group("hazard"):
			continue
		var n: Node = a.owner if a.owner != null else a
		var t = n.get("type")
		if t == Game.itemType.Barrel or t == Game.itemType.Wall:
			if not props.has(n):
				props.append(n)


## 低血时找最近的补给箱（血量 > 50% 不找，因为箱子只给武器）
func _scanBox() -> void:
	boxTarget = null
	if player == null:
		return
	var hpRatio := float(player.hp) / maxf(float(player.maxHp), 1.0)
	if hpRatio > 0.5:
		return
	var best := INF
	var limit := 14.0 * MapData.cellSize
	for b in get_tree().get_nodes_in_group("box"):
		if not is_instance_valid(b):
			continue
		var d: float = player.global_position.distance_squared_to(b.global_position)
		if d < best and d <= limit * limit:
			best = d
			boxTarget = b


## 收集范围内的敌人（本体 + 受击区，按实例去重）
func _collectEnemies() -> Array:
	var seen := {}
	var out: Array = []
	if area == null:
		return out
	for b in area.get_overlapping_bodies():
		if not isEnemy(b):
			continue
		var id := b.get_instance_id()
		if not seen.has(id):
			seen[id] = true
			out.append(b)
	for a in area.get_overlapping_areas():
		if a.is_in_group("hazard"):
			continue
		var n: Node = a.owner if a.owner != null else a
		if not isEnemy(n):
			continue
		var id2 := n.get_instance_id()
		if not seen.has(id2):
			seen[id2] = true
			out.append(n)
	return out


func _validEnemy(n: Node) -> bool:
	if not isEnemy(n):
		return false
	if n.get("isDead") == true:
		return false
	return player.global_position.distance_to(n.global_position) <= senseRadius * 1.1


## 目标打分：距离 × 威胁 × 队友受威胁加成 × 被队友锁定的惩罚
func _targetScore(e: Node2D) -> float:
	if not isEnemy(e) or e.get("isDead") == true:
		return 0.0
	var d: float = player.global_position.distance_to(e.global_position)
	if d > senseRadius * 1.1:
		return 0.0
	var distScore := 1.0 / (1.0 + d / 96.0)
	var threat := 1.4 if e.get("type") == Game.roleType.Devil else 1.0
	var allyBonus := 1.0
	var ally := nearestAlly()
	if ally != null and ally.global_position.distance_to(e.global_position) < 3.0 * MapData.cellSize:
		allyBonus = 1.25

	var claim := 1.0
	for other in get_tree().get_nodes_in_group("player"):
		if other == player or not is_instance_valid(other):
			continue
		if other.get("isCpu") != true:
			continue
		var ob := other.cpuBrain as CpuBrain
		if ob != null and ob != self and ob.target == e:
			claim = 0.75
			break

	return distScore * threat * allyBonus * claim


func isEnemy(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	var t = n.get("type")
	return t == Game.roleType.Zombie or t == Game.roleType.Devil


## 最近的人类队友（跳过 CPU 与已死亡）
func nearestAlly() -> Player:
	var best: Player = null
	var bestD := INF
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p == null or p == player or not is_instance_valid(p) or p.isCpu or p.isDead:
			continue
		var d: float = player.global_position.distance_squared_to(p.global_position)
		if d < bestD:
			bestD = d
			best = p
	return best


## 场上还活着的真人玩家数量（CPU 不计入；死亡的不计）
func livingHumanCount() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p == null or not is_instance_valid(p):
			continue
		if p.isCpu or p.isDead:
			continue
		n += 1
	return n


## 单人生存模式：没有活着的真人队友（人类全死了）
##   这时不守尸体、不等复活，优先自保：拉远距离、见势不妙就跑
func isSolo() -> bool:
	return livingHumanCount() == 0


## 某点附近最近的敌人（救援时用来找"威胁队友的那只"）
func enemyNear(pos: Vector2, radius: float) -> Node2D:
	var best: Node2D = null
	var bestD: float = radius * radius
	for n in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(n) or n.get("isDead") == true:
			continue
		var d: float = pos.distance_squared_to(n.global_position)
		if d < bestD:
			bestD = d
			best = n
	return best


# ---------------------------------------------------------------- 导航

## 刷新敌人源距离场（多个 CPU 共享，内部按时间/障碍变化节流）
func ensureField() -> void:
	MapData.ensureCpuField()


## 这一步能不能走：静态障碍（墙/油桶）+ 动态占格（玩家/敌人）+ 可玩区域
##
## ignore 一般传"当前目标"：否则目标自己占的格子会把接近路线挡掉。
func canStepTo(pos: Vector2, step: Vector2, ignore: Node = null) -> bool:
	var target: Vector2 = pos + step
	if not MapData.getPlayRect().has_point(target):
		return false
	if MapData.isObstacle(MapData.worldToCell(target)):
		return false
	if player.blockedByCell(target):
		return false
	return not cellOccupiedByCharacter(MapData.worldToCell(target), ignore)


## 这一格是不是被别的角色占着（玩家 / 敌人）；ignore 用于放过目标本人
func cellOccupiedByCharacter(cell: Vector2i, ignore: Node = null) -> bool:
	var center: Vector2 = MapData.cellCenter(cell)
	var r2: float = pow(MapData.cellSize * 0.75, 2.0)
	for n in get_tree().get_nodes_in_group("player"):
		if n == player or n == ignore or not is_instance_valid(n):
			continue
		if n.get("isDead") == true:
			continue
		if n.global_position.distance_squared_to(center) < r2:
			return true
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == ignore or not is_instance_valid(e):
			continue
		if e.get("isDead") == true:
			continue
		if e.global_position.distance_squared_to(center) < r2:
			return true
	return false


## 走位方向：直线能走就直走；被挡（墙/人/敌人）就用距离场或侧向绕
func pathDir(pos: Vector2, desired: Vector2, ignore: Node = null) -> Vector2:
	if desired == Vector2.ZERO:
		return Vector2.ZERO
	var step: Vector2 = desired.normalized() * MapData.cellSize
	if canStepTo(pos, step, ignore):
		return desired
	var fdir := MapData.cpuFieldDir(pos)
	if fdir != Vector2.ZERO and canStepTo(pos, fdir * MapData.cellSize, ignore):
		return fdir
	var side := desired.orthogonal()
	for s in [side, -side]:
		if canStepTo(pos, s * MapData.cellSize, ignore):
			return s
	return desired


## 只做直线 + 侧移的走位（不查敌人源距离场）
## 低血去找箱子时用：避免"绕路时被距离场带着往敌人那边跑"
func pathDirSimple(pos: Vector2, desired: Vector2, ignore: Node = null) -> Vector2:
	if desired == Vector2.ZERO:
		return Vector2.ZERO
	var step: Vector2 = desired.normalized() * MapData.cellSize
	if canStepTo(pos, step, ignore):
		return desired
	var side := desired.orthogonal()
	for s in [side, -side]:
		if canStepTo(pos, s * MapData.cellSize, ignore):
			return s
	return desired


# ---------------------------------------------------------------- 策略

func personalityOf() -> int:
	if personality >= 0:
		return personality
	var pid := player.playerId if player != null else 0
	match pid:
		3:
			return Strategy.AGGRESSIVE
		5:
			return Strategy.KITER
		_:
			return Strategy.DEFENSIVE


func strategyName() -> String:
	match strategy:
		Strategy.AGGRESSIVE:
			return "突进"
		Strategy.SUPPORT:
			return "跟随"
		Strategy.KITER:
			return "放风筝"
		Strategy.PATROL:
			return "巡逻"
		_:
			return "防守"


## 离锚点最多多远（格）；0 = 不限
func leashCells() -> int:
	match strategy:
		Strategy.AGGRESSIVE:
			return 0
		Strategy.SUPPORT:
			return 5
		Strategy.KITER:
			return 8
		Strategy.PATROL:
			return 0
		_:
			return 6


## 策略锚点：跟随看队友位置，其他看进入策略时的位置
func leashAnchor() -> Vector2:
	if strategy == Strategy.SUPPORT:
		var ally := nearestAlly()
		if ally != null:
			return ally.global_position
	return anchorPos


## 武器偏好分：突进爱近战枪，放风筝/防守爱远射
func weaponBias(w) -> float:
	if w == null:
		return 0.0
	var r := float(w.wRange)
	match strategy:
		Strategy.AGGRESSIVE:
			return 0.35 if r <= 256.0 else -0.15
		Strategy.KITER:
			return 0.35 if r >= 300.0 else -0.30
		Strategy.SUPPORT:
			if w.type == Game.weaponType.Railgun:
				return 0.25
			return 0.10 if w.type == Game.weaponType.Pistol else 0.0
		_:
			return 0.25 if r >= 300.0 else 0.0


## 求生阈值：单人生存时更怕死（提前进求生分支）
func surviveThreshold() -> float:
	return 0.40 if isSolo() else SURVIVE_HP_RATIO


## 撤退阈值：单人生存时更早撤（有队友时可以顶一顶）
func retreatThreshold() -> float:
	return 0.45 if isSolo() else 0.30


## 每 tick 调用（内部 1 秒节流）
func updateStrategy() -> void:
	if player == null:
		return
	var now := Time.get_ticks_msec()
	if now < manualUntilMs:
		return
	if now - _lastStrategyEvalMs < 1000:
		return
	_lastStrategyEvalMs = now

	var hpRatio := float(player.hp) / maxf(float(player.maxHp), 1.0)
	var ally := nearestAlly()
	var nearestDist := INF if target == null \
			else player.global_position.distance_to(target.global_position)

	# 强制切换：立即生效，不等驻留
	# 血量很低先放风筝拉开距离（求生分支负责找箱子/后退）
	if hpRatio < surviveThreshold():
		_setStrategy(Strategy.KITER, now)
		return
	# 单人生存：真人队友全死了，不守尸体、不等复活，优先保命
	#   有敌人 → 放风筝（拉远打），没敌人 → 巡逻警戒（别乱冲）
	if isSolo():
		_setStrategy(Strategy.KITER if target != null else Strategy.PATROL, now)
		return
	if hpRatio < 0.35:
		_setStrategy(Strategy.DEFENSIVE, now)
		return
	if target == null:
		# 没敌人：队友太远就归队，否则在附近巡逻
		var far := 0.0
		if ally != null:
			far = player.global_position.distance_to(ally.global_position)
		if far > 8.0 * MapData.cellSize:
			_setStrategy(Strategy.SUPPORT, now)
		else:
			_setStrategy(Strategy.PATROL, now)
		return

	# 刚从巡逻切回战斗：不等驻留，直接按性格进入战斗策略
	if strategy == Strategy.PATROL:
		_setStrategy(personalityOf(), now)

	if now - strategySinceMs < strategyDwellMs:
		return

	var scores := {
		Strategy.AGGRESSIVE: 1.0, Strategy.DEFENSIVE: 1.0,
		Strategy.SUPPORT: 0.8, Strategy.KITER: 0.8,
	}
	if target != null:
		var dCells := nearestDist / MapData.cellSize
		if dCells > 7.0:
			scores[Strategy.KITER] += 0.6
			scores[Strategy.AGGRESSIVE] += 0.4
		elif dCells < 3.0:
			scores[Strategy.DEFENSIVE] += 0.5
			scores[Strategy.AGGRESSIVE] += 0.4
		else:
			scores[Strategy.AGGRESSIVE] += 0.25
			scores[Strategy.DEFENSIVE] += 0.15
	else:
		scores[Strategy.SUPPORT] += 1.2
	if ally != null:
		scores[Strategy.SUPPORT] += 0.5
	if hpRatio < 0.5:
		scores[Strategy.DEFENSIVE] += 0.6

	match personalityOf():
		Strategy.AGGRESSIVE:
			scores[Strategy.AGGRESSIVE] += 0.5
		Strategy.KITER:
			scores[Strategy.KITER] += 0.5
		Strategy.SUPPORT:
			scores[Strategy.SUPPORT] += 0.4
		_:
			scores[Strategy.DEFENSIVE] += 0.4

	var best := strategy
	var bestScore := -INF
	for k in scores.keys():
		if float(scores[k]) > bestScore:
			bestScore = float(scores[k])
			best = k
	# 滞回：新策略要高出当前 20% 才换
	if bestScore > float(scores[strategy]) * 1.20:
		_setStrategy(best, now)


func _setStrategy(s: int, now: int) -> void:
	if s == strategy:
		strategySinceMs = now
		return
	strategy = s
	strategySinceMs = now
	anchorPos = player.global_position
	if s == Strategy.PATROL:
		startPatrol()


# ---------------------------------------------------------------- 巡逻

## 进入巡逻：锚点优先放在队友身边，先站一会再开始走
func startPatrol() -> void:
	patrolHome = player.global_position
	var ally := nearestAlly()
	if ally != null:
		patrolHome = ally.global_position
	patrolDir = Vector2.ZERO
	patrolSteps = 0
	patrolLastCell = MapData.worldToCell(player.global_position)
	patrolWaitUntilMs = Time.get_ticks_msec() + randi_range(1000, 2500)


## 巡逻的一步：一格一格走，4~7 格歇一次；被挡/离锚点太远就重新选方向
func patrolMove() -> Vector2:
	if player == null:
		return Vector2.ZERO
	var now := Time.get_ticks_msec()
	if now < patrolWaitUntilMs:
		return Vector2.ZERO

	# 队友走远了：锚点跟过去，避免自己走丢
	var ally := nearestAlly()
	if ally != null and patrolHome.distance_to(ally.global_position) > 4.0 * MapData.cellSize:
		patrolHome = ally.global_position

	# 跨进新格子才消耗步数（8 向移动每格约 32px）
	var cell := MapData.worldToCell(player.global_position)
	if cell != patrolLastCell:
		patrolLastCell = cell
		if patrolSteps > 0:
			patrolSteps -= 1
			if patrolSteps <= 0:
				# 刚走完一段：歇 1.5~3.5 秒，再选下一段
				patrolDir = Vector2.ZERO
				patrolWaitUntilMs = now + randi_range(1500, 3500)
				return Vector2.ZERO

	# 方向被挡 / 被角色顶住：立刻换一个能走的方向（这里不额外停顿）
	var blocked: bool = patrolDir == Vector2.ZERO
	if not blocked:
		blocked = not canStepTo(player.global_position, patrolDir * MapData.cellSize)
	if blocked:
		var dir := pickPatrolDir()
		if dir == Vector2.ZERO:
			patrolDir = Vector2.ZERO
			patrolWaitUntilMs = now + randi_range(1500, 3000)
			return Vector2.ZERO
		patrolDir = dir
		patrolSteps = randi_range(4, 7)
	return patrolDir


## 选一个"能走"的方向：离锚点太远先回家，否则随机 8 向
func pickPatrolDir() -> Vector2:
	var toHome: Vector2 = patrolHome - player.global_position
	if toHome.length() > patrolLeashCells * MapData.cellSize:
		var back := snap8(toHome)
		if back != Vector2.ZERO and canStepTo(player.global_position, back * MapData.cellSize):
			return back

	var dirs: Array = [
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1),
	]
	dirs.shuffle()
	for d in dirs:
		var v: Vector2 = d
		v = v.normalized()
		if canStepTo(player.global_position, v * MapData.cellSize):
			return v
	return Vector2.ZERO


## 把任意方向吸附成 8 向（主导轴优先，避免斜着卡墙角）
func snap8(v: Vector2) -> Vector2:
	if v == Vector2.ZERO:
		return Vector2.ZERO
	var x := signf(v.x)
	var y := signf(v.y)
	if absf(v.x) > absf(v.y) * 1.8:
		return Vector2(x, 0.0)
	if absf(v.y) > absf(v.x) * 1.8:
		return Vector2(0.0, y)
	return Vector2(x, y).normalized()


# ---------------------------------------------------------------- 射线 / 拆物 / 交战距离

## 武器射线的第一命中（与实际开火同一套几何：枪口、射程、掩码、排除自己）
func firstHit(aim: Vector2) -> Node:
	if player == null or player.currWeapon == null:
		return null
	var w = player.currWeapon
	var space := player.get_world_2d().direct_space_state
	var from: Vector2 = w.hitOrigin()
	var to: Vector2 = w.hitEnd(aim)
	var q := PhysicsRayQueryParameters2D.create(from, to, w.collisionMask)
	q.collide_with_areas = true
	q.exclude = [w.ownerId]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return null
	var col = hit.get("collider")
	if col is Area2D and col.owner != null:
		col = col.owner
	return col


## 这一枪会不会打到目标（挡在前面的队友/墙/油桶都会让它返回 false）
func shotHitsTarget(aim: Vector2, t: Node2D) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	return firstHit(aim) == t


## 这一枪会不会打到指定的可拆物
func shotHitsProp(aim: Vector2, prop: Node2D) -> bool:
	if prop == null or not is_instance_valid(prop):
		return false
	return firstHit(aim) == prop


## 目标射线上第一个挡路的可拆物（墙 / 油桶）
func propBlocker(aim: Vector2, t: Node2D) -> Node2D:
	var col := firstHit(aim)
	if col == null or col == t:
		return null
	var ty = col.get("type")
	if ty == Game.itemType.Wall or ty == Game.itemType.Barrel:
		return col
	return null


## 物品/武器的爆炸半径（像素）；墙不爆炸返回 0
func blastRadiusOf(node) -> float:
	if node == null:
		return 0.0
	if node.get("type") == Game.itemType.Wall:
		return 0.0
	var dmg = node.get("damage")
	var d := float(dmg) if dmg != null else 150.0
	return (2.0 + maxf(d - 100.0, 0.0) * 0.005) * MapData.cellSize


## 打爆这个油桶会不会伤到自己人（关闭友伤时不会，直接放行）
func barrelSafeToBlow(barrel: Node2D) -> bool:
	if not MapData.friendlyFireOn():
		return true
	var r := blastRadiusOf(barrel) + MapData.cellSize
	if player.global_position.distance_to(barrel.global_position) < r:
		return false
	for n in get_tree().get_nodes_in_group("player"):
		if n == player or not is_instance_valid(n) or n.get("isDead") == true:
			continue
		if n.global_position.distance_to(barrel.global_position) < r:
			return false
	return true


## 现在值不值得拆一个东西：
## 1) 目标射线上挡着墙 / 油桶（油桶要先确认炸了不伤队友）
## 2) 油桶旁边有敌人、且爆区里没有自己人 → 当炸药打
func demolitionTarget() -> Node2D:
	if player == null or not isGun(player.currWeapon):
		return null

	if target != null and is_instance_valid(target):
		var aim: Vector2 = (target.global_position - player.global_position).normalized()
		var blocker := propBlocker(aim, target)
		if blocker != null:
			var ty = blocker.get("type")
			if ty == Game.itemType.Wall:
				return blocker
			if ty == Game.itemType.Barrel and barrelSafeToBlow(blocker):
				return blocker

	for p in props:
		if not is_instance_valid(p) or p.get("type") != Game.itemType.Barrel:
			continue
		if player.global_position.distance_to(p.global_position) > effectiveRange(player.currWeapon):
			continue
		if not barrelSafeToBlow(p):
			continue
		if enemyNear(p.global_position, blastRadiusOf(p)) != null:
			return p
	return null


## 武器的有效射程：火箭这类弹丸武器 wRange = 0，用经验射程代替
func effectiveRange(w) -> float:
	if w == null:
		return 0.0
	var r := float(w.wRange)
	if r > 0.0:
		return r
	if w.type == Game.weaponType.Rocket:
		return 320.0
	return 0.0


## 每把武器的理想交战距离（像素）：按武器本身来，不强行贴脸
func idealDistance(w) -> float:
	if w == null:
		return 160.0
	var d := 160.0
	match w.type:
		Game.weaponType.Shotgun:
			d = 56.0
		Game.weaponType.UZI:
			d = 168.0
		Game.weaponType.Pistol:
			d = 208.0
		Game.weaponType.Railgun:
			d = 300.0
		Game.weaponType.Rocket:
			d = 240.0
		_:
			d = 160.0
	match strategy:
		Strategy.AGGRESSIVE:
			d *= 0.85
		Strategy.SUPPORT:
			d *= 0.90
		Strategy.KITER:
			d *= 1.15
		_:
			pass
	var maxD: float = effectiveRange(w) - 8.0
	return clampf(d, 48.0, maxf(maxD, 48.0))


# ---------------------------------------------------------------- 武器

## 只考虑枪械（放置类武器 CPU 不用）
func isGun(w) -> bool:
	if w == null:
		return false
	return w.type in [
		Game.weaponType.Pistol, Game.weaponType.Railgun, Game.weaponType.Rocket,
		Game.weaponType.Shotgun, Game.weaponType.UZI,
	]


## 爆发类武器（会炸到自己/队友）
##
## 之前只判了火箭，手榴弹/地雷/充电包/油桶同样是范围伤害，
## 开火前也要过一遍爆区检查（`explosiveSafe`），否则 CPU 会往脚边扔雷。
func isExplosive(w) -> bool:
	if w == null:
		return false
	return w.type in [
		Game.weaponType.Rocket, Game.weaponType.Grenade,
		Game.weaponType.Mine, Game.weaponType.ChargePack, Game.weaponType.Barrel,
	]


## 爆炸半径（像素）：与原版/explosion.gd 同一公式
func blastRadius(w) -> float:
	var dmg := float(w.damage) if w != null else 0.0
	return (2.0 + maxf(dmg - 100.0, 0.0) * 0.005) * MapData.cellSize


## 朝 targetPos 开爆炸物是否安全：自己或任何队友在爆区内 → 不打
func explosiveSafe(targetPos: Vector2) -> bool:
	if player.currWeapon == null or not isExplosive(player.currWeapon):
		return true
	if not MapData.friendlyFireOn():
		return true
	var r := blastRadius(player.currWeapon) + MapData.cellSize
	if player.global_position.distance_to(targetPos) < r:
		return false
	for n in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(n) or n.get("isDead") == true:
			continue
		if n.global_position.distance_to(targetPos) < r:
			return false
	return true


## 给一把枪按"当前距离"打分：射程适配 + DPS + 弹药余量 + 策略偏好
func gunScore(w, dist: float) -> float:
	var r := maxf(effectiveRange(w), 1.0)
	var fit := 1.0 if dist <= r else clampf(1.0 - (dist - r) / r, 0.0, 1.0)
	var dps := float(w.damage) / maxf(float(w.delay), 0.05)
	var ammo := 1.0 if w.maxAmmoNum == 0 \
			else clampf(float(w.ammoNum) / float(w.maxAmmoNum), 0.0, 1.0)
	return fit * 2.0 + minf(dps / 200.0, 1.0) + ammo * 0.3 + weaponBias(w)


## 选枪：带滞回（差距不够/冷却中就不换），空弹强制换
func bestGun(dist: float) -> Node:
	if player == null:
		return null
	var cur = player.currWeapon
	var best = null
	var bestScore := -INF
	for w in player.weaponList:
		if not isGun(w):
			continue
		if w.maxAmmoNum > 0 and w.ammoNum <= 0:
			continue
		var s: float = gunScore(w, dist)
		if s > bestScore:
			bestScore = s
			best = w
	if best == null:
		return null
	if cur != null and isGun(cur) and not (cur.maxAmmoNum > 0 and cur.ammoNum <= 0):
		if bestScore - gunScore(cur, dist) < 0.15:
			return cur
		if Time.get_ticks_msec() - lastSwitchMs < switchCooldownMs:
			return cur
	return best
