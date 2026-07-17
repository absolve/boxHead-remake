extends "res://script/character.gd"

## 僵尸敌人脚本
# 继承自character.gd，实现僵尸AI逻辑：
# - 流场寻路（Flow Field Pathfinding）
# - 目标追踪（寻找最近的玩家）
# - 攻击检测和执行
# - 旋转动画处理
# - 碰撞检测和绕行


## 动画节点
@onready var ani = $ani
## 身体碰撞体节点
@onready var body = $body
## 身体碰撞形状节点
@onready var bodyShape = $body/bodyShape
## 攻击碰撞区域节点
@onready var attackArea = $attackArea
## 形状投射节点（用于碰撞检测）
@onready var shapeCast = $ShapeCast2D
@onready var attackSound=$attackSound


## 字体资源
var font: FontFile
## 当前追踪目标（玩家）
var target = null
## 目标上一帧位置
var targetOldPos = Vector2.ZERO
## 攻击范围（像素）
var attackRange = 35
## 路径点列表
var path = []
## 目标位置
var targetPos = null
## 路径更新间隔（秒）
var pathUpdateInterval = 1
## 路径更新计时器
var pathTimer = 0
## 当前路径点索引
var pathPointIndex = 0
## 上一帧朝向角度
var oldAngle = 0
## 受伤计时器
var hurtTimer = 0
## 受伤持续时间（秒）
var hurtDelay = 0.5
## 攻击冷却计时器
var attackTimer = 0
## 攻击冷却时间（秒）
var attackDelay = 1
## 形状查询参数（用于碰撞检测）
var shapeQuery = PhysicsShapeQueryParameters2D.new()
## 上一帧速
var lastVelocity = Vector2.ZERO
## 旋转目标帧（动画帧）
var rotate_target_frame = 0
## 旋转步长（每帧移动的帧数）
var rotate_step = 1
## 旋转等待计时器
var rotate_wait_timer = 0.0
## 旋转等待持续时间（秒）
var rotate_wait_duration = 0.2
## 旋转后是否需要立即攻击
var rotate_to_attack = false
## 寻路计时器
var findPathTimer = 0
## 寻路间隔（秒）
var findPathDelay = 2
## 下一个移动点
var nextPoint = Vector2.ZERO

## 8方向向量数组（用于寻路）
var dirs = [
	Vector2(1, 0),   # 右
	Vector2(1, 1),   # 右下
	Vector2(0, 1),   # 下
	Vector2(-1, 1),  # 左下
	Vector2(-1, 0),  # 左
	Vector2(-1, -1), # 左上
	Vector2(0, -1),  # 上
	Vector2(1, -1),  # 右上
]

## 初始出生位置（僵尸需要先移动到这里）
var initPos = Vector2.ZERO
## 碰撞体大小
var size: Vector2 = Vector2(32, 32)
## 最佳移动方向
var bestDir: Vector2 = Vector2.ZERO
## 当前移动方向
var currDir: Vector2 = Vector2.ZERO
## 上一次所在的网格位置
var lastGrid: Vector2i = Vector2.ZERO
## 最少移动格子数（用于判断是否脱离了原方向的阻塞）
var minMoveGrid = 2


## 方向信息类
# 用于存储候选方向的评分信息，便于排序选择最佳路径
class dirInfo:
	var dir: Vector2     # 方向向量
	var dot: float       # 与原方向的点积（值越大越接近原方向）
	var canMove: bool    # 是否可以移动
	var distance         # 距离目标的距离
	
	func _init(_dir: Vector2):
		self.dir = _dir
	
	func _to_string():
		return "dir:%s distance:%s" % [dir, distance]


## 攻击判定框位置调整表
# 根据朝向角度调整攻击区域的偏移位置
var attackPos = {
	0: Vector2(20, -9),  1: Vector2(20, -3),  2: Vector2(0, 3),
	3: Vector2(-11, -5), 4: Vector2(-9, -11), 5: Vector2(5, -17),
	6: Vector2(5, -17),  7: Vector2(16, -17)
}

