extends "res://script/character.gd"

## 玩家角色脚本
# 继承自character.gd，实现玩家的控制逻辑：
# - 移动控制（WASD或方向键）
# - 武器系统（切换、拾取、升级）
# - 受伤和死亡处理
# - 碰撞检测

## 动画节点
@onready var ani = $ani
## 武器背包节点（存放所有武器）
@onready var weaponBackpack = $weaponBackpack
## 武器名称显示节点
@onready var txt = $txt
## 身体碰撞体节点
@onready var body = $body
## 身体碰撞形状节点
@onready var bodyShape = $body/bodyShape
## 血条节点
@onready var lifeBar = $lifeBar
## 死亡音效节点
@onready var deadSound = $dead
## 拾取音效节点
@onready var pickupSound = $pickup
## 玩家精灵节点
@onready var player = $player
## 玩家ID（用于多人游戏区分）
@export var playerId = 1

## 按键映射（根据玩家ID分配不同按键）
var keyMap = {'left': '', 'right': '', 'up': '', 'down': '', 'fire': '', 'nextWeapon': '', 'prevWeapon': ''}
## 当前使用的武器
var currWeapon = null
## 武器列表（玩家拥有的所有武器）
var weaponList = []
## 当前武器索引
var currWeaponIndex = 0
## 当前朝向向量
var vector = Vector2.RIGHT
## 不需要显示武器的动画例外列表
var aniException = ['Mine', 'ChargePack', 'Wall', 'Barrel', 'Grenade']
## 形状查询参数（用于碰撞检测）
var shapeQuery = PhysicsShapeQueryParameters2D.new()
## 受伤计时器
var hurtTimer = 0
## 受伤持续时间（秒）
var hurtDelay = 0.5


## 初始化
func _ready():
	# 设置初始状态
	state = Game.playerState.Idle
	
	# 配置形状查询参数
	shapeQuery.collide_with_areas = true
	shapeQuery.collision_mask = 1 + 2 + 4
	shapeQuery.exclude = [get_rid(), body.get_rid()]
	shapeQuery.shape = shape.shape
	
	# 初始化武器列表（默认装备手枪）
	var temp = load("res://scene/pistol.tscn")
	var gun = temp.instantiate()
	gun.ownerId = body.get_rid()
	weaponList.push_back(gun)
	weaponBackpack.add_child(gun)
	
	currWeapon = gun
	
	# 设置武器名称显示
	txt.text = Game.weaponName[currWeapon.type]
	
	# 根据玩家ID配置按键映射
	if playerId == 1:
		keyMap.left = "p1_left"
		keyMap.right = "p1_right"
		keyMap.up = "p1_up"
		keyMap.down = "p1_down"
		keyMap.fire = 'p1_fire'
		keyMap.nextWeapon = 'p1_nextWeapon'
		keyMap.prevWeapon = 'p1_prevWeapon'
	elif playerId == 2:
		keyMap.left = "p2_left"
		keyMap.right = "p2_right"
		keyMap.up = "p2_up"
		keyMap.down = "p2_down"
		keyMap.fire = 'p2_fire'
		keyMap.nextWeapon = 'p2_nextWeapon'
		keyMap.prevWeapon = 'p2_prevWeapon'
	elif playerId == 3:
		keyMap.left = "p3_left"
		keyMap.right = "p3_right"
		keyMap.up = "p3_up"
		keyMap.down = "p3_down"
		keyMap.fire = 'p3_fire'
		keyMap.nextWeapon = 'p3_nextWeapon'
		keyMap.prevWeapon = 'p3_prevWeapon'
	elif playerId == 4:
		keyMap.left = "p4_left"
		keyMap.right = "p4_right"
		keyMap.up = "p4_up"
		keyMap.down = "p4_down"
		keyMap.fire = 'p4_fire'
		keyMap.nextWeapon = 'p4_nextWeapon'
		keyMap.prevWeapon = 'p4_prevWeapon'
	
	# 连接武器升级信号
	Game.weaponUpgrade.connect(weaponUpgrade)
	
	# 播放出生闪烁动画
	player.play("flash")
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func(): player.play("RESET"))
	tween.play()


