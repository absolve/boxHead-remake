extends "res://script/character.gd"

@onready var ani=$ani
@onready var weaponBackpack=$weaponBackpack
@onready var txt=$txt

var playerId=1
var keyMap={'left':'','right':'','up':'','down':'','fire':'','nextWeapon':'','prevWeapon':''}
var currWeapon=null
var weaponList=[]
var currWeaponIndex=0
var vector=Vector2.RIGHT
var aniException=['Mine','RemoteMine','Wall','Barrel','Grenade']


func _ready():
	var temp=load("res://scene/hand_gun.tscn")
	var gun=temp.instantiate()
	gun.ownerId=get_rid()
	weaponList.push_back(gun)
	weaponBackpack.add_child(gun)
	currWeapon=gun
	txt.text=Game.weaponName[currWeapon.type]
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
	
	var b=load("res://scene/barrel.tscn")
	var barrel=b.instantiate()
	barrel.ownerId=get_rid()
	weaponList.push_back(barrel)
	weaponBackpack.add_child(barrel)
	
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

	var s=load("res://scene/shotgun.tscn")
	var shortGun=s.instantiate()
	shortGun.ownerId=get_rid()
	weaponList.push_back(shortGun)
	weaponBackpack.add_child(shortGun)
	
	if playerId==1:
		keyMap.left="p1_left"
		keyMap.right="p1_right"
		keyMap.up="p1_up"
		keyMap.down="p1_down"
		keyMap.fire='p1_fire'
		keyMap.nextWeapon='p1_nextWeapon'
		keyMap.prevWeapon='p1_prevWeapon'
	
	
func switchWeapon(next:bool=true):
	if weaponList.size()>1:
		if next:
			currWeaponIndex+=1
		else:
			currWeaponIndex-=1	
		currWeaponIndex=wrapi(currWeaponIndex,0,weaponList.size())
		currWeapon=weaponList[currWeaponIndex]
	
		#txt.text=Game.weaponName[currWeapon.type]
		
		
	
	
func  _physics_process(_delta):
	currAni="stand"
	var input_dir = Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")
	#print(input_dir)
	if input_dir.length() != 0:
		vector=input_dir
		angle = input_dir.angle() / (PI/4)
		angle = wrapi(int(angle), 0, 8)
		currAni="walk"
	velocity = input_dir * speed
	move_and_slide()
	if aniException.has(Game.weaponName[currWeapon.type]):
		ani.play(currAni+"_%s"%playerId+"_%s"%angle+"_%s"%'other')
	else:	
		ani.play(currAni+"_%s"%playerId+"_%s"%angle+"_%s"%Game.weaponName[currWeapon.type])

	#更新武器弹药
	if currWeapon.maxAmmoNum==0:
		txt.text=Game.weaponName[currWeapon.type]
	else:
		txt.text='%s:%s'%[Game.weaponName[currWeapon.type],currWeapon.ammoNum]
	
	if currWeapon.maxAmmoNum!=0:
		if currWeapon.ammoNum<=0:
			txt.modulate=Color.RED
		else:
			txt.modulate=Color.WHITE	
	else:
		txt.modulate=Color.WHITE
	
	#if Input.is_action_pressed(keyMap.fire):
		#currWeapon.fire(vector)
	z_index=floori(global_position.y/MapData.cellSize)+1


func _input(_event: InputEvent) -> void:
	if Input.is_action_pressed(keyMap.fire):
		currWeapon.fire(vector)
	if Input.is_action_just_pressed(keyMap.nextWeapon):
		switchWeapon()
	if Input.is_action_just_pressed(keyMap.prevWeapon):
		switchWeapon(false)