## 攻击区域旋转角度调整表
# 某些角度需要额外旋转攻击区域
var attackPosAngle = {2: 90, 6: 90}
## 是否已在当前攻击动画中执行过攻击判定
# 防止同一攻击动画多次触发伤害
var hasAttacked = false
## 攻击判定帧（动画帧索引）
# 攻击动画共5帧（0-4），在第2帧进行攻击判定（攻击动作最关键的时刻）
var attackHitFrame = 2
var damage=2

## 初始化
func _ready():
	# 获取字体
	font = ThemeDB.fallback_font
	
	# 配置形状查询参数
	shapeQuery.collide_with_areas = true
	shapeQuery.collision_mask = 1 + 2 + 4 + 8
	shapeQuery.exclude = [get_rid()]
	shapeQuery.shape = shape.shape
	
	# 如果初始速度不为零，设置初始朝向
	if velocity.length() != 0:
		angle = round(velocity.angle() / (PI / 4))
		angle = wrapi(int(angle), 0, 8)
		oldAngle = angle
		pathTimer = pathUpdateInterval


## 物理帧更新
func _physics_process(_delta: float) -> void:
	if state == Game.enemyState.Idle || state == Game.enemyState.ffp || state == Game.enemyState.findDir:
		# 寻路状态：定期更新目标，根据状态获取移动方向
		pathTimer += _delta
		if pathTimer > pathUpdateInterval:
			target = findTarget()
			pathTimer = 0
		
		if target == null:
			return
		
		# 根据状态获取移动方向
		if state == Game.enemyState.ffp:
			currDir = getFlowField()
		elif state == Game.enemyState.findDir:
			currDir = findDir()
		
		# 设置速度
		velocity = currDir * speed
		
		# 检测是否在攻击范围内
		if target != null:
			var dis = global_position.distance_squared_to(target.global_position)
			if dis < attackRange * attackRange:
				# 计算朝向玩家的角度
				var dir_to_player = global_position.direction_to(target.global_position)
				var target_angle = wrapi(int(round(dir_to_player.angle() / (PI / 4))), 0, 8)
				
				if angle != target_angle:
					# 需要先旋转面向玩家
					angle = target_angle
					playRotateAni(target_angle)
					rotate_to_attack = true
					return
				else:
					# 已面向玩家，执行攻击
					velocity = Vector2.ZERO
					ani.play("attack" + "_%s" % angle)
					attackArea.position = attackPos[angle]
					attackTimer = 0
					if attackPosAngle.has(angle):
						attackArea.rotation = deg_to_rad(attackPosAngle[angle])
					else:
						attackArea.rotation = 0
					state = Game.enemyState.attack
					return
		
		# 更新动画状态
		if velocity.length() > 0:
			currAni = "walk"
		else:
			currAni = "stand"
		
		# 根据速度计算朝向
		if velocity.length() != 0:
			angle = round(velocity.angle() / (PI / 4))
			angle = wrapi(int(angle), 0, 8)
			if angle != oldAngle:
				playRotateAni(angle)
				return
		
		# 播放动画并移动
		ani.play(currAni + "_%s" % angle)
		move_and_collide(velocity * _delta)
	
	elif state == Game.enemyState.dead:
		# 死亡状态：无操作
		pass
	
	elif state == Game.enemyState.hurt:
		# 受伤状态：减速恢复
		hurtTimer += _delta
		if hurtTimer >= hurtDelay:
			hurtTimer = 0
			state = Game.enemyState.ffp
		velocity = velocity.lerp(Vector2.ZERO, hurtTimer)
		move_and_collide(velocity * _delta)
	
	elif state == Game.enemyState.attack:
		# 攻击状态：播放攻击动画，检测攻击冷却
		if !ani.is_playing():
			attackTimer += _delta
			if attackTimer > attackDelay:
				attackTimer = 0
				ani.play("attack" + "_%s" % angle)
				attackArea.position = attackPos[angle]
				if attackPosAngle.has(angle):
					attackArea.rotation = deg_to_rad(attackPosAngle[angle])
				else:
					attackArea.rotation = 0
				hasAttacked = false  # 重置攻击判定标志
		# 攻击动画播放中：在关键帧进行攻击判定
		if ani.is_playing() && ani.frame == attackHitFrame && !hasAttacked:
			hasAttacked = true
			doAttack()	
		# 计算朝向玩家的角度
		var dir_to_player = global_position.direction_to(target.global_position)
		var target_angle = wrapi(int(round(dir_to_player.angle() / (PI / 4))), 0, 8)
		
		if angle != target_angle:
			# 需要先旋转面向玩家
			angle = target_angle
			playRotateAni(target_angle)
			rotate_to_attack = true
			return		
		# 检测目标是否仍在攻击范围内
		var dis = global_position.distance_squared_to(target.global_position)
		if dis > attackRange * attackRange:
			state = Game.enemyState.ffp
	
	elif state == Game.enemyState.rotate:
		# 旋转状态：逐帧播放旋转动画
		ani.frame = wrapi(ani.frame + rotate_step, 0, 32)
		if ani.frame == rotate_target_frame:
			oldAngle = angle
			rotate_wait_timer = 0.0
			state = Game.enemyState.rotate_wait
	
	elif state == Game.enemyState.rotate_wait:
		# 旋转等待状态：旋转后短暂停顿再继续行动
		rotate_wait_timer += _delta
		if rotate_wait_timer >= rotate_wait_duration:
			if rotate_to_attack:
				# 旋转后需要攻击
				rotate_to_attack = false
				velocity = Vector2.ZERO
				ani.play("attack" + "_%s" % angle)
				attackArea.position = attackPos[angle]
				attackTimer = 0
				if attackPosAngle.has(angle):
					attackArea.rotation = deg_to_rad(attackPosAngle[angle])
				else:
					attackArea.rotation = 0
				state = Game.enemyState.attack
			else:
				# 旋转后继续寻路
				state = Game.enemyState.ffp
	
	elif state == Game.enemyState.init:
		# 初始化状态：移动到初始位置
		currAni = "walk"
		
		# 碰撞检测和位置修正
		var space_state = get_world_2d().direct_space_state
		shapeQuery.transform = Transform2D(global_rotation, global_position)
		var result = space_state.intersect_shape(shapeQuery, 1)
		if result:
			var r = result[0]
			if r.collider.get('type') && r.collider.type in [Game.itemType.Barrel,
								Game.itemType.Wall, Game.roleType.Player,
								Game.roleType.Zombie, Game.roleType.Devil]:
				var shape1 = r.collider.get_node("shape").shape
				var d = global_position - r.collider.global_position
				if abs(d.x) > abs(d.y):
					var signx = sign(d.x)
					global_position.x = r.collider.global_position.x + signx * (shape1.size.x / 2 + shape.shape.size.x / 2)
				else:
					var signy = sign(d.y)
					global_position.y = r.collider.global_position.y + signy * (shape1.size.y / 2 + shape.shape.size.y / 2)
				currAni = "stand"
		
		# 更新朝向和动画
		if velocity.length() != 0:
			angle = round(velocity.angle() / (PI / 4))
			angle = wrapi(int(angle), 0, 8)
		ani.play(currAni + "_%s" % angle)
		move_and_collide(velocity * speed * _delta)
		
		# 到达初始位置后切换到流场寻路状态
		if global_position.distance_to(initPos) < 1:
			state = Game.enemyState.ffp
	
	# 限制敌人在地图边界内（非初始化状态）
	if state != Game.enemyState.init:
		position.x = clamp(position.x, bodySize.x / 2, MapData.mapSize.x - bodySize.x / 2)
		position.y = clamp(position.y, bodySize.y / 2, MapData.mapSize.y - bodySize.y / 2)
	
	# 根据Y坐标设置Z轴顺序
	z_index = roundi(global_position.y / MapData.cellSize) + 1
	
	# 请求重绘（调试信息）
	# queue_redraw()


