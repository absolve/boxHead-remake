extends "res://script/character.gd"

@onready var ani = $ani
@onready var weaponBackpack = $weaponBackpack
@onready var txt = $txt
@onready var body = $body
@onready var bodyShape = $body/bodyShape

var playerId = 1
var keyMap = {'left': '', 'right': '', 'up': '', 'down': '', 'fire': '', 'nextWeapon': '', 'prevWeapon': ''}
var currWeapon = null
var weaponList = []
var currWeaponIndex = 0
var vector = Vector2.RIGHT
var aniException = ['Mine', 'RemoteMine', 'Wall', 'Barrel', 'Grenade']
var shapeQuery=PhysicsShapeQueryParameters2D.new()

func _ready():
	state=Game.playerState.Idle
	shapeQuery=PhysicsShapeQueryParameters2D.new()
	shapeQuery.collide_with_bodies=false
	shapeQuery.collide_with_areas=true
	shapeQuery.collision_mask=1+2+4
	shapeQuery.exclude=[body.get_rid()]
	shapeQuery.shape=shape.shape
	
	var temp = load("res://scene/pistol.tscn")
	var gun = temp.instantiate()
	gun.ownerId = get_rid()
	weaponList.push_back(gun)
	weaponBackpack.add_child(gun)
	#currWeapon=gun
	#txt.text=Game.weaponName[currWeapon.type]
	#var t=load("res://scene/uzi.tscn")
	#var g=t.instantiate()
	#g.ownerId=get_rid()
	#weaponList.push_back(g)
	#weaponBackpack.add_child(g)
	#var r= load("res://scene/rocket.tscn")
	#var rocket=r.instantiate()
	#rocket.ownerId=get_rid()
	#weaponList.push_back(rocket)
	#weaponBackpack.add_child(rocket)
	
	#var b=load("res://scene/barrel.tscn")
	#var barrel=b.instantiate()
	#barrel.ownerId=get_rid()
	#weaponList.push_back(barrel)
	#weaponBackpack.add_child(barrel)
	
	#var w=load("res://scene/wall.tscn")
	#var wall=w.instantiate()
	#wall.ownerId=get_rid()
	#weaponList.push_back(wall)
	#weaponBackpack.add_child(wall)
	
	#var m=load("res://scene/mine.tscn")
	#var mine=m.instantiate()
	#mine.ownerId=get_rid()
	#weaponList.push_back(mine)
	#weaponBackpack.add_child(mine)

	#var s=load("res://scene/shotgun.tscn")
	#var shortGun=s.instantiate()
	#shortGun.ownerId=get_rid()
	#weaponList.push_back(shortGun)
	#weaponBackpack.add_child(shortGun)
	
	var g = load("res://scene/grenade.tscn")
	var grenade = g.instantiate()
	grenade.ownerId = get_rid()
	weaponList.push_back(grenade)
	weaponBackpack.add_child(grenade)

	
	#var rg=load("res://scene/railgun.tscn")
	#var railgun=rg.instantiate()
	#railgun.ownerId=get_rid()
	#weaponList.push_back(railgun)
	#weaponBackpack.add_child(railgun)
	
	currWeapon = gun
	
	
	txt.text = Game.weaponName[currWeapon.type]
	if playerId == 1:
		keyMap.left = "p1_left"
		keyMap.right = "p1_right"
		keyMap.up = "p1_up"
		keyMap.down = "p1_down"
		keyMap.fire = 'p1_fire'
		keyMap.nextWeapon = 'p1_nextWeapon'
		keyMap.prevWeapon = 'p1_prevWeapon'
	print(currWeapon)
	
func switchWeapon(next: bool = true):
	if weaponList.size() > 1:
		if next:
			currWeaponIndex += 1
		else:
			currWeaponIndex -= 1
		print(currWeaponIndex)
		currWeaponIndex = wrapi(currWeaponIndex, 0, weaponList.size())
		print(currWeaponIndex)
		currWeapon = weaponList[currWeaponIndex]
	
		#txt.text=Game.weaponName[currWeapon.type]	
	
	
