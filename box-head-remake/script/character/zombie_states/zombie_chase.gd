extends State

## Chase 状态 —— 流场寻路追击玩家
##
## 骨架与阻挡判定均对齐 godot4flow-field demo 的 enemy.gd（selectFlowField + findDir）：
##   ffp：    每帧只对**当前方向**做一次整格 ShapeCast；被挡才做旋转扫描
##            （7 次、每次 45°，半格探测），选"与原方向点积最大"的可走方向，
##            切 findDir 承诺方向绕行；
##   findDir：沿承诺方向一直走（同样只探当前方向，再被挡再旋转换向），
##            离开起点满 minMoveGrid 格且流场方向恢复可走后切回 ffp。
## 阻挡必须用 ShapeCast 而不是纯格子判定：格子判定看不到墙的物理边缘，
## 身体被挤到格子边缘时会顶着墙一直往前蹭。
## 朝向 angle 每帧直接取移动方向（流场方向本身就是 8 向值），追击途中不再用 Turn。

## 宿主
var z: Zombie:
	get:
		return actor as Zombie

## 追击子状态：Game.enemyState.ffp（沿流场）/ Game.enemyState.findDir（绕行）
var moveState: int = Game.enemyState.ffp
## 当前承诺的移动方向（findDir 模式下保持，直到被挡或切回流场）
var currDir: Vector2 = Vector2.ZERO
## 进入绕行时所在的格子
var lastGrid: Vector2i = Vector2i.ZERO


func enter(_msg: Dictionary = {}) -> void:
	moveState = Game.enemyState.ffp
	currDir = Vector2.ZERO


func exit() -> void:
	z.velocity = Vector2.ZERO


func physicsUpdate(delta: float) -> void:
	if z.isDead:
		return

	# 目标丢失（玩家死亡/被回收）→ 站桩等刷新
	if not z.refreshTarget(delta):
		z.velocity = Vector2.ZERO
		z.playAnim("stand")
		return

	# ---- 进入攻击距离：朝向对就直接打，不对就转身再打
	if z.targetInAttackRange():
		z.velocity = Vector2.ZERO
		if z.isFacingTarget():
			stateMachine.transitionTo(&"Attack")
		else:
			stateMachine.transitionTo(&"Turn", {"to": z.dirToTarget(), "next": "Attack"})
		return

	# ---- 沿流场走；被挡就 ShapeCast 旋转找最接近的可走方向
	var dir: Vector2
	if moveState == Game.enemyState.ffp:
		dir = selectFlowField()
	else:
		dir = findDir()

	if dir == Vector2.ZERO:
		z.velocity = Vector2.ZERO
		z.playAnim("stand")
		return

	z.angle = Zombie.angleFromVector(dir)
	z.oldAngle = z.angle
	z.moveInDirection(dir, delta)
	z.playAnim("walk")


# ---------------------------------------------------------------- 流场模式（demo selectFlowField）

## 取流场方向；整格探测被挡就旋转找"与原方向最接近"的可走方向，切 findDir
func selectFlowField() -> Vector2:
	var dir: Vector2 = MapData.getFlowDir(z.global_position, z.targetId())
	if dir == Vector2.ZERO:
		# 流场无方向（站在障碍格/不可达区，比如出生点压墙、被挤进墙里）→ 先脱困
		return escapeDir()

	z.shapeCast.target_position = MapData.cellSize * dir
	z.shapeCast.force_shapecast_update()

	if not z.shapeCast.is_colliding():
		return dir.normalized()

	# 流场方向被挡：旋转 7 次（45° 一步）收集可走候选
	var newDir := dir
	var cell := z.gridPosition()
	var canMoveDir: Array = []
	for i in range(7):
		newDir = newDir.rotated(PI / 4)
		if isOutsideMap(cell + Vector2i(roundi(newDir.x), roundi(newDir.y))):
			continue
		z.shapeCast.target_position = MapData.cellSize / 2 * newDir
		z.shapeCast.force_shapecast_update()
		if not z.shapeCast.is_colliding():
			canMoveDir.append(newDir)

	if canMoveDir.is_empty():
		# 真无路可走 → 站一帧，下帧重试（同伴挪动后即可恢复）
		return Vector2.ZERO

	# 按与原方向的点积排序，选最接近流场方向的可走方向
	canMoveDir.sort_custom(func(a, b): return a.dot(dir) >= b.dot(dir))
	currDir = canMoveDir[0]
	moveState = Game.enemyState.findDir
	lastGrid = cell
	return currDir.normalized()


