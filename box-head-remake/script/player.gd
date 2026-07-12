extends "res://script/character.gd"

@onready var ani = $ani
@onready var weaponBackpack = $weaponBackpack
@onready var txt = $txt
@onready var body = $body
@onready var bodyShape = $body/bodyShape
@onready var lifeBar = $lifeBar
@onready var deadSound = $dead

@export var playerId = 1 # 玩家一个标记
var keyMap = {'left': '', 'right': '', 'up': '', 'down': '', 'fire': '', 'nextWeapon': '', 'prevWeapon': ''}
var currWeapon = null
var weaponList = []
var currWeaponIndex = 0
var vector = Vector2.RIGHT
var aniException = ['Mine', 'ChargePack', 'Wall', 'Barrel', 'Grenade']
var shapeQuery = PhysicsShapeQueryParameters2D.new()
var hurtTimer = 0
var hurtDelay = 0.5


func _ready():
	state = Game.playerState.Idle
	shapeQuery.collide_with_bodies = true
	shapeQuery.collide_with_areas = true
	shapeQuery.collision_mask = 1 + 2 + 4
	shapeQuery.exclude = [get_rid(), body.get_rid()]
	shapeQuery.shape = shape.shape

	
	var temp = load("res://scene/pistol.tscn")
	var gun = temp.instantiate()
	gun.ownerId = body.get_rid()
	weaponList.push_back(gun)
	weaponBackpack.add_child(gun)
	#currWeapon=gun
	#txt.text=Game.weaponName[currWeapon.type]
	var t = load("res://scene/uzi.tscn")
	var u = t.instantiate()
	u.ownerId = body.get_rid()
	weaponList.push_back(u)
	weaponBackpack.add_child(u)
	
	var r = load("res://scene/rocket.tscn")
	var rocket = r.instantiate()
	rocket.ownerId = body.get_rid()
	weaponList.push_back(rocket)
	weaponBackpack.add_child(rocket)
	
	var b = load("res://scene/barrel.tscn")
	var barrel = b.instantiate()
	barrel.ownerId = body.get_rid()
	weaponList.push_back(barrel)
	weaponBackpack.add_child(barrel)
	
	var w = load("res://scene/wall.tscn")
	var wall = w.instantiate()
	wall.ownerId = body.get_rid()
	weaponList.push_back(wall)
	weaponBackpack.add_child(wall)
	
	var m = load("res://scene/mine.tscn")
	var mine = m.instantiate()
	mine.ownerId = body.get_rid()
	weaponList.push_back(mine)
	weaponBackpack.add_child(mine)

	var s = load("res://scene/shotgun.tscn")
	var shortGun = s.instantiate()
	shortGun.ownerId = body.get_rid()
	weaponList.push_back(shortGun)
	weaponBackpack.add_child(shortGun)
	
	var g = load("res://scene/grenade.tscn")
	var grenade = g.instantiate()
	grenade.ownerId = body.get_rid()
	weaponList.push_back(grenade)
	weaponBackpack.add_child(grenade)

	
	var rg = load("res://scene/railgun.tscn")
	var railgun = rg.instantiate()
	railgun.ownerId = get_rid()
	weaponList.push_back(railgun)
	weaponBackpack.add_child(railgun)
	
	var cp = load("res://scene/chargePack.tscn")
	var chargePack = cp.instantiate()
	chargePack.ownerId = get_rid()
	weaponList.push_back(chargePack)
	weaponBackpack.add_child(chargePack)


	currWeapon = gun
	
	print(playerId)
	txt.text = Game.weaponName[currWeapon.type]
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
	print(currWeapon)
	Game.weaponUpgrade.connect(weaponUpgrade)

#武器升级
func weaponUpgrade(_type):
	if _type == [Game.weaponType.Pistol, Game.weaponType.UZI, Game.weaponType.Rocket,
	 Game.weaponType.Barrel, Game.weaponType.Wall, Game.weaponType.Mine, Game.weaponType.
	 Shotgun, Game.weaponType.Grenade, Game.weaponType.Railgun, Game.weaponType.ChargePack]:
		for i in weaponList:
			if i.type == _type:
				i.damage = MapData.allWeaponData._type['damage']
				# i.ammoNum = MapData.allWeaponData._type['ammoNum']
				i.maxAmmoNum = MapData.allWeaponData._type['maxAmmoNum']
				i.automatic = MapData.allWeaponData._type['automatic']
				i.wrange = MapData.allWeaponData._type['wRange']
				i.delay = MapData.allWeaponData._type['delay']
				if _type == Game.weaponType.Shotgun:
					i.splitAngle = MapData.allWeaponData._type['splitAngle']
				if _type == [Game.weaponType.Mine, Game.weaponType.ChargePack]:
					i.splitExplosion = MapData.allWeaponData._type['splitExplosion']
				break

#切换武器	
func switchWeapon(next: bool = true):
	if weaponList.size() > 1:
		if next:
			currWeaponIndex += 1
		else:
			currWeaponIndex -= 1
		currWeaponIndex = wrapi(currWeaponIndex, 0, weaponList.size())
		currWeapon = weaponList[currWeaponIndex]
		Game.notice.emit("%s:%s" % [tr("Switch"), Game.weaponName[currWeapon.type]])
		#txt.text=Game.weaponName[currWeapon.type]	