## 武器升级处理
# 根据武器类型更新武器属性
# @param _type 武器类型（Game.weaponType枚举值）
func weaponUpgrade(_type):
	if _type in [Game.weaponType.Pistol, Game.weaponType.UZI, Game.weaponType.Rocket,
	 Game.weaponType.Barrel, Game.weaponType.Wall, Game.weaponType.Mine, Game.weaponType.
	 Shotgun, Game.weaponType.Grenade, Game.weaponType.Railgun, Game.weaponType.ChargePack]:
		for i in weaponList:
			if i.type == _type:
				i.damage = MapData.allWeaponData[_type]['damage']
				i.maxAmmoNum = MapData.allWeaponData[_type]['maxAmmoNum']
				i.automatic = MapData.allWeaponData[_type]['automatic']
				i.wRange = MapData.allWeaponData[_type]['wRange']
				i.delay = MapData.allWeaponData[_type]['delay']
				if _type == Game.weaponType.Shotgun:
					i.splitAngle = MapData.allWeaponData[_type]['splitAngle']
				if _type in [Game.weaponType.Mine, Game.weaponType.ChargePack]:
					i.splitExplosion = MapData.allWeaponData[_type]['splitExplosion']
				break


## 切换武器
# 在武器列表中循环切换当前武器
# @param next 是否切换到下一把武器（true=下一把，false=上一把）
func switchWeapon(next: bool = true):
	if weaponList.size() > 1:
		if next:
			currWeaponIndex += 1
		else:
			currWeaponIndex -= 1
		currWeaponIndex = wrapi(currWeaponIndex, 0, weaponList.size())
		currWeapon = weaponList[currWeaponIndex]
		Game.notice.emit("%s:%s" % [tr("Switch"), Game.weaponName[currWeapon.type]])