func _physics_process(_delta):
	if state==Game.playerState.Idle:
		
		currAni = "stand"
		var input_dir = Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")
		#print(input_dir)
		if input_dir.length() != 0:
			vector = input_dir
			angle = input_dir.angle() / (PI / 4)
			angle = wrapi(int(angle), 0, 8)
			currAni = "walk"
		velocity = input_dir * speed
	
		#for i in get_slide_collision_count():
			#var collision = get_slide_collision(i)
			#print("碰到了：", collision.get_collider().name)
		move_and_slide()
		#检测area2d
		var space_state = get_world_2d().direct_space_state
		#var query=PhysicsShapeQueryParameters2D.new()
		#query.collide_with_bodies=false
		#query.collide_with_areas=true
		#query.collision_mask=1+2+4
		#query.exclude=[body.get_rid()]
		#query.shape=shape.shape
		shapeQuery.transform=Transform2D(global_rotation,global_position)
		var result=space_state.intersect_shape(shapeQuery,1)
		if result:
			print(result)
			var r=result[0]
			if r.collider.get('type')&&r.collider.type in [Game.itemType.Barrel,
									Game.itemType.Wall]:
				velocity=Vector2.ZERO						
				var shape1=r.collider.get_node("shape").shape
				print(shape1.size)
				var delta=global_position-r.collider.global_position
				if abs(delta.x) > abs(delta.y):
					# 左右边
					var signx = sign(delta.x)
					global_position.x =r.collider.global_position.x+signx*(0.09+shape1.size.x/2+shape.shape.size.x/2)
				else:
					# 上下边
					var signy = sign(delta.y)	
					global_position.y =r.collider.global_position.y+signy*(0.09+shape1.size.y/2+shape.shape.size.y/2)
					
		#move_and_collide(velocity*_delta)		
		
		if aniException.has(Game.weaponName[currWeapon.type]):
			ani.play(currAni + "_%s"%playerId + "_%s"%angle + "_%s"%'other')
		else:
			ani.play(currAni + "_%s"%playerId + "_%s"%angle + "_%s"%Game.weaponName[currWeapon.type])

		#更新武器弹药
		if currWeapon.maxAmmoNum == 0:
			txt.text = Game.weaponName[currWeapon.type]
		else:
			txt.text = '%s:%s' % [Game.weaponName[currWeapon.type], currWeapon.ammoNum]

		if currWeapon.maxAmmoNum != 0:
			if currWeapon.ammoNum <= 0:
				txt.modulate = Color.RED
			else:
				txt.modulate = Color.BLACK
		else:
			txt.modulate = Color.BLACK
		
		
		if Input.is_action_pressed(keyMap.fire):
			if currWeapon.type == Game.weaponType.Grenade:
				currWeapon.increase()
			else:
				currWeapon.fire(vector)
		if Input.is_action_just_released(keyMap.fire):
			if currWeapon.type == Game.weaponType.Grenade:
				currWeapon.fire(vector)

		
		if Input.is_action_just_pressed(keyMap.nextWeapon):
			switchWeapon()
		if Input.is_action_just_pressed(keyMap.prevWeapon):
			switchWeapon(false)	
		position.x = clamp(position.x, bodySize.x / 2, MapData.mapSize.x - bodySize.x / 2)
		position.y = clamp(position.y, bodySize.y / 2, MapData.mapSize.y - bodySize.y / 2)
		
	z_index = floori(global_position.y / MapData.cellSize) + 1
	

#func _input(_event: InputEvent) -> void:
	#if _event is InputEventKey:
		#print(_event)
		#print(Input.is_action_pressed(keyMap.fire))
		#print('is_released',_event.is_released())
		#pass
	#if Input.is_action_pressed(keyMap.fire):
		#if currWeapon.type==Game.weaponType.Grenade:
			##print('Grenade')
			#
			#if _event.is_released():
				#print('is_released')
				#currWeapon.fire(vector)
			#else:
				#currWeapon.increase()	
		#else:		
			#currWeapon.fire(vector)
	#if Input.is_action_just_pressed(keyMap.nextWeapon):
		#switchWeapon()
	#if Input.is_action_just_pressed(keyMap.prevWeapon):
		#switchWeapon(false)