## 寻找目标玩家
# 在玩家组中找到距离最近的玩家作为追踪目标
# @return 最近的玩家节点，无玩家时返回null
func findTarget():
	var nodes = get_tree().get_nodes_in_group("player")
	if nodes.size() > 0:
		var minDistance = INF
		var nearestEnemy = null
		for i in nodes:
			var dis = global_position.distance_to(i.global_position)
			if dis < minDistance:
				minDistance = dis
				nearestEnemy = i
		return nearestEnemy
	else:
		return null


## 获取流场方向
# 根据流场数据获取移动方向，并检测碰撞进行绕行
# @return 最佳移动方向向量（Vector2）
func getFlowField():
	var current_grid = Vector2i(floori(global_position.x / MapData.cellSize),
		floori(global_position.y / MapData.cellSize))
	
	# 获取流场提供的方向
	var dir = MapData.getFlowDir(global_position, target.playerId)
	
	# 使用形状投射检测碰撞
	shapeCast.target_position = size / 2 * dir
	shapeCast.force_shapecast_update()
	
	if shapeCast.is_colliding():
		# 流场方向被阻挡，寻找可绕行的方向
		var newDir = dir
		var canMoveDir = []
		var newGrid: Vector2 = Vector2.ZERO
		
		# 尝试7个旋转方向（每次45度）
		for i in range(7):
			newDir = newDir.rotated(PI / 4)
			newGrid = Vector2(current_grid) + newDir
			
			# 边界检查
			if newGrid.x < 0 || newGrid.x > MapData.mapSize.x - 1 || \
				newGrid.y < 0 || newGrid.y > MapData.mapSize.y - 1:
					continue
			
			# 检测该方向是否可通行
			shapeCast.target_position = size / 2 * newDir
			shapeCast.force_shapecast_update()
			if !shapeCast.is_colliding():
				var d = dirInfo.new(newDir)
				d.dot = newDir.dot(dir)
				canMoveDir.append(d)
		
		# 按与原方向的相似度排序
		canMoveDir.sort_custom(func(a, b): return a.dot >= b.dot)
		
		if canMoveDir.size() > 0:
			bestDir = canMoveDir[0].dir
			state = Game.enemyState.findDir
		else:
			bestDir = Vector2.ZERO
		
		lastGrid = Vector2i(floori(global_position.x / MapData.cellSize),
			floori(global_position.y / MapData.cellSize))
	else:
		# 流场方向可通行
		bestDir = dir
	
	return bestDir.normalized()