## 拾取物品
# 根据物品类型添加武器或恢复生命
# @param _type 物品类型（Game.boxContent枚举值）
func pickItem(_type):
	if _type in [Game.boxContent.Railgun, Game.boxContent.Rocket,
	 Game.boxContent.Shotgun, Game.boxContent.UZI,
	 Game.boxContent.Mine, Game.boxContent.ChargePack,
	 Game.boxContent.Wall, Game.boxContent.Barrel, Game.boxContent.Grenade]:
		var w = getWeapon(Game.getBoxContentWeaponType(_type))
		if w != null:
			# 已有该武器，补充弹药
			w.ammoNum = MapData.allWeaponData[_type]['ammoNum']
		else:
			# 没有该武器，创建新武器实例
			if _type == Game.boxContent.Railgun:
				var temp = load("res://scene/railgun.tscn")
				var railgun = temp.instantiate()
				railgun.ownerId = get_rid()
				railgun.damage = MapData.allWeaponData.get(Game.weaponType.Railgun)['damage']
				railgun.ammoNum = MapData.allWeaponData.get(Game.weaponType.Railgun)['maxAmmoNum']
				railgun.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.Railgun)['maxAmmoNum']
				railgun.automatic = MapData.allWeaponData.get(Game.weaponType.Railgun)['automatic']
				railgun.wrange = MapData.allWeaponData.get(Game.weaponType.Railgun)['wRange']
				railgun.delay = MapData.allWeaponData.get(Game.weaponType.Railgun)['delay']
				weaponList.push_back(railgun)
				weaponBackpack.add_child(railgun)
			elif _type == Game.boxContent.Rocket:
				var temp = load("res://scene/rocket.tscn")
				var rocket = temp.instantiate()
				rocket.ownerId = body.get_rid()
				rocket.damage = MapData.allWeaponData.get(Game.weaponType.Rocket)['damage']
				rocket.ammoNum = MapData.allWeaponData.get(Game.weaponType.Rocket)['maxAmmoNum']
				rocket.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.Rocket)['maxAmmoNum']
				rocket.automatic = MapData.allWeaponData.get(Game.weaponType.Rocket)['automatic']
				rocket.wrange = MapData.allWeaponData.get(Game.weaponType.Rocket)['wRange']
				rocket.delay = MapData.allWeaponData.get(Game.weaponType.Rocket)['delay']
				weaponList.push_back(rocket)
				weaponBackpack.add_child(rocket)
			elif _type == Game.boxContent.Shotgun:
				var temp = load("res://scene/shotgun.tscn")
				var shotgun = temp.instantiate()
				shotgun.ownerId = body.get_rid()
				shotgun.damage = MapData.allWeaponData.get(Game.weaponType.Shotgun)['damage']
				shotgun.ammoNum = MapData.allWeaponData.get(Game.weaponType.Shotgun)['maxAmmoNum']
				shotgun.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.Shotgun)['maxAmmoNum']
				shotgun.automatic = MapData.allWeaponData.get(Game.weaponType.Shotgun)['automatic']
				shotgun.wrange = MapData.allWeaponData.get(Game.weaponType.Shotgun)['wRange']
				shotgun.delay = MapData.allWeaponData.get(Game.weaponType.Shotgun)['delay']
				shotgun.splitAngle = MapData.allWeaponData.get(Game.weaponType.Shotgun)['splitAngle']
				weaponList.push_back(shotgun)
				weaponBackpack.add_child(shotgun)
			elif _type == Game.boxContent.UZI:
				var temp = load("res://scene/uzi.tscn")
				var uzi = temp.instantiate()
				uzi.ownerId = body.get_rid()
				uzi.damage = MapData.allWeaponData.get(Game.weaponType.UZI)['damage']
				uzi.ammoNum = MapData.allWeaponData.get(Game.weaponType.UZI)['maxAmmoNum']
				uzi.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.UZI)['maxAmmoNum']
				uzi.automatic = MapData.allWeaponData.get(Game.weaponType.UZI)['automatic']
				uzi.wrange = MapData.allWeaponData.get(Game.weaponType.UZI)['wRange']
				uzi.delay = MapData.allWeaponData.get(Game.weaponType.UZI)['delay']
				weaponList.push_back(uzi)
				weaponBackpack.add_child(uzi)
			elif _type == Game.boxContent.Mine:
				var temp = load("res://scene/mine.tscn")
				var mine = temp.instantiate()
				mine.ownerId = body.get_rid()
				mine.damage = MapData.allWeaponData.get(Game.weaponType.Mine)['damage']
				mine.ammoNum = MapData.allWeaponData.get(Game.weaponType.Mine)['maxAmmoNum']
				mine.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.Mine)['maxAmmoNum']
				mine.splitExplosion = MapData.allWeaponData.get(Game.weaponType.Mine)['splitExplosion']
				weaponList.push_back(mine)
				weaponBackpack.add_child(mine)
			elif _type == Game.boxContent.ChargePack:
				var temp = load("res://scene/chargePack.tscn")
				var chargePack = temp.instantiate()
				chargePack.ownerId = get_rid()
				chargePack.damage = MapData.allWeaponData.get(Game.weaponType.ChargePack)['damage']
				chargePack.ammoNum = MapData.allWeaponData.get(Game.weaponType.ChargePack)['maxAmmoNum']
				chargePack.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.ChargePack)['maxAmmoNum']
				chargePack.splitExplosion = MapData.allWeaponData.get(Game.weaponType.ChargePack)['splitExplosion']
				weaponList.push_back(chargePack)
				weaponBackpack.add_child(chargePack)
			elif _type == Game.boxContent.Wall:
				var temp = load("res://scene/wall.tscn")
				var wall = temp.instantiate()
				wall.ownerId = body.get_rid()
				wall.ammoNum = MapData.allWeaponData.get(Game.weaponType.Wall)['maxAmmoNum']
				wall.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.Wall)['maxAmmoNum']
				weaponList.push_back(wall)
				weaponBackpack.add_child(wall)
			elif _type == Game.boxContent.Barrel:
				var temp = load("res://scene/barrel.tscn")
				var barrel = temp.instantiate()
				barrel.ownerId = body.get_rid()
				barrel.damage = MapData.allWeaponData.get(Game.weaponType.Barrel)['damage']
				barrel.ammoNum = MapData.allWeaponData.get(Game.weaponType.Barrel)['maxAmmoNum']
				barrel.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.Barrel)['maxAmmoNum']
				barrel.splitExplosion = MapData.allWeaponData.get(Game.weaponType.Barrel)['splitExplosion']
				weaponList.push_back(barrel)
				weaponBackpack.add_child(barrel)
			elif _type == Game.boxContent.Grenade:
				var temp = load("res://scene/grenade.tscn")
				var grenade = temp.instantiate()
				grenade.ownerId = body.get_rid()
				grenade.damage = MapData.allWeaponData.get(Game.weaponType.Grenade)['damage']
				grenade.ammoNum = MapData.allWeaponData.get(Game.weaponType.Grenade)['maxAmmoNum']
				grenade.maxAmmoNum = MapData.allWeaponData.get(Game.weaponType.Grenade)['maxAmmoNum']
				grenade.splitExplosion = MapData.allWeaponData.get(Game.weaponType.Grenade)['splitExplosion']
				weaponList.push_back(grenade)
				weaponBackpack.add_child(grenade)

	elif _type == Game.boxContent.Life:
		# 恢复生命
		hp = maxHp
	
	# 播放拾取音效
	pickupSound.play()