func hit(damage: int, attackPos: Vector2, recoil: float = 0):
	hp -= damage
	lifeBar.hp = hp
	if hp <= 0:
		state = Game.playerState.dead
		deadSound.play()
		ani.play("fallDown_%s" % [roundi(angle / 2.0)])
		shape.disabled = true
		bodyShape.disabled = true
		#await ani.animation_finished
		#var temp = create_tween()
		#temp.tween_interval(2)
		#temp.tween_property(ani, "modulate:a", 0, 1)
		#temp.tween_callback(queue_free)
		#发送玩家死亡的消息
	else:
		state = Game.playerState.hurt
		hurtTimer = 0
		# print("----", global_position, ' ', attackPos)
		var attacker = ((global_position + bodyShape.position) - attackPos).normalized()
		# print("----", attacker)
		var dot = velocity.normalized().dot(attacker)
		if dot >= 0: # 正面击中
			ani.play("hitFront_%s" % [angle])
		else: # 背面 侧面击中
			ani.play("hitRear_%s" % [angle])
		velocity = attacker * recoil
		
	
func _physics_process(_delta):
	if state == Game.playerState.Idle:
		currAni = "stand"
		var input_dir = Input.get_vector(keyMap.left, keyMap.right, keyMap.up, keyMap.down)
		if input_dir.length() != 0:
			vector = input_dir
			angle = round(input_dir.angle() / (PI / 4))
			angle = wrapi(int(angle), 0, 8)
			currAni = "walk"
		if !input_dir.is_normalized(): # 对角线移动 长度设为1
			input_dir = input_dir.normalized()
		velocity = input_dir * speed
	
		
		#检测area2d
		#var space_state = get_world_2d().direct_space_state
		#shapeQuery.transform = Transform2D(global_rotation, global_position)
		#var result = space_state.intersect_shape(shapeQuery, 1)
		#if result:
			##print(result)
			#var r = result[0]
			#if r.collider.get('type') && r.collider.type in [Game.itemType.Barrel,
									#Game.itemType.Wall, Game.roleType.Player,
									#Game.roleType.Zombie, Game.roleType.Devil]:
				#var shape1 = r.collider.get_node("shape").shape
				##print(shape1.size)
				#var delta = global_position - r.collider.global_position
				#if abs(delta.x) > shape1.size.x / 2 || abs(delta.y) > shape1.size.y / 2:
					#velocity = Vector2.ZERO
					#if abs(delta.x) > abs(delta.y):
						## 左右边
						#var signx = sign(delta.x)
						#global_position.x = r.collider.global_position.x + signx * (shape1.size.x / 2 + shape.shape.size.x / 2)
					#else:
						## 上下边
						#var signy = sign(delta.y)
						#global_position.y = r.collider.global_position.y + signy * (shape1.size.y / 2 + shape.shape.size.y / 2)
						
		
		if aniException.has(Game.weaponName[currWeapon.type]):
			ani.play(currAni + "_%s" % 1 + "_%s"%angle + "_%s"%'other')
		else:
			ani.play(currAni + "_%s" % 1 + "_%s"%angle + "_%s"%Game.weaponName[currWeapon.type])

		#更新武器弹药
		if currWeapon.maxAmmoNum == 0:
			txt.text = Game.weaponName[currWeapon.type]
		else:
			txt.text = '%s:%s' % [Game.weaponName[currWeapon.type], currWeapon.ammoNum]

		if currWeapon.maxAmmoNum != 0:
			if currWeapon.ammoNum <= 0:
				txt.modulate = Color.RED
			else:
				txt.modulate = Color.WHITE
		else:
			txt.modulate = Color.WHITE
		
		
		if Input.is_action_pressed(keyMap.fire):
			if currWeapon.type == Game.weaponType.Grenade:
				currWeapon.increase()
			else:
				if currWeapon.automatic:
					currWeapon.fire(vector)
				elif Input.is_action_just_pressed(keyMap.fire):
					currWeapon.fire(vector)
		if Input.is_action_just_released(keyMap.fire):
			if currWeapon.type == Game.weaponType.Grenade:
				currWeapon.fire(vector)
			
				
		if Input.is_action_just_pressed(keyMap.nextWeapon):
			switchWeapon()
		if Input.is_action_just_pressed(keyMap.prevWeapon):
			switchWeapon(false)

		var displacement = velocity * _delta
		if displacement != Vector2.ZERO:
			displacement = _resolve_area_blockers(displacement)
		move_and_collide(displacement)
	elif state == Game.playerState.hurt:
		hurtTimer += _delta
		if hurtTimer > hurtDelay:
			hurtTimer = 0
			state = Game.playerState.Idle
		velocity = velocity.lerp(Vector2.ZERO, hurtTimer)
		move_and_collide(velocity * _delta)
	elif state == Game.playerState.dead:
		pass
	
	position.x = clamp(position.x, bodySize.x / 2, MapData.mapSize.x - bodySize.x / 2)
	position.y = clamp(position.y, bodySize.y / 2, MapData.mapSize.y - bodySize.y / 2)
	z_index = floori(global_position.y / MapData.cellSize) + 1
	#var dir = MapData.getFlowDir(global_position, playerId) 
	#print(dir)
	
func _resolve_area_blockers(displacement: Vector2) -> Vector2:
	# 起始位置：只有在实际矩形重叠时才认为在内部，允许从内部离开
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

	# 目标位置纠正：最多迭代几次以收敛
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