## 寻找新的移动方向
# 在findDir状态下持续检测并更新移动方向
# @return 当前最佳移动方向向量（Vector2）
func findDir():
	var current_grid = Vector2i(floori(global_position.x / MapData.cellSize),
		floori(global_position.y / MapData.cellSize))
	var newGrid: Vector2 = Vector2.ZERO
	
	if currDir != Vector2.ZERO:
		# 检测当前方向是否仍可通行
		shapeCast.target_position = size / 2 * currDir
		shapeCast.force_shapecast_update()
		newGrid = Vector2(current_grid) + currDir
		
		if !shapeCast.is_colliding() && newGrid.x >= 0 && newGrid.x <= MapData.mapSize.x - 1 && \
				newGrid.y >= 0 && newGrid.y <= MapData.mapSize.y - 1:
			bestDir = currDir
		else:
			# 当前方向被阻挡，寻找新方向
			var newDir = currDir
			var canMoveDir = []
			
			for i in range(7):
				newDir = newDir.rotated(PI / 4)
				newGrid = Vector2(current_grid) + newDir
				
				if newGrid.x < 0 || newGrid.x > MapData.mapSize.x - 1 || \
					newGrid.y < 0 || newGrid.y > MapData.mapSize.y - 1:
						continue
				
				shapeCast.target_position = size / 2 * newDir
				shapeCast.force_shapecast_update()
				if !shapeCast.is_colliding():
					var d = dirInfo.new(newDir)
					d.dot = newDir.dot(currDir)
					canMoveDir.append(d)
			
			canMoveDir.sort_custom(func(a, b): return a.dot >= b.dot)
			
			if canMoveDir.size() > 0:
				bestDir = canMoveDir[0].dir
			else:
				bestDir = Vector2.ZERO
			
			lastGrid = current_grid
	else:
		# 无当前方向，回到流场寻路状态
		state = Game.enemyState.ffp
	
	# 如果移动了足够距离，尝试回到流场方向
	if lastGrid.distance_squared_to(current_grid) > minMoveGrid * minMoveGrid:
		var dir = MapData.getFlowDir(global_position, target.playerId)
		shapeCast.target_position = size / 2 * dir
		shapeCast.force_shapecast_update()
		if !shapeCast.is_colliding():
			bestDir = dir
	
	return bestDir.normalized()