## 获取指定类型的武器
# 在武器列表中查找指定类型的武器
# @param _type 武器类型（Game.weaponType枚举值）
# @return 找到的武器实例，未找到返回null
func getWeapon(_type):
	for i in weaponList:
		if i.type == _type:
			return i
	return null


## 受伤处理
# 减少血量，处理受伤动画和击退效果
# @param damage 伤害值（int）
# @param attackPos 攻击来源位置（Vector2）
# @param recoil 击退力度（float，默认0）
func hit(damage: int, attackPos: Vector2, recoil: float = 0):
	hp -= damage
	lifeBar.hp = hp
	
	if hp <= 0:
		# 死亡处理
		state = Game.playerState.dead
		deadSound.play()
		ani.play("fallDown_%s" % [roundi(angle / 2.0)])
		shape.disabled = true
		bodyShape.disabled = true
	else:
		# 受伤处理
		state = Game.playerState.hurt
		hurtTimer = 0
		
		# 计算击退方向
		var attacker = ((global_position + bodyShape.position) - attackPos).normalized()
		var dot = velocity.normalized().dot(attacker)
		
		# 根据击中方向播放不同受伤动画
		if dot >= 0:
			ani.play("hitFront_%s" % [angle])
		else:
			ani.play("hitRear_%s" % [angle])
		
		# 应用击退
		velocity = attacker * recoil