# ---------------------------------------------------------------- 绕行模式（demo findDir）

## 沿 currDir 前进；被挡就地旋转换向；走满 minMoveGrid 格后探测流场是否恢复可走
func findDir() -> Vector2:
	var cell := z.gridPosition()

	if currDir != Vector2.ZERO:
		z.shapeCast.target_position = MapData.cellSize * currDir
		z.shapeCast.force_shapecast_update()

		if z.shapeCast.is_colliding():
			# 当前方向被挡：旋转找可走方向
			var newDir := currDir
			var canMoveDir: Array = []
			for i in range(7):
				newDir = newDir.rotated(PI / 4)
				if isOutsideMap(cell + Vector2i(roundi(newDir.x), roundi(newDir.y))):
					continue
				z.shapeCast.target_position = MapData.cellSize / 2 * newDir
				z.shapeCast.force_shapecast_update()
				if not z.shapeCast.is_colliding():
					canMoveDir.append(newDir)

			if canMoveDir.is_empty():
				currDir = Vector2.ZERO
			else:
				canMoveDir.sort_custom(func(a, b): return a.dot(currDir) >= b.dot(currDir))
				currDir = canMoveDir[0]
			lastGrid = cell
	else:
		moveState = Game.enemyState.ffp

	# 走够 minMoveGrid 格 → 回头探测流场方向是否恢复可走
	if currDir != Vector2.ZERO \
			and lastGrid.distance_squared_to(cell) > z.minMoveGrid * z.minMoveGrid:
		var dir: Vector2 = MapData.getFlowDir(z.global_position, z.targetId())
		if dir != Vector2.ZERO:
			z.shapeCast.target_position = MapData.cellSize / 2 * dir
			z.shapeCast.force_shapecast_update()
			if not z.shapeCast.is_colliding():
				moveState = Game.enemyState.ffp
				return dir.normalized()

	return currDir.normalized() if currDir != Vector2.ZERO else Vector2.ZERO


## 目标格是否超出地图（demo 的边界检查；旋转候选会指到图外）
func isOutsideMap(cell: Vector2i) -> bool:
	var grid := Vector2i(int(MapData.mapSize.x / MapData.cellSize),
			int(MapData.mapSize.y / MapData.cellSize))
	return cell.x < 0 or cell.y < 0 or cell.x >= grid.x or cell.y >= grid.y


## 脱困：站在障碍格里时，8 个方向做整格探测取最接近目标方向的出路
##
## 必须用整格探测：半格探测从墙格中心够不到墙外，8 个方向全会判成被挡。
## 也不能用纯格子判定：人已经在障碍格里，格子数据帮不上忙。
func escapeDir() -> Vector2:
	var base: Vector2 = z.vectorFromAngle(z.dirToTarget())
	var cell := z.gridPosition()
	var best := Vector2.ZERO
	var bestDot := -INF
	var newDir := base
	for i in range(8):
		if i > 0:
			newDir = newDir.rotated(PI / 4)
		if isOutsideMap(cell + Vector2i(roundi(newDir.x), roundi(newDir.y))):
			continue
		z.shapeCast.target_position = MapData.cellSize * newDir
		z.shapeCast.force_shapecast_update()
		if z.shapeCast.is_colliding():
			continue
		var dot := newDir.dot(base)
		if dot > bestDot:
			bestDot = dot
			best = newDir

	if best == Vector2.ZERO:
		return Vector2.ZERO

	currDir = best
	moveState = Game.enemyState.findDir
	lastGrid = cell
	return best.normalized()
