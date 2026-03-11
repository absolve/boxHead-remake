extends "res://script/character.gd"

@onready var ani=$ani
@onready var weaponBackpack=$weaponBackpack
@onready var txt=$txt

var playerId=1
var keyMap={'left':'','right':'','up':'','down':'','fire':'','switch':''}
var currWeapon=null
var weaponList=[]
var currWeaponIndex=0
var vector=Vector2.RIGHT

func _ready():
	var temp=load("res://scene/hand_gun.tscn")
	var gun=temp.instantiate()
	weaponList.push_back(gun)
	weaponBackpack.add_child(gun)
	currWeapon=gun
	txt.text=Game.weaponName[currWeapon.type]
	var t=load("res://scene/uzi.tscn")
	var g=t.instantiate()
	weaponList.push_back(g)
	weaponBackpack.add_child(g)
	if playerId==1:
		keyMap.left="p1_left"
		keyMap.right="p1_right"
		keyMap.up="p1_up"
		keyMap.down="p1_down"
		keyMap.fire='p1_fire'
		keyMap.switch='p1_switch'
	print(global_position,global_position+Vector2(800,0))
	
func switchWeapon():
	if weaponList.size()>1:
		currWeaponIndex+=1
		currWeaponIndex=wrapi(currWeaponIndex,0,weaponList.size())
		currWeapon=weaponList[currWeaponIndex]
		#播放声音
		txt.text=Game.weaponName[currWeapon.type]
	
	
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
	ani.play(currAni+"_%s"%playerId+"_%s"%angle+"_%s"%Game.weaponName[currWeapon.type])
	
	#var space_state = get_world_2d().direct_space_state
	#var mouse_pos = get_global_mouse_position()
	#var query = PhysicsRayQueryParameters2D.create(global_position, 
	#mouse_pos)
	#query.collide_with_areas=true
	##query.exclude = [ownerId]
	#var result = space_state.intersect_ray(query)
	#print(result)
	

func _input(_event: InputEvent) -> void:
	if Input.is_action_pressed(keyMap.fire):
		currWeapon.fire(vector)
	if Input.is_action_just_pressed(keyMap.switch):
		switchWeapon()
		pass