## 物理帧更新
func _physics_process(_delta):
	if state == Game.playerState.Idle:
		# 空闲状态：处理移动和攻击
		currAni = "stand"
		
		# 获取输入方向
		var input_dir = Input.get_vector(keyMap.left, keyMap.right, keyMap.up, keyMap.down)
		if input_dir.length() != 0:
			vector = input_dir
			angle = round(input_dir.angle() / (PI / 4))
			angle = wrapi(int(angle), 0, 8)
			currAni = "walk"
		
		# 对角线移动时归一化速度
		if !input_dir.is_normalized():
			input_dir = input_dir.normalized()
		velocity = input_dir * speed
		
		# 根据武器类型播放对应动画
		if aniException.has(Game.weaponName[currWeapon.type]):
			ani.play(currAni + "_%s" % 1 + "_%s" % angle + "_%s" % 'other')
		else:
			ani.play(currAni + "_%s" % 1 + "_%s" % angle + "_%s" % Game.weaponName[currWeapon.type])

		# 更新武器弹药显示
		if currWeapon.maxAmmoNum == 0:
			txt.text = Game.weaponName[currWeapon.type]
		else:
			txt.text = '%s:%s' % [Game.weaponName[currWeapon.type], currWeapon.ammoNum]

		# 根据弹药量改变文字颜色
		if currWeapon.maxAmmoNum != 0:
			if currWeapon.ammoNum <= 0:
				txt.modulate = Color.RED
			else:
				txt.modulate = Color.WHITE
		else:
			txt.modulate = Color.WHITE
		
		# 处理射击输入
		if Input.is_action_pressed(keyMap.fire):
			if currWeapon.type == Game.weaponType.Grenade:
				currWeapon.increase()
			else:
				if currWeapon.automatic:
					currWeapon.fire(vector)
				elif Input.is_action_just_pressed(keyMap.fire):
					currWeapon.fire(vector)
		
		# 手榴弹释放时扔出
		if Input.is_action_just_released(keyMap.fire):
			if currWeapon.type == Game.weaponType.Grenade:
				currWeapon.fire(vector)
		
		# 处理武器切换输入
		if Input.is_action_just_pressed(keyMap.nextWeapon):
			switchWeapon()
		if Input.is_action_just_pressed(keyMap.prevWeapon):
			switchWeapon(false)

		# 移动并处理碰撞
		var displacement = velocity * _delta
		if displacement != Vector2.ZERO:
			displacement = _resolve_area_blockers(displacement)
		move_and_collide(displacement)
	
	elif state == Game.playerState.hurt:
		# 受伤状态：减速恢复
		hurtTimer += _delta
		if hurtTimer > hurtDelay:
			hurtTimer = 0
			state = Game.playerState.Idle
		velocity = velocity.lerp(Vector2.ZERO, hurtTimer)
		move_and_collide(velocity * _delta)
	
	elif state == Game.playerState.dead:
		# 死亡状态：无操作
		pass
	
	# 限制玩家在地图边界内
	position.x = clamp(position.x, bodySize.x / 2, MapData.mapSize.x - bodySize.x / 2)
	position.y = clamp(position.y, bodySize.y / 2, MapData.mapSize.y - bodySize.y / 2)
	
	# 根据Y坐标设置Z轴顺序（实现2.5D视觉效果）
	z_index = floori(global_position.y / MapData.cellSize) + 1


## 区域障碍物碰撞处理
# 检测并解决玩家与障碍物的重叠问题
# @param displacement 期望的位移向量（Vector2）
# @return 调整后的位移向量（Vector2）
func _resolve_area_blockers(displacement: Vector2) -> Vector2:
	# 起始位置检查：如果已经在障碍物内部，允许离开
	shapeQuery.transform = Transform2D(global_rotation, global_position)
	var start_results = get_world_2d().direct_space_state.intersect_shape(shapeQuery, 8)
	for sr in start_results:
		var area_shape = null
		if sr.collider.has_node("shape"):
			area_shape = sr.collider.get_node("shape").shape
		if area_shape is RectangleShape2D:
			var area_extents = area_shape.size * 0.5
			var self_extents = shape.shape.size * 0.5
			var delta = global_position - sr.collider.global_position
			var overlap_x = (area_extents.x + self_extents.x) - abs(delta.x)
			var overlap_y = (area_extents.y + self_extents.y) - abs(delta.y)
			if overlap_x > 0 and overlap_y > 0:
				return displacement

	# 目标位置纠正：最多迭代3次以收敛
	var adjusted_position = global_position + displacement
	for i in range(3):
		var made_adjustment = false
		shapeQuery.transform = Transform2D(global_rotation, adjusted_position)
		var results = get_world_2d().direct_space_state.intersect_shape(shapeQuery, 8)
		for r in results:
			var area_shape = null
			if r.collider.has_node("shape"):
				area_shape = r.collider.get_node("shape").shape
			if area_shape is RectangleShape2D:
				var area_extents = area_shape.size * 0.5
				var self_extents = shape.shape.size * 0.5
				var delta = adjusted_position - r.collider.global_position
				var overlap_x = (area_extents.x + self_extents.x) - abs(delta.x)
				var overlap_y = (area_extents.y + self_extents.y) - abs(delta.y)
				if overlap_x > 0 and overlap_y > 0:
					var move_x = sign(delta.x) if delta.x != 0 else sign(displacement.x) if displacement.x != 0 else 1
					var move_y = sign(delta.y) if delta.y != 0 else sign(displacement.y) if displacement.y != 0 else 1
					if overlap_x < overlap_y:
						adjusted_position.x += move_x * overlap_x
					else:
						adjusted_position.y += move_y * overlap_y
					made_adjustment = true
		if not made_adjustment:
			break

	return adjusted_position - global_position