## 播放旋转动画
# 计算最短旋转方向并设置旋转动画
# @param _newAngle 目标角度（0-7）
func playRotateAni(_newAngle):
	ani.stop()
	ani.animation = "rotate"
	ani.frame = oldAngle * 4
	
	# 计算目标帧（0-31）
	rotate_target_frame = (_newAngle * 4) % 32
	
	# 计算最短旋转方向
	var delta = (rotate_target_frame - ani.frame + 32) % 32
	if delta == 0:
		rotate_step = 1
	elif delta <= 16:
		rotate_step = 1
	else:
		rotate_step = -1
	
	state = Game.enemyState.rotate


## 受伤处理
# 减少血量，处理受伤/死亡状态和动画
# @param damage 伤害值（int）
# @param _attackPos 攻击来源位置（Vector2）
# @param recoil 击退力度（float，默认0）
func hit(_damage: int, _attackPos: Vector2, recoil: float = 0):
	if isDead:
		return
	
	hp -= _damage
	
	if oldAngle != angle:
		oldAngle = angle
	
	if hp <= 0:
		# 死亡处理
		isDead = true
		state = Game.enemyState.dead
		ani.play("fallDown_%s" % [int(angle / 2)])
		body.monitorable = false
		body.monitoring = false
		bodyShape.disabled = true
		shape.disabled = true
		
		# 发出敌人被击杀信号
		Game.enemyKilled.emit(global_position)
		
		# 延迟消失动画
		var temp = create_tween()
		temp.tween_interval(3)
		temp.tween_property(ani, "modulate:a", 0, 1)
		temp.tween_callback(queue_free)
	else:
		# 受伤处理
		#lastState=state
		state = Game.enemyState.hurt
		hurtTimer = 0
		
		# 计算击退方向
		var attacker = (_attackPos - global_position).normalized()
		var dot = velocity.normalized().dot(attacker)
		
		# 根据击中方向播放不同受伤动画
		if dot > 0:
			ani.play("hitFront_%s" % [angle])
		else:
			ani.play("hitRear_%s" % [angle])
		
		# 应用击退
		velocity = Vector2.RIGHT.rotated(velocity.angle()) * -recoil

## 执行攻击判定
func doAttack():
	var p=attackArea.get_overlapping_areas()
	for  i in p:
		if i.owner.has_method("hit"):
			i.owner.hit(damage, global_position, 20)
	#attackSound.play()
	
## 绘制调试信息
# 显示当前网格坐标
func _draw() -> void:
	draw_string(font, Vector2(30, 10), "%s-%s" % \
	[floori(global_position.x / MapData.cellSize), floori(global_position.y / MapData.cellSize)]
	, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
